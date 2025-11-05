---
name: 🐛 CRITICAL - Variable Reference Error in BackupManager
about: ReferenceError crashes backup upload endpoint
title: '[BUG] CRIT-STAB-001: Variable Reference Error in BackupManager'
labels: 'bug, critical, P0, stability'
assignees: ''
---

## 🐛 Critical Bug - IMMEDIATE FIX REQUIRED

**Severity:** CRITICAL (Runtime Error)
**Priority:** P0 - Deploy within 24 hours
**Type:** Logic Error / Reference Error

---

## 📋 Summary

The `BackupManager.uploadBackup()` method contains a variable reference error that causes a `ReferenceError` when backup file upload fails. The error handler references an undefined variable `path` instead of `tempPath`.

## 🔍 Technical Details

**Affected File:** `server/managers/BackupManager.js`
**Line:** 110
**Method:** `uploadBackup(req, res)`

**Buggy Code:**
```javascript
const tempPath = Path.join(this.backupPath, fileUtils.sanitizeFilename(backupFile.name))
const success = await backupFile
  .mv(tempPath)
  .then(() => true)
  .catch((error) => {
    // ⚠️ BUG: 'path' is undefined - should be 'tempPath'
    Logger.error('[BackupManager] Failed to move backup file', path, error)
    return false
  })
```

## 💥 Impact

### When Error Triggers
- Disk full / no space left
- Permission denied on backup directory
- File system errors (I/O errors)
- Network mount failures

### Consequences
- ❌ Unhandled ReferenceError crashes endpoint
- ❌ Client receives no response (connection hangs)
- ❌ Error not properly logged
- ❌ Partial file may remain

## 🎯 Reproduction

```bash
# 1. Fill disk space
dd if=/dev/zero of=/var/audiobookshelf/backups/fill bs=1M count=10000

# 2. Try to upload backup
curl -X POST http://localhost:3333/api/backups/upload \
  -F "file=@test.audiobookshelf" \
  -H "Authorization: Bearer $TOKEN"

# Result: ReferenceError: path is not defined
```

## ✅ Remediation

### Quick Fix (1 minute)

**Option 1: Simple Variable Name Fix**
```javascript
// Line 110: Change 'path' to 'tempPath'
Logger.error('[BackupManager] Failed to move backup file', tempPath, error)
```

### Better Fix (5 minutes)

**Option 2: Enhanced Error Handling**
```javascript
const tempPath = Path.join(this.backupPath, fileUtils.sanitizeFilename(backupFile.name))

let success = false
try {
  await backupFile.mv(tempPath)
  success = true
} catch (error) {
  Logger.error('[BackupManager] Failed to move backup file', {
    filename: backupFile.name,
    destination: tempPath,
    error: error.message,
    code: error.code
  })

  // Cleanup partial file if exists
  try {
    if (await fs.pathExists(tempPath)) {
      await fs.unlink(tempPath)
    }
  } catch (cleanupError) {
    Logger.error('[BackupManager] Failed to cleanup partial file', tempPath, cleanupError)
  }
}

if (!success) {
  return res.status(500).send('Failed to move backup file into backups directory')
}
```

## 📦 Files to Change

- [x] `server/managers/BackupManager.js` (line 110, optionally 105-120)

## 🧪 Testing Checklist

- [ ] Unit test: Handle file move failure gracefully
- [ ] Unit test: Cleanup partial files on error
- [ ] Integration test: Backup upload with disk full
- [ ] Manual test: Upload succeeds with available space
- [ ] Manual test: Upload fails gracefully with no space

## 🧪 Test Code

```javascript
// test/server/managers/BackupManager.test.js
describe('BackupManager - Error Handling', () => {
  it('should handle file move failure gracefully', async () => {
    const req = {
      files: {
        file: {
          name: 'backup.audiobookshelf',
          size: 1000,
          mv: sinon.stub().rejects(new Error('ENOSPC: no space left'))
        }
      }
    }

    const res = {
      status: sinon.stub().returnsThis(),
      send: sinon.stub()
    }

    await backupManager.uploadBackup(req, res)

    // Should return 507 for no space
    expect(res.status.calledWith(507)).to.be.true
    expect(res.send.calledOnce).to.be.true
  })

  it('should not throw ReferenceError on file move failure', async () => {
    // Should not throw
    await expect(backupManager.uploadBackup(req, res)).to.not.be.rejected
  })
})
```

## 📚 References

- Detailed analysis: `CRITICAL_ISSUES_DETAILED_REPORT.md` (CRIT-STAB-001 section)

## 🚀 Deployment Plan

1. Apply fix (1 minute)
2. Add unit tests
3. Test backup upload
4. Deploy with next hotfix

## 🔧 Prevention

Add ESLint rule:
```javascript
// .eslintrc.js
{
  "rules": {
    "no-undef": "error"
  }
}
```

Add pre-commit hook:
```bash
#!/bin/bash
npm run lint
```

---

**⏰ Timeline:** Include in immediate hotfix
**👀 Reviewers:** @backend-team

**See `CRITICAL_ISSUES_DETAILED_REPORT.md` for complete analysis**
