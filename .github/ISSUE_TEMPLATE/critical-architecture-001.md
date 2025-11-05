---
name: 🏗️ CRITICAL - God Object Anti-Pattern
about: Database and Controller classes violate Single Responsibility Principle
title: '[ARCHITECTURE] CRIT-ARCH-001: Refactor God Objects'
labels: 'architecture, critical, P2, refactoring, technical-debt'
assignees: ''
---

## 🏗️ Critical Architecture Issue

**Severity:** CRITICAL (Architecture)
**Priority:** P2 - Begin within 1 month
**Type:** Design Flaw / Code Smell
**Effort:** 12 weeks

---

## 📋 Summary

Multiple classes violate the Single Responsibility Principle by handling too many responsibilities. This makes the code difficult to test, maintain, and reason about.

## 🔍 Affected Components

### 1. Database.js (999 lines)
**Multiple Responsibilities:**
- ORM Connection Manager
- Model Registry (25+ getter methods)
- Settings Manager
- Migration Handler
- Cache Manager (library filter data)
- Query Builder
- Schema Manager

**Location:** `server/Database.js`

---

### 2. LibraryController.js (1,492 lines)
**Multiple Responsibilities:**
- Library CRUD operations
- Library item filtering
- Search functionality
- Statistics generation
- Library scanning
- Series/author management

**Location:** `server/controllers/LibraryController.js`

---

### 3. LibraryItemController.js (1,197 lines)
**Multiple Responsibilities:**
- Library item CRUD
- Cover management
- Sharing functionality
- RSS feed management
- Podcast downloads
- Media playback

**Location:** `server/controllers/LibraryItemController.js`

---

## 💥 Impact

### Testing Impact
- **Impossible to Unit Test:** Must mock entire system to test one function
- **No Isolation:** Cannot test components independently
- **Slow Test Runs:** Full integration tests required

### Development Impact
- **High Cognitive Load:** Developers must understand 1000+ lines to make changes
- **Merge Conflicts:** Multiple developers editing same large files
- **Fear of Change:** Any change might break unrelated functionality

### Maintenance Impact
- **Bug Reproduction:** Difficult to isolate issues
- **Onboarding:** New developers take weeks to understand god objects
- **Technical Debt:** Grows exponentially over time

---

## 🎯 Remediation Plan

### Phase 1: Extract Service Layer (Weeks 1-2)

**Create Focused Services:**

```javascript
// server/services/LibraryService.js
class LibraryService {
  constructor(database) {
    this.db = database
  }

  async createLibrary(libraryData) {
    // Pure business logic
  }

  async updateLibrary(id, updates) {
    // ...
  }
}

// server/services/LibraryScanService.js
class LibraryScanService {
  async scanLibrary(libraryId, options) {
    // Scanning logic only
  }
}

// server/services/LibraryFilterService.js
class LibraryFilterService {
  async getFilteredItems(libraryId, filters) {
    // Filter logic only
  }
}
```

---

### Phase 2: Split Database Class (Weeks 3-4)

**Separate Concerns:**

```javascript
// server/database/ConnectionManager.js
class ConnectionManager {
  async connect(dbPath) { /* ... */ }
}

// server/database/ModelRegistry.js
class ModelRegistry {
  register(modelName, model) { /* ... */ }
  get(modelName) { /* ... */ }
}

// server/database/MigrationRunner.js
class MigrationRunner {
  async runMigrations(sequelize, version) { /* ... */ }
}

// server/services/SettingsService.js
class SettingsService {
  async getSetting(key) { /* ... */ }
  async setSetting(key, value) { /* ... */ }
}
```

---

### Phase 3: Implement Dependency Injection (Weeks 5-6)

**Use DI Container (Awilix):**

```javascript
// server/di/container.js
const { createContainer, asClass } = require('awilix')

function setupContainer(config) {
  const container = createContainer()

  container.register({
    database: asClass(Database).singleton(),
    libraryService: asClass(LibraryService).scoped(),
    scanService: asClass(LibraryScanService).scoped(),
    libraryController: asClass(LibraryController).scoped()
  })

  return container
}
```

---

### Phase 4: Migrate Controllers (Weeks 7-12)

**Refactored Controller (200 lines instead of 1,492):**

```javascript
class LibraryController {
  constructor(libraryService, scanService, filterService) {
    this.libraryService = libraryService
    this.scanService = scanService
    this.filterService = filterService
  }

  async create(req, res) {
    try {
      if (!req.user.isAdminOrUp) {
        return res.sendStatus(403)
      }

      const { error, data } = this.validateCreateRequest(req.body)
      if (error) {
        return res.status(400).send(error)
      }

      const library = await this.libraryService.createLibrary(data)
      return res.status(201).json(library.toJSON())
    } catch (error) {
      Logger.error('[LibraryController] Failed to create library', error)
      return res.status(500).send('Failed to create library')
    }
  }
}
```

---

## 📦 Deliverables

### Week 1-2: Service Layer
- [ ] Create LibraryService
- [ ] Create ScanService
- [ ] Create FilterService
- [ ] Create PodcastService
- [ ] Create UserService
- [ ] Write unit tests for each service

### Week 3-4: Database Split
- [ ] Extract ConnectionManager
- [ ] Extract ModelRegistry
- [ ] Extract MigrationRunner
- [ ] Extract SettingsService
- [ ] Update Database class to orchestrate

### Week 5-6: Dependency Injection
- [ ] Setup Awilix container
- [ ] Register all dependencies
- [ ] Update server initialization
- [ ] Test dependency resolution

### Week 7-12: Controller Migration
- [ ] Refactor LibraryController
- [ ] Refactor LibraryItemController
- [ ] Refactor remaining controllers (30 files)
- [ ] Remove old code paths
- [ ] Final testing

---

## 🧪 Testing Strategy

### Before Refactoring (Hard)
```javascript
// Must mock entire Database singleton
describe('LibraryController', () => {
  // Requires complex setup
  // Integration test, not unit test
})
```

### After Refactoring (Easy)
```javascript
// Inject mocked services
describe('LibraryController', () => {
  it('should create library', async () => {
    const mockService = {
      createLibrary: sinon.stub().resolves({ id: 1, name: 'Test' })
    }

    const controller = new LibraryController(mockService, null, null)

    // Fast, isolated unit test
  })
})
```

---

## 📊 Success Metrics

- [ ] Database.js reduced from 999 → ~150 lines
- [ ] LibraryController reduced from 1,492 → ~200 lines
- [ ] LibraryItemController reduced from 1,197 → ~200 lines
- [ ] All controllers <300 lines
- [ ] All services <200 lines
- [ ] 100% of new code has unit tests
- [ ] Cyclomatic complexity <15 for all methods

---

## ⚠️ Risks & Mitigation

### Risk: Breaking Changes
**Mitigation:**
- Feature flags for new implementations
- Run old and new code in parallel
- Gradual rollout (10% → 50% → 100%)

### Risk: Team Velocity Drop
**Mitigation:**
- Allocate 60% to refactoring, 40% to features
- Pair programming for knowledge transfer
- Document as you go

### Risk: Incomplete Refactoring
**Mitigation:**
- Complete one controller at a time
- Don't start new controller until previous is done
- Maintain old code until all migrated

---

## 📚 References

- Detailed analysis: `CRITICAL_ISSUES_DETAILED_REPORT.md` (CRIT-ARCH-001 section)
- Implementation plan: `SPRINT_PLANNING.md` (Phase 4)
- SOLID Principles: https://en.wikipedia.org/wiki/SOLID
- Dependency Injection: https://github.com/jeffijoe/awilix

---

## 🚀 Getting Started

### Week 1 Tasks

1. **Setup (Day 1):**
   ```bash
   # Install Awilix for DI
   npm install awilix

   # Create directory structure
   mkdir -p server/{services,repositories,di}
   ```

2. **First Service (Day 2-5):**
   - Extract LibraryService from LibraryController
   - Write comprehensive unit tests
   - See detailed report for code examples

3. **Review (Day 5):**
   - Team code review
   - Adjust approach based on feedback

---

**⏰ Timeline:** 12-week phased approach
**👀 Reviewers:** @architecture-team @backend-team

**See `CRITICAL_ISSUES_DETAILED_REPORT.md` for complete analysis**
