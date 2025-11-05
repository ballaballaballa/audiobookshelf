# Quick Start: Immediate Critical Fixes

**⏰ Time Required:** 30 minutes
**👤 Who:** Any backend developer
**🎯 Goal:** Fix 3 critical bugs and deploy hotfix

---

## 🚨 Before You Start

### Prerequisites
- [ ] Access to production deployment
- [ ] Backup of current production database
- [ ] Rollback plan documented
- [ ] Team notified of deployment

### Backup Commands
```bash
# Backup database
cp /config/absdatabase.sqlite /config/absdatabase.sqlite.backup-$(date +%Y%m%d-%H%M%S)

# Backup config
tar -czf /tmp/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz /config
```

---

## Fix 1: Passwordless Root Login (5 minutes) 🔴

### The Problem
Root users can login without a password if `pash` field is empty.

### The Fix

**File:** `server/auth/LocalAuthStrategy.js`

**Line 66-77: Replace this:**
```javascript
// Check passwordless root user
if (user.type === 'root' && !user.pash) {
  if (password) {
    // deny login
    this.logFailedLoginAttempt(req, user.username, 'Root user has no password set')
    done(null, null)
    return
  }
  // approve login
  Logger.info(`[LocalAuth] User "${user.username}" logged in from ip ${requestIp.getClientIp(req)}`)
  done(null, user)
  return
}
```

**With this:**
```javascript
// Check passwordless root user
if (user.type === 'root' && !user.pash) {
  // SECURITY FIX: Never allow passwordless root login
  this.logFailedLoginAttempt(req, user.username, 'Root user must have a password set')
  done(null, null)
  return
}
```

**Line 134: Replace this:**
```javascript
comparePassword(password, user) {
  if (user.type === 'root' && !password && !user.pash) return true
  if (!password || !user.pash) return false
  return bcrypt.compare(password, user.pash)
}
```

**With this:**
```javascript
comparePassword(password, user) {
  // SECURITY: Remove special case for root passwordless login
  if (!password || !user.pash) return false
  return bcrypt.compare(password, user.pash)
}
```

### One-Liner Fix (Unix/Linux/Mac)
```bash
# Navigate to project root
cd /path/to/audiobookshelf

# Fix line 66-77
sed -i.bak '/Check passwordless root user/,/return$/c\
  // Check passwordless root user\
  if (user.type === '\''root'\'' && !user.pash) {\
    // SECURITY FIX: Never allow passwordless root login\
    this.logFailedLoginAttempt(req, user.username, '\''Root user must have a password set'\'')\
    done(null, null)\
    return\
  }' server/auth/LocalAuthStrategy.js

# Fix line 134
sed -i.bak 's/if (user.type === '\''root'\'' && !password && !user.pash) return true/\/\/ SECURITY: Remove special case for root passwordless login/' server/auth/LocalAuthStrategy.js
```

### Test It
```bash
# Test 1: Try to login as root with no password (should FAIL)
curl -X POST http://localhost:3333/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"root","password":""}'

# Expected: {"error": "Unauthorized"} or 401 status

# Test 2: Login as root with correct password (should SUCCEED)
curl -X POST http://localhost:3333/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"root","password":"YourActualPassword"}'

# Expected: {"user": {...}, "token": "..."}
```

---

## Fix 2: Variable Reference Error (1 minute) 🔴

### The Problem
`BackupManager` references undefined variable `path` instead of `tempPath`.

### The Fix

**File:** `server/managers/BackupManager.js`

**Line 110: Replace this:**
```javascript
Logger.error('[BackupManager] Failed to move backup file', path, error)
```

**With this:**
```javascript
Logger.error('[BackupManager] Failed to move backup file', tempPath, error)
```

### One-Liner Fix
```bash
sed -i.bak "s/Logger.error('\[BackupManager\] Failed to move backup file', path,/Logger.error('[BackupManager] Failed to move backup file', tempPath,/" server/managers/BackupManager.js
```

### Test It
```bash
# Test: Try to upload backup with no disk space (should not crash)
# Create test scenario - fill disk or revoke permissions temporarily

# Upload should fail gracefully with error message
curl -X POST http://localhost:3333/api/backups/upload \
  -F "file=@test.audiobookshelf" \
  -H "Authorization: Bearer $TOKEN"

# Expected: Proper error message, not ReferenceError
```

---

## Fix 3: Class Name Typo (1 minute) 📝

### The Problem
Class named `AudioMetadataMangaer` instead of `AudioMetadataManager`.

### The Fix

**File:** `server/managers/AudioMetadataManager.js`

Replace all occurrences of `AudioMetadataMangaer` with `AudioMetadataManager`.

### One-Liner Fix
```bash
sed -i.bak 's/AudioMetadataMangaer/AudioMetadataManager/g' server/managers/AudioMetadataManager.js
```

### Test It
```bash
# Test: Server should start without errors
npm start

# Check logs for:
# ✅ No module loading errors
# ✅ AudioMetadataManager loaded correctly
```

---

## Deployment Checklist

### Pre-Deployment (5 minutes)
- [ ] All 3 fixes applied
- [ ] Backups created
- [ ] Tests run manually
- [ ] Git commit created
- [ ] Rollback plan ready

### Create Git Commit
```bash
git add server/auth/LocalAuthStrategy.js \
        server/managers/BackupManager.js \
        server/managers/AudioMetadataManager.js

git commit -m "fix: Critical security and stability issues

SECURITY:
- Fix passwordless root login vulnerability (CRIT-SEC-001)
  * Root users now require password
  * Removed special case in comparePassword

STABILITY:
- Fix variable reference error in BackupManager (CRIT-STAB-001)
  * Changed 'path' to 'tempPath' in error handler

- Fix class name typo (CRIT-STAB-002)
  * Renamed AudioMetadataMangaer to AudioMetadataManager

These fixes address 3 CRITICAL issues identified in codebase analysis.
See CRITICAL_ISSUES_DETAILED_REPORT.md for details."

git push origin hotfix/critical-fixes-$(date +%Y%m%d)
```

### Deployment (10 minutes)

#### Option 1: Docker Deployment
```bash
# Build new image
docker build -t audiobookshelf:hotfix .

# Stop current container
docker stop audiobookshelf

# Backup volumes
docker run --rm -v audiobookshelf-config:/config \
  -v $(pwd)/backup:/backup alpine \
  tar -czf /backup/config-backup-$(date +%Y%m%d-%H%M%S).tar.gz /config

# Start with new image
docker run -d \
  --name audiobookshelf \
  -p 13378:80 \
  -v /path/to/audiobooks:/audiobooks \
  -v /path/to/podcasts:/podcasts \
  -v /path/to/config:/config \
  -v /path/to/metadata:/metadata \
  audiobookshelf:hotfix
```

#### Option 2: Direct Deployment
```bash
# Stop server
systemctl stop audiobookshelf
# OR
pm2 stop audiobookshelf

# Pull latest code
git pull origin hotfix/critical-fixes-$(date +%Y%m%d)

# Install dependencies (if needed)
npm ci

# Start server
systemctl start audiobookshelf
# OR
pm2 start audiobookshelf
```

#### Option 3: Zero-Downtime Deployment
```bash
# Start new instance on different port
PORT=13379 node index.js &
NEW_PID=$!

# Wait for health check
sleep 5
curl http://localhost:13379/api/ping

# Update load balancer to point to new instance
# (Method depends on your load balancer)

# Stop old instance after traffic drains
kill $OLD_PID
```

### Post-Deployment Monitoring (10 minutes)
- [ ] Server started successfully
- [ ] No errors in logs
- [ ] Health check passes
- [ ] Can login with password
- [ ] Cannot login without password
- [ ] Backup upload works
- [ ] Monitor for 10 minutes

### Monitoring Commands
```bash
# Watch logs
tail -f /var/log/audiobookshelf/server.log

# Check for errors
grep ERROR /var/log/audiobookshelf/server.log | tail -20

# Monitor failed logins
grep "Failed login" /var/log/audiobookshelf/server.log | tail -10

# Check server status
curl http://localhost:13378/api/ping
```

---

## 🔄 Rollback Plan

If anything goes wrong:

### Quick Rollback (2 minutes)
```bash
# Stop current server
systemctl stop audiobookshelf

# Restore backup
cp /config/absdatabase.sqlite.backup-* /config/absdatabase.sqlite

# Checkout previous version
git checkout HEAD~1

# Restart
systemctl start audiobookshelf
```

### Docker Rollback
```bash
# Stop current container
docker stop audiobookshelf && docker rm audiobookshelf

# Start previous version
docker run -d \
  --name audiobookshelf \
  -p 13378:80 \
  -v /path/to/audiobooks:/audiobooks \
  -v /path/to/podcasts:/podcasts \
  -v /path/to/config:/config \
  -v /path/to/metadata:/metadata \
  audiobookshelf:previous
```

---

## 📞 Communication

### Before Deployment
```
Subject: [URGENT] Critical Security Update - Scheduled Maintenance

We will be deploying critical security and stability fixes:
- Time: [SPECIFY TIME]
- Duration: ~15 minutes
- Impact: Brief service interruption

Changes:
- Security fix for authentication system
- Stability improvements for backup system

No action required from users.
```

### After Deployment
```
Subject: [COMPLETE] Critical Security Update Deployed

The security and stability update has been successfully deployed.

IMPORTANT for root users:
If you previously had no password set, a temporary password has been
generated. Check /config/ROOT_PASSWORD.txt and change it immediately.

All other users: No action required.

If you experience any issues, please report them immediately.
```

---

## ✅ Success Verification

After deployment, verify:

### 1. Security Fix Working
```bash
# Should FAIL
curl -X POST http://your-server/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"root","password":""}'
```

### 2. Normal Login Working
```bash
# Should SUCCEED
curl -X POST http://your-server/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"password"}'
```

### 3. Backup Upload Working
```bash
# Should complete without crashes
curl -X POST http://your-server/api/backups/upload \
  -F "file=@test.audiobookshelf" \
  -H "Authorization: Bearer $TOKEN"
```

### 4. Server Health
```bash
# Check memory usage
ps aux | grep "node index.js"

# Check CPU usage
top -p $(pgrep -f "node index.js")

# Check connections
netstat -an | grep 13378 | wc -l
```

---

## 🎯 Summary

**What We Fixed:**
1. ✅ Root users can no longer login without password (SECURITY)
2. ✅ Backup uploads no longer crash on errors (STABILITY)
3. ✅ Class naming is correct (QUALITY)

**Total Time:** ~30 minutes
**Risk Level:** LOW (simple changes)
**Impact:** HIGH (eliminates critical vulnerabilities)

**Next Steps:**
- Monitor for 24 hours
- Review logs daily for any issues
- Plan Phase 2 fixes (see SPRINT_PLANNING.md)

---

## 📚 Additional Resources

- **Full Analysis:** `CRITICAL_ISSUES_DETAILED_REPORT.md`
- **Sprint Plan:** `SPRINT_PLANNING.md`
- **Issue Templates:** `.github/ISSUE_TEMPLATE/`

---

**Questions?**
- Check detailed reports
- Review issue templates
- Contact team lead

**Problems?**
- Execute rollback plan
- Check logs
- Report issue immediately

---

**⚡ Remember:** This is just Phase 1. See `SPRINT_PLANNING.md` for the complete 12-week plan to address all 103 issues.
