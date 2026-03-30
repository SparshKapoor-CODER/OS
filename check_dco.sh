#!/usr/bin/env bash
# =============================================================================
# check_dco.sh
# CI/CD script: enforces Developer Certificate of Origin sign-off on all
# commits in a pull request / branch, blocking merges if sign-off is missing.
#
# Inspired by: Section D.3 — Governance Recommendations for a New Project
#   "The Developer Certificate of Origin (DCO) model — in which contributors
#    certify that they have the right to submit their code under the project's
#    licence, without transferring rights — is a well-tested mechanism that
#    preserves contributor autonomy while maintaining licence coherence."
#   — The Fork in the Road, Sparsh Kapoor | 24BAI10017 | VIT Bhopal
#
# Usage (local):
#   ./check_dco.sh [base_branch]
#   ./check_dco.sh main
#
# Usage (GitHub Actions):
#   - run: bash check_dco.sh ${{ github.base_ref }}
#
# Exit codes:
#   0 — all commits are signed off
#   1 — one or more commits are missing DCO sign-off
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[DCO-CHECK]${RESET} $*"; }
ok()      { echo -e "${GREEN}[PASS]${RESET}      $*"; }
fail()    { echo -e "${RED}[FAIL]${RESET}      $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}      $*"; }

# ── Configuration ──────────────────────────────────────────────────────────────
BASE_BRANCH="${1:-main}"
# Optionally allow bot/merge commits to skip DCO check
ALLOW_BOTS="${ALLOW_BOTS:-true}"
# Bot email patterns (GitHub merge bots, Dependabot, etc.)
BOT_PATTERNS=("noreply@github.com" "dependabot" "renovate" "github-actions")

echo -e "${BOLD}"
echo "  ╔════════════════════════════════════════╗"
echo "  ║  Developer Certificate of Origin Check ║"
echo "  ║  Protecting contributor autonomy        ║"
echo "  ╚════════════════════════════════════════╝"
echo -e "${RESET}"

# ── Detect commit range ────────────────────────────────────────────────────────
if git rev-parse "origin/${BASE_BRANCH}" &>/dev/null; then
    MERGE_BASE=$(git merge-base HEAD "origin/${BASE_BRANCH}" 2>/dev/null || echo "")
elif git rev-parse "${BASE_BRANCH}" &>/dev/null; then
    MERGE_BASE=$(git merge-base HEAD "${BASE_BRANCH}" 2>/dev/null || echo "")
else
    warn "Cannot resolve base branch '${BASE_BRANCH}'. Checking last 20 commits instead."
    MERGE_BASE=$(git rev-parse "HEAD~20" 2>/dev/null || git rev-parse --root HEAD)
fi

if [[ -z "$MERGE_BASE" ]]; then
    COMMIT_RANGE="HEAD"
else
    COMMIT_RANGE="${MERGE_BASE}..HEAD"
fi

COMMITS=$(git log --format="%H" "$COMMIT_RANGE" 2>/dev/null || true)
COMMIT_COUNT=$(echo "$COMMITS" | grep -c . || true)

info "Base branch  : ${BASE_BRANCH}"
info "Commit range : ${COMMIT_RANGE}"
info "Commits found: ${COMMIT_COUNT}"
echo ""

[[ $COMMIT_COUNT -eq 0 ]] && { ok "No commits to check."; exit 0; }

# ── Check each commit ──────────────────────────────────────────────────────────
FAIL_COUNT=0
PASS_COUNT=0
SKIP_COUNT=0

while IFS= read -r commit_hash; do
    [[ -z "$commit_hash" ]] && continue

    commit_msg=$(git log -1 --format="%B" "$commit_hash")
    author_email=$(git log -1 --format="%ae" "$commit_hash")
    short_hash="${commit_hash:0:8}"
    subject=$(git log -1 --format="%s" "$commit_hash")

    # ── Bot / merge commit bypass ────────────────────────────────────────────
    if [[ "$ALLOW_BOTS" == "true" ]]; then
        IS_BOT=false
        for pattern in "${BOT_PATTERNS[@]}"; do
            if echo "$author_email" | grep -qi "$pattern"; then
                IS_BOT=true; break
            fi
        done
        # Also skip GitHub merge commits ("Merge pull request #...")
        if echo "$subject" | grep -qE "^Merge (pull request|branch)"; then
            IS_BOT=true
        fi
        if [[ "$IS_BOT" == "true" ]]; then
            warn "  SKIP  ${short_hash}  [bot/merge]  ${subject:0:55}"
            SKIP_COUNT=$((SKIP_COUNT + 1))
            continue
        fi
    fi

    # ── Check for Signed-off-by ──────────────────────────────────────────────
    if echo "$commit_msg" | grep -qE "^Signed-off-by: .+ <.+@.+>"; then
        signoff=$(echo "$commit_msg" | grep -E "^Signed-off-by:" | head -1)
        ok "  PASS  ${short_hash}  ${subject:0:45}"
        echo -e "         ${GREEN}${signoff}${RESET}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        fail "  FAIL  ${short_hash}  ${subject:0:45}"
        echo -e "         ${RED}Missing: Signed-off-by: Name <email>${RESET}"
        echo -e "         ${RED}Author : ${author_email}${RESET}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

done <<< "$COMMITS"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}Passed : ${PASS_COUNT}${RESET}"
echo -e "  ${YELLOW}Skipped: ${SKIP_COUNT}${RESET}  (bots / merge commits)"
echo -e "  ${RED}Failed : ${FAIL_COUNT}${RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo ""
    fail "DCO sign-off missing on ${FAIL_COUNT} commit(s). Merge blocked."
    echo ""
    echo -e "  ${BOLD}How to fix:${RESET}"
    echo "  ┌──────────────────────────────────────────────────────────┐"
    echo "  │  For new commits:                                        │"
    echo "  │    git commit -s -m \"your message\"                       │"
    echo "  │                                                          │"
    echo "  │  To add sign-off to the last N commits:                 │"
    echo "  │    git rebase HEAD~N --signoff                           │"
    echo "  │    git push --force-with-lease                           │"
    echo "  │                                                          │"
    echo "  │  What this means:                                        │"
    echo "  │    You certify under DCO 1.1 that you have the right     │"
    echo "  │    to submit this contribution. You RETAIN COPYRIGHT.    │"
    echo "  │    No rights are transferred to any corporation.         │"
    echo "  └──────────────────────────────────────────────────────────┘"
    echo ""
    echo -e "  ${CYAN}Reference: Section D.3 — The Fork in the Road${RESET}"
    echo -e "  ${CYAN}Sparsh Kapoor | 24BAI10017 | VIT Bhopal${RESET}"
    exit 1
else
    echo ""
    ok "All commits carry DCO sign-off. Contributors retain their own copyright."
    ok "This project does not require a Joint Copyright Assignment."
    ok "No single corporation can legally capture this contribution."
    echo ""
    echo -e "  ${CYAN}\"This single change eliminates the most dangerous lever that${RESET}"
    echo -e "  ${CYAN} corporate stewards can pull.\"${RESET}"
    echo -e "  ${CYAN} — The Fork in the Road, Section D.3${RESET}"
    exit 0
fi
