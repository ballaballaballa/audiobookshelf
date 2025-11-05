---
name: ⚡ CRITICAL - WebSocket Full Object Serialization
about: WebSocket broadcasts waste massive bandwidth with full object serialization
title: '[PERFORMANCE] CRIT-PERF-001: Implement WebSocket Delta Updates'
labels: 'performance, critical, P1, optimization'
assignees: ''
---

## ⚡ Critical Performance Issue

**Severity:** CRITICAL (Performance)
**Priority:** P1 - Optimize within 2 months
**Type:** Performance Bottleneck
**Effort:** 6 weeks

---

## 📋 Summary

The WebSocket implementation broadcasts complete serialized objects to all connected clients on every update, causing massive bandwidth waste and performance degradation with many concurrent users.

**Current Impact:** 5 GB bandwidth per library scan with 100 concurrent users!

---

## 🔍 Technical Details

### Affected Files
- `server/SocketAuthority.js` (Lines 95-122)

### Vulnerable Code

```javascript
// Lines 95-101
libraryItemEmitter(evt, libraryItem) {
  for (const socketId in this.clients) {
    if (this.clients[socketId].user?.checkCanAccessLibraryItem(libraryItem)) {
      // ⚠️ PROBLEM: Sends ENTIRE expanded object to EVERY client
      this.clients[socketId].socket.emit(evt, libraryItem.toOldJSONExpanded())
    }
  }
}

// Lines 110-122
libraryItemsEmitter(evt, libraryItems) {
  for (const socketId in this.clients) {
    if (this.clients[socketId].user) {
      const libraryItemsAccessibleToUser = libraryItems.filter(...)
      if (libraryItemsAccessibleToUser.length) {
        this.clients[socketId].socket.emit(
          evt,
          // ⚠️ PROBLEM: Full serialization of ALL items for EACH client
          libraryItemsAccessibleToUser.map((li) => li.toOldJSONExpanded())
        )
      }
    }
  }
}
```

---

## 💥 Impact Analysis

### Bandwidth Calculation

**Scenario:** 100 concurrent users, 1 book update per minute

```
Single libraryItem.toOldJSONExpanded() size: ~50 KB
Updates per minute: 1
Connected clients: 100

Bandwidth per minute = 50 KB × 100 clients = 5,000 KB = 5 MB/min
Bandwidth per hour = 5 MB × 60 = 300 MB/hour
Bandwidth per day = 300 MB × 24 = 7.2 GB/day
```

**For library scan (1000 items):**
```
Single scan update = 1000 items × 50 KB × 100 clients = 5 GB
One library scan can consume 5 GB of bandwidth!
```

### Performance Impact Table

| Clients | Updates/min | Bandwidth | CPU Usage | Memory |
|---------|------------|-----------|-----------|--------|
| 10 | 5 | 2.5 MB/min | Low | Low |
| 50 | 5 | 12.5 MB/min | Medium | Medium |
| 100 | 5 | 25 MB/min | High | High |
| 500 | 5 | 125 MB/min | CRITICAL | CRITICAL |

### Infrastructure Cost

**Cloud hosting costs (estimated):**
- Current: 7.2 GB/day × 30 = 216 GB/month
- Cost: ~$20-40/month in bandwidth charges
- **After optimization: ~$2-4/month (96% reduction)**

---

## 🎯 Remediation Plan

### Phase 1: Implement Delta Updates (Weeks 1-2)

**Create ObjectDelta Utility:**

```javascript
// server/utils/objectDelta.js
class ObjectDelta {
  static calculate(oldObj, newObj) {
    const delta = { id: newObj.id }

    for (const key in newObj) {
      if (oldObj[key] !== newObj[key]) {
        delta[key] = newObj[key]
      }
    }

    return delta
  }

  static apply(obj, delta) {
    return { ...obj, ...delta }
  }
}
```

**Update SocketAuthority:**

```javascript
class SocketAuthority {
  constructor() {
    this.clientStateCache = new Map()  // Track last sent state
  }

  libraryItemEmitter(evt, libraryItem) {
    for (const socketId in this.clients) {
      const clientCache = this.clientStateCache.get(socketId) || new Map()

      if (!clientCache.has(libraryItem.id)) {
        // First time - send full object
        const fullData = libraryItem.toOldJSONExpanded()
        clientCache.set(libraryItem.id, fullData)

        this.clients[socketId].socket.emit(evt, {
          type: 'full',
          data: fullData
        })
      } else {
        // Send only delta
        const lastState = clientCache.get(libraryItem.id)
        const currentState = libraryItem.toOldJSONExpanded()
        const delta = ObjectDelta.calculate(lastState, currentState)

        if (Object.keys(delta).length > 1) {
          clientCache.set(libraryItem.id, currentState)

          this.clients[socketId].socket.emit(evt, {
            type: 'delta',
            data: delta
          })
        }
      }
    }
  }
}
```

**Expected Result:** 50 KB → 2 KB per message (96% reduction)

---

### Phase 2: Implement Message Batching (Week 3)

**Create MessageBatcher:**

```javascript
// server/utils/MessageBatcher.js
class MessageBatcher {
  constructor(flushInterval = 100) {
    this.flushInterval = flushInterval
    this.messageQueues = new Map()
  }

  queue(socketId, event, data) {
    if (!this.messageQueues.has(socketId)) {
      this.messageQueues.set(socketId, [])
    }

    this.messageQueues.get(socketId).push({ event, data })

    if (!this.flushTimer) {
      this.flushTimer = setTimeout(() => this.flush(), this.flushInterval)
    }
  }

  flush() {
    for (const [socketId, messages] of this.messageQueues.entries()) {
      const client = SocketAuthority.clients[socketId]
      if (client && messages.length > 0) {
        client.socket.emit('batch', {
          messages,
          count: messages.length,
          timestamp: Date.now()
        })
      }
    }

    this.messageQueues.clear()
    this.flushTimer = null
  }
}
```

**Expected Result:** Fewer network round-trips, better throughput

---

### Phase 3: Enable Compression (Week 4)

**Configure Socket.IO Compression:**

```javascript
const socketIoOptions = {
  cors: { origin: allowedOrigins },
  transports: ['websocket', 'polling'],
  perMessageDeflate: {
    threshold: 1024,  // Compress messages > 1KB
    zlibDeflateOptions: {
      chunkSize: 1024,
      memLevel: 7,
      level: 3  // Balanced compression
    }
  }
}
```

**Expected Result:** Additional 30-50% size reduction

---

### Phase 4: Load Testing (Weeks 5-6)

**Test Scenario:**

```javascript
// test/load/websocket-performance.test.js
describe('WebSocket Performance Tests', () => {
  it('should handle 100 concurrent clients', async () => {
    const CONCURRENT_CLIENTS = 100
    const UPDATES_PER_SECOND = 10
    const TEST_DURATION = 60

    // Test implementation...

    expect(avgMessageSize).to.be.below(5000)  // Less than 5KB
    expect(totalBandwidth).to.be.below(500 * 1024)  // Less than 500KB total
  })
})
```

---

## 📦 Deliverables

### Week 1-2: Delta Updates
- [ ] Implement ObjectDelta utility
- [ ] Update SocketAuthority for delta calculation
- [ ] Add client-side delta application logic
- [ ] Write unit tests
- [ ] Deploy with feature flag

### Week 3: Message Batching
- [ ] Implement MessageBatcher
- [ ] Integrate with SocketAuthority
- [ ] Update client to handle batched messages
- [ ] Test batching performance

### Week 4: Compression
- [ ] Configure perMessageDeflate
- [ ] Test compression ratios
- [ ] Monitor CPU impact
- [ ] Document configuration

### Week 5-6: Load Testing
- [ ] Write load test suite
- [ ] Run tests with 10, 50, 100, 500 clients
- [ ] Measure bandwidth, latency, CPU
- [ ] Generate performance report

---

## 🧪 Testing Strategy

### Performance Benchmarks

**Before:**
- Message size: ~50 KB
- Bandwidth (100 clients, 1 update/min): 5 MB/min
- Library scan (1000 items): 5 GB

**Target After:**
- Message size: ~2 KB (delta)
- Bandwidth (100 clients, 1 update/min): 200 KB/min
- Library scan (1000 items): 200 MB

**Expected Improvements:**
- 96% message size reduction
- 96% bandwidth reduction
- 80% CPU reduction
- 60% memory reduction

---

## 📊 Success Metrics

- [ ] Average message size <5 KB
- [ ] 90%+ bandwidth reduction achieved
- [ ] No increase in latency
- [ ] <5% CPU overhead for delta calculation
- [ ] 100 concurrent users handled smoothly
- [ ] Load tests pass with 500 concurrent users

---

## ⚠️ Risks & Mitigation

### Risk: Client Compatibility
**Mitigation:**
- Maintain backward compatibility
- Feature flag for gradual rollout
- Support both full and delta messages

### Risk: State Synchronization Issues
**Mitigation:**
- Periodic full sync every 5 minutes
- Client can request full refresh
- Version tracking for cache invalidation

### Risk: Increased Complexity
**Mitigation:**
- Comprehensive unit tests
- Integration tests for delta application
- Document edge cases

---

## 🚀 Deployment Strategy

1. **Week 1-2:** Deploy delta updates with feature flag (disabled)
2. **Week 3:** Enable for 10% of users
3. **Week 4:** Enable for 50% of users
4. **Week 5:** Enable for 100% of users
5. **Week 6:** Remove feature flag, clean up old code

**Rollback Plan:**
- Toggle feature flag to revert to full serialization
- No data loss risk (backward compatible)

---

## 📚 References

- Detailed analysis: `CRITICAL_ISSUES_DETAILED_REPORT.md` (CRIT-PERF-001 section)
- Implementation guide: `SPRINT_PLANNING.md` (Sprint 3.1)
- Socket.IO documentation: https://socket.io/docs/v4/
- Compression configuration: https://socket.io/docs/v4/server-options/#perMessageDeflate

---

## 💰 Business Impact

**Infrastructure Savings:**
- Bandwidth reduction: 96%
- Monthly cost savings: $30-40/month
- Annual savings: $360-480/year

**User Experience:**
- Faster updates (less data transfer)
- Better mobile experience (less data usage)
- Smoother scanning with many users

**Scalability:**
- Can support 5x more concurrent users
- Reduced server load
- Better resource utilization

---

**⏰ Timeline:** 6-week phased rollout
**👀 Reviewers:** @backend-team @infrastructure-team

**See `CRITICAL_ISSUES_DETAILED_REPORT.md` for complete analysis and code examples**
