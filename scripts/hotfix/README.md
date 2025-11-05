# Critical Hotfix Scripts

This directory contains automated scripts to apply critical security and stability fixes to Audiobookshelf.

## Quick Start

### Apply All Fixes (Recommended)

```bash
# Dry run first (see what would change)
./scripts/hotfix/apply-critical-fixes.sh --dry-run

# Apply all fixes
./scripts/hotfix/apply-critical-fixes.sh
```

This single script applies all 3 critical fixes:
1. Passwordless root login vulnerability (CRIT-SEC-001)
2. Variable reference error (CRIT-STAB-001)
3. Class name typo (CRIT-STAB-002)

## What the Script Does

### Safety Features
- ✅ Validates it's running in Audiobookshelf project
- ✅ Creates timestamped backups of all files before modifying
- ✅ Checks if fixes are already applied (idempotent)
- ✅ Verifies all fixes after application
- ✅ Supports dry-run mode

### Fixes Applied

**Fix 1: Security - Passwordless Root Login**
- File: `server/auth/LocalAuthStrategy.js`
- Lines: 66-77, 134
- Impact: Prevents unauthorized root access
- Backup: Creates `.backup-YYYYMMDD-HHMMSS` file

**Fix 2: Stability - Variable Reference**
- File: `server/managers/BackupManager.js`
- Line: 110
- Impact: Prevents crash on backup upload errors
- Backup: Creates `.backup-YYYYMMDD-HHMMSS` file

**Fix 3: Quality - Class Name Typo**
- File: `server/managers/AudioMetadataManager.js`
- Impact: Improves code maintainability
- Backup: Creates `.backup-YYYYMMDD-HHMMSS` file

## Usage Examples

### Dry Run (Recommended First Step)
```bash
./scripts/hotfix/apply-critical-fixes.sh --dry-run
```

Output:
```
╔══════════════════════════════════════════════════════════════╗
║   Audiobookshelf Critical Fixes - Automated Application     ║
╚══════════════════════════════════════════════════════════════╝

[WARNING] DRY RUN MODE - No changes will be made

[SUCCESS] Found Audiobookshelf project at: /path/to/audiobookshelf
[SUCCESS] All required files found

┌──────────────────────────────────────────────────────────────┐
│ Fix 1: Passwordless Root Login Vulnerability                │
└──────────────────────────────────────────────────────────────┘

[INFO] Processing: server/auth/LocalAuthStrategy.js
[INFO] Would create backup: server/auth/LocalAuthStrategy.js.backup-...
[INFO] Would apply security fix to LocalAuthStrategy.js

...
```

### Apply Fixes
```bash
./scripts/hotfix/apply-critical-fixes.sh
```

Output on success:
```
╔══════════════════════════════════════════════════════════════╗
║                   ALL FIXES APPLIED ✓                        ║
╚══════════════════════════════════════════════════════════════╝

[SUCCESS] All 3 critical fixes have been successfully applied!

Next steps:
1. Review the changes: git diff
2. Test the application manually
3. Create a commit: git add . && git commit -m 'fix: Apply critical fixes'
4. Deploy to production
```

## After Running the Script

### 1. Review Changes
```bash
git diff
```

### 2. Test Locally
```bash
# Start the server
npm start

# Test authentication
curl -X POST http://localhost:3333/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"root","password":""}'

# Should return 401 (fix working!)
```

### 3. Create Commit
```bash
git add server/auth/LocalAuthStrategy.js \
        server/managers/BackupManager.js \
        server/managers/AudioMetadataManager.js

git commit -m "fix: Apply critical security and stability fixes

SECURITY:
- Fix passwordless root login vulnerability (CRIT-SEC-001)

STABILITY:
- Fix variable reference error in BackupManager (CRIT-STAB-001)
- Fix class name typo in AudioMetadataManager (CRIT-STAB-002)

Applied automatically via scripts/hotfix/apply-critical-fixes.sh"
```

### 4. Deploy
Follow your normal deployment process.

## Rollback

If you need to rollback:

```bash
# Find backup files
ls -la server/auth/LocalAuthStrategy.js.backup-*
ls -la server/managers/BackupManager.js.backup-*
ls -la server/managers/AudioMetadataManager.js.backup-*

# Restore from backup
cp server/auth/LocalAuthStrategy.js.backup-YYYYMMDD-HHMMSS \
   server/auth/LocalAuthStrategy.js

cp server/managers/BackupManager.js.backup-YYYYMMDD-HHMMSS \
   server/managers/BackupManager.js

cp server/managers/AudioMetadataManager.js.backup-YYYYMMDD-HHMMSS \
   server/managers/AudioMetadataManager.js
```

## Troubleshooting

### "File not found" error
Make sure you're running the script from the project root or scripts directory:
```bash
cd /path/to/audiobookshelf
./scripts/hotfix/apply-critical-fixes.sh
```

### "Fix already applied" warnings
This is normal if you've already run the script. The script is idempotent and safe to run multiple times.

### Permission denied
Make the script executable:
```bash
chmod +x scripts/hotfix/apply-critical-fixes.sh
```

## Manual Application

If you prefer to apply fixes manually, see:
- **Detailed Guide:** `QUICK_START_FIXES.md` in project root
- **Issue Templates:** `.github/ISSUE_TEMPLATE/critical-*.md`

## Related Documentation

- **Quick Start Guide:** `../QUICK_START_FIXES.md`
- **Full Analysis:** `../CRITICAL_ISSUES_DETAILED_REPORT.md`
- **Sprint Plan:** `../SPRINT_PLANNING.md`
- **Executive Summary:** `../EXECUTIVE_SUMMARY.md`

## Support

For questions or issues:
1. Review `QUICK_START_FIXES.md` for manual instructions
2. Check `CRITICAL_ISSUES_DETAILED_REPORT.md` for technical details
3. Create a GitHub issue if problems persist

---

**⚡ This script fixes critical security vulnerabilities. Deploy within 24 hours!**
