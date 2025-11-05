---
name: 🔴 CRITICAL - Passwordless Root Login Vulnerability
about: Authentication bypass allows unauthorized root access
title: '[SECURITY] CRIT-SEC-001: Passwordless Root Login Vulnerability'
labels: 'security, critical, P0, bug'
assignees: ''
---

## 🚨 Security Issue - IMMEDIATE ACTION REQUIRED

**Severity:** CRITICAL (CVSS 9.8)
**Priority:** P0 - Deploy within 24 hours
**Type:** Authentication Bypass
**CWE:** CWE-287 (Improper Authentication)

---

## 📋 Summary

The authentication system allows root users to login without providing a password if the root account has no password set (`pash` field is null/empty). This represents a complete authentication bypass for the most privileged account.

## 🔍 Technical Details

**Affected File:** `server/auth/LocalAuthStrategy.js`
**Lines:** 66-77, 134

**Vulnerable Code:**
```javascript
// Line 66-77
if (user.type === 'root' && !user.pash) {
  if (password) {
    // deny login
    this.logFailedLoginAttempt(req, user.username, 'Root user has no password set')
    done(null, null)
    return
  }
  // ⚠️ VULNERABILITY: approve login with empty password!
  Logger.info(`[LocalAuth] User "${user.username}" logged in from ip ${requestIp.getClientIp(req)}`)
  done(null, user)
  return
}
```

## 💥 Impact

**Confidentiality:** HIGH - Access to all user data, settings, credentials
**Integrity:** HIGH - Can modify/delete any data, create backdoor accounts
**Availability:** HIGH - Can delete database, disable services

**Attack Complexity:** LOW - No tools required, simple curl command
**Privileges Required:** NONE - No authentication needed
**User Interaction:** NONE - Fully automated exploit

## 🎯 Attack Scenario

```bash
# Simple exploitation
curl -X POST http://target-server/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"root","password":""}'

# Returns JWT token with full admin privileges
```

## ✅ Remediation

### Step 1: Update LocalAuthStrategy.js

Replace lines 66-77 with:
```javascript
// Check passwordless root user
if (user.type === 'root' && !user.pash) {
  // SECURITY FIX: Never allow passwordless root login
  this.logFailedLoginAttempt(req, user.username, 'Root user must have a password set')
  done(null, null)
  return
}
```

### Step 2: Update comparePassword method

Replace line 134 with:
```javascript
comparePassword(password, user) {
  // SECURITY: Remove special case for root passwordless login
  if (!password || !user.pash) return false
  return bcrypt.compare(password, user.pash)
}
```

### Step 3: Add Migration Script

Create migration to generate temporary passwords for existing passwordless roots.
See detailed report for full migration code.

### Step 4: Test

- [ ] Test root login with empty password (should FAIL)
- [ ] Test root login with valid password (should SUCCEED)
- [ ] Run unit tests
- [ ] Verify migration creates temp password

## 📦 Files to Change

- [x] `server/auth/LocalAuthStrategy.js` (lines 66-77, 134, 145-183)
- [x] Create new migration file
- [x] Add unit tests

## 🧪 Testing Checklist

- [ ] Unit test: Reject passwordless root login
- [ ] Unit test: Accept root login with valid password
- [ ] Integration test: API rejects empty password
- [ ] Manual test: Login flow works correctly
- [ ] Migration test: Temp password generated

## 📚 References

- Detailed analysis: `CRITICAL_ISSUES_DETAILED_REPORT.md` (CRIT-SEC-001 section)
- CWE-287: https://cwe.mitre.org/data/definitions/287.html
- OWASP Authentication Failures: https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/

## 🚀 Deployment Plan

1. Apply fix to hotfix branch
2. Test in staging (30 minutes)
3. Deploy to production
4. Monitor for 24 hours
5. Issue security advisory
6. Notify users

## ⚠️ Breaking Changes

After deployment, any root users without passwords will need to:
1. Check `/config/ROOT_PASSWORD.txt` for temporary password
2. Login with temporary password
3. Change password immediately

## 🔒 Security Advisory Template

```
SECURITY ADVISORY: Critical Authentication Bypass

Severity: CRITICAL
Affected Versions: All versions prior to X.X.X
Fixed in: X.X.X

Issue: Root users could login without providing a password.
Impact: Complete system compromise
Action: Update immediately and verify root password is set.
```

---

**⏰ Timeline:** Fix must be deployed within 24 hours
**👀 Reviewers:** @security-team @backend-team @devops

**See `CRITICAL_ISSUES_DETAILED_REPORT.md` for complete analysis**
