#!/bin/bash
set -e

#═══════════════════════════════════════════════════════════════════
# Audiobookshelf Critical Fixes - Automated Application Script
#═══════════════════════════════════════════════════════════════════
#
# This script applies all 3 critical fixes automatically:
# 1. Fix passwordless root login vulnerability (CRIT-SEC-001)
# 2. Fix variable reference error in BackupManager (CRIT-STAB-001)
# 3. Fix class name typo (CRIT-STAB-002)
#
# Usage: ./apply-critical-fixes.sh [--dry-run]
#
#═══════════════════════════════════════════════════════════════════

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

#═══════════════════════════════════════════════════════════════════
# Helper Functions
#═══════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

create_backup() {
    local file=$1
    local backup="${file}.backup-$(date +%Y%m%d-%H%M%S)"

    if [ -f "$file" ]; then
        if [ "$DRY_RUN" = false ]; then
            cp "$file" "$backup"
            log_success "Created backup: $backup"
        else
            log_info "Would create backup: $backup"
        fi
    else
        log_error "File not found: $file"
        return 1
    fi
}

#═══════════════════════════════════════════════════════════════════
# Pre-flight Checks
#═══════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Audiobookshelf Critical Fixes - Automated Application     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warning "DRY RUN MODE - No changes will be made"
    echo ""
fi

# Check we're in the right directory
if [ ! -f "$PROJECT_ROOT/package.json" ]; then
    log_error "Not in Audiobookshelf project root!"
    log_error "Expected to find package.json at: $PROJECT_ROOT"
    exit 1
fi

# Check if audiobookshelf is in package.json
if ! grep -q '"name": "audiobookshelf"' "$PROJECT_ROOT/package.json"; then
    log_error "This doesn't appear to be the Audiobookshelf project"
    exit 1
fi

log_success "Found Audiobookshelf project at: $PROJECT_ROOT"

# Check required files exist
FILES_TO_FIX=(
    "$PROJECT_ROOT/server/auth/LocalAuthStrategy.js"
    "$PROJECT_ROOT/server/managers/BackupManager.js"
    "$PROJECT_ROOT/server/managers/AudioMetadataManager.js"
)

for file in "${FILES_TO_FIX[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Required file not found: $file"
        exit 1
    fi
done

log_success "All required files found"
echo ""

#═══════════════════════════════════════════════════════════════════
# Fix 1: Passwordless Root Login (CRIT-SEC-001)
#═══════════════════════════════════════════════════════════════════

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Fix 1: Passwordless Root Login Vulnerability                │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

FILE1="$PROJECT_ROOT/server/auth/LocalAuthStrategy.js"

log_info "Processing: $FILE1"

# Create backup
create_backup "$FILE1"

# Check if fix is already applied
if grep -q "SECURITY FIX: Never allow passwordless root login" "$FILE1"; then
    log_warning "Fix already applied! Skipping..."
else
    if [ "$DRY_RUN" = false ]; then
        # Apply fix to lines 66-77
        # This removes the passwordless login approval
        sed -i.tmp '/Check passwordless root user/,/^    }/c\
  // Check passwordless root user\
  if (user.type === '\''root'\'' && !user.pash) {\
    // SECURITY FIX: Never allow passwordless root login\
    this.logFailedLoginAttempt(req, user.username, '\''Root user must have a password set'\'')\
    done(null, null)\
    return\
  }' "$FILE1"

        # Also fix the comparePassword method (line 134)
        sed -i.tmp 's/if (user\.type === '\''root'\'' && !password && !user\.pash) return true/\/\/ SECURITY: Remove special case for root passwordless login\n    if (!password || !user.pash) return false/' "$FILE1"

        # Clean up temp file
        rm -f "${FILE1}.tmp"

        log_success "Applied security fix to LocalAuthStrategy.js"
    else
        log_info "Would apply security fix to LocalAuthStrategy.js"
    fi
fi

echo ""

#═══════════════════════════════════════════════════════════════════
# Fix 2: Variable Reference Error (CRIT-STAB-001)
#═══════════════════════════════════════════════════════════════════

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Fix 2: Variable Reference Error in BackupManager            │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

FILE2="$PROJECT_ROOT/server/managers/BackupManager.js"

log_info "Processing: $FILE2"

# Create backup
create_backup "$FILE2"

# Check if fix is already applied
if grep -q "Logger.error('\[BackupManager\] Failed to move backup file', tempPath, error)" "$FILE2"; then
    log_warning "Fix already applied! Skipping..."
else
    if [ "$DRY_RUN" = false ]; then
        # Fix the variable reference (change 'path' to 'tempPath')
        sed -i.tmp "s/Logger\.error('\[BackupManager\] Failed to move backup file', path,/Logger.error('[BackupManager] Failed to move backup file', tempPath,/" "$FILE2"

        # Clean up temp file
        rm -f "${FILE2}.tmp"

        log_success "Applied variable fix to BackupManager.js"
    else
        log_info "Would apply variable fix to BackupManager.js"
    fi
fi

echo ""

#═══════════════════════════════════════════════════════════════════
# Fix 3: Class Name Typo (CRIT-STAB-002)
#═══════════════════════════════════════════════════════════════════

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Fix 3: Class Name Typo in AudioMetadataManager              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

FILE3="$PROJECT_ROOT/server/managers/AudioMetadataManager.js"

log_info "Processing: $FILE3"

# Create backup
create_backup "$FILE3"

# Check if typo exists
if grep -q "AudioMetadataMangaer" "$FILE3"; then
    if [ "$DRY_RUN" = false ]; then
        # Fix the class name typo
        sed -i.tmp 's/AudioMetadataMangaer/AudioMetadataManager/g' "$FILE3"

        # Clean up temp file
        rm -f "${FILE3}.tmp"

        log_success "Applied class name fix to AudioMetadataManager.js"
    else
        log_info "Would apply class name fix to AudioMetadataManager.js"
    fi
else
    log_warning "Fix already applied! Skipping..."
fi

echo ""

#═══════════════════════════════════════════════════════════════════
# Verification
#═══════════════════════════════════════════════════════════════════

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Verification                                                 │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""

if [ "$DRY_RUN" = false ]; then
    ERRORS=0

    # Verify Fix 1
    if grep -q "SECURITY FIX: Never allow passwordless root login" "$FILE1"; then
        log_success "✓ Fix 1 verified: Passwordless root login disabled"
    else
        log_error "✗ Fix 1 failed: Security fix not found"
        ((ERRORS++))
    fi

    # Verify Fix 2
    if grep -q "Logger.error('\[BackupManager\] Failed to move backup file', tempPath, error)" "$FILE2"; then
        log_success "✓ Fix 2 verified: Variable reference corrected"
    else
        log_error "✗ Fix 2 failed: Variable fix not applied"
        ((ERRORS++))
    fi

    # Verify Fix 3
    if ! grep -q "AudioMetadataMangaer" "$FILE3"; then
        log_success "✓ Fix 3 verified: Class name corrected"
    else
        log_error "✗ Fix 3 failed: Typo still present"
        ((ERRORS++))
    fi

    echo ""

    if [ $ERRORS -eq 0 ]; then
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                   ALL FIXES APPLIED ✓                        ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        log_success "All 3 critical fixes have been successfully applied!"
        echo ""
        echo "Next steps:"
        echo "1. Review the changes: git diff"
        echo "2. Test the application manually"
        echo "3. Create a commit: git add . && git commit -m 'fix: Apply critical security and stability fixes'"
        echo "4. Deploy to production"
        echo ""
        log_warning "Important: If you had a passwordless root account, you'll need to set a password!"
        echo ""
    else
        log_error "Some fixes failed to apply. Please review the errors above."
        exit 1
    fi
else
    log_info "Dry run complete. No changes were made."
    log_info "Run without --dry-run to apply fixes."
fi

exit 0
