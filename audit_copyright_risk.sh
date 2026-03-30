#!/usr/bin/env bash
# =============================================================================
# audit_copyright_risk.sh
# Audits a Git repository for copyright concentration and governance risk
# Inspired by: Section A.2 — The Structural Fault Line Beneath the Success
#              Section B.2 — Why Corporate Control Crosses an Ethical Line
#              (The Fork in the Road — Sparsh Kapoor | 24BAI10017 | VIT Bhopal)
#
# What it checks:
#   1. Commit authorship concentration (are 80%+ of commits from one org/domain?)
#   2. Presence of DCO sign-offs vs. absence (copyright-assignment risk signal)
#   3. Copyright headers in source files — who do they name?
#   4. CLA / copyright assignment files in the repo
#   5. Corporate concentration in recent commits (last 90 days)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[PASS]${RESET}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
fail()    { echo -e "${RED}[RISK]${RESET}  $*"; }
section() { echo -e "\n${BOLD}━━━  $*  ━━━${RESET}"; }

REPO="${1:-.}"
[[ -d "$REPO/.git" ]] || { echo "Usage: $0 <path-to-git-repo>"; exit 1; }
cd "$REPO"

REPORT_FILE="copyright_audit_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$REPORT_FILE") 2>&1

echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════════════════════╗
  ║         Copyright & Governance Risk Auditor              ║
  ║  "The community had been living with a loaded pistol     ║
  ║   they trusted would not be fired."                      ║
  ║   — The Fork in the Road, Section A.3                    ║
  ╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"
info "Auditing: $(pwd)"
info "Report will be saved to: ${REPORT_FILE}"

# ── 1. Basic stats ────────────────────────────────────────────────────────────
section "1. Repository Overview"
TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
TOTAL_CONTRIBUTORS=$(git log --format='%ae' | sort -u | wc -l | tr -d ' ')
FIRST_COMMIT=$(git log --reverse --format="%ad" --date=short | head -1)
LAST_COMMIT=$(git log  --format="%ad" --date=short | head -1)

echo "  Total commits      : ${TOTAL_COMMITS}"
echo "  Unique contributors: ${TOTAL_CONTRIBUTORS}"
echo "  First commit       : ${FIRST_COMMIT}"
echo "  Last commit        : ${LAST_COMMIT}"

# ── 2. Commit authorship concentration ────────────────────────────────────────
section "2. Commit Authorship — Corporate Concentration"
info "Top 10 contributor email domains (by commit count):"

git log --format='%ae' \
    | sed 's/.*@//' \
    | sort | uniq -c | sort -rn \
    | head -10 \
    | while read -r count domain; do
        pct=$(( count * 100 / TOTAL_COMMITS ))
        bar=$(printf '█%.0s' $(seq 1 $((pct / 5 + 1))))
        if [[ $pct -ge 70 ]]; then
            echo -e "  ${RED}${pct}%${RESET} $bar  ${domain}  (${count} commits)"
        elif [[ $pct -ge 40 ]]; then
            echo -e "  ${YELLOW}${pct}%${RESET} $bar  ${domain}  (${count} commits)"
        else
            echo -e "  ${GREEN}${pct}%${RESET} $bar  ${domain}  (${count} commits)"
        fi
    done

# Top domain percentage check
TOP_DOMAIN_COUNT=$(git log --format='%ae' | sed 's/.*@//' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
TOP_DOMAIN=$(git log --format='%ae' | sed 's/.*@//' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
TOP_PCT=$(( TOP_DOMAIN_COUNT * 100 / TOTAL_COMMITS ))

echo ""
if [[ $TOP_PCT -ge 70 ]]; then
    fail "CONCENTRATION RISK: '${TOP_DOMAIN}' holds ${TOP_PCT}% of commit history."
    fail "This mirrors the OpenOffice.org pattern: one entity dominates contribution."
elif [[ $TOP_PCT -ge 40 ]]; then
    warn "MODERATE RISK: '${TOP_DOMAIN}' holds ${TOP_PCT}% of commits. Monitor closely."
else
    ok "Commit authorship appears reasonably distributed. Top domain: ${TOP_PCT}%."
fi

# ── 3. Recent concentration (last 90 days) ────────────────────────────────────
section "3. Recent Concentration (Last 90 Days)"
SINCE_DATE=$(date -d "90 days ago" +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d)
RECENT_TOTAL=$(git log --since="$SINCE_DATE" --format='%ae' | wc -l | tr -d ' ')

if [[ $RECENT_TOTAL -eq 0 ]]; then
    warn "No commits in the last 90 days. Project may be inactive."
else
    info "Last 90 days — top domains:"
    git log --since="$SINCE_DATE" --format='%ae' \
        | sed 's/.*@//' \
        | sort | uniq -c | sort -rn \
        | head -5 \
        | while read -r count domain; do
            pct=$(( count * 100 / RECENT_TOTAL ))
            echo "    ${pct}%  ${domain}  (${count} commits)"
        done
fi

# ── 4. DCO sign-off audit ─────────────────────────────────────────────────────
section "4. DCO Sign-Off Audit"
info "Checking commits for 'Signed-off-by:' lines..."

SIGNED=$(git log --format="%B" | grep -c "^Signed-off-by:" || true)
UNSIGNED=$((TOTAL_COMMITS - SIGNED))

echo "  Commits with DCO sign-off   : ${SIGNED}"
echo "  Commits WITHOUT DCO sign-off: ${UNSIGNED}"

if [[ $UNSIGNED -eq 0 ]]; then
    ok "All commits are DCO signed. Contributors retain their own copyright."
elif [[ $UNSIGNED -lt $((TOTAL_COMMITS / 10)) ]]; then
    warn "A few commits lack DCO sign-off (<10%). Consider enforcing via CI."
else
    fail "GOVERNANCE RISK: ${UNSIGNED} commits lack DCO sign-off."
    fail "This project may rely on implicit copyright assignment — or have no clear copyright at all."
    fail "Recommend: add a DCO bot to CI and update CONTRIBUTING.md."
fi

# ── 5. CLA / copyright assignment file detection ──────────────────────────────
section "5. CLA / Copyright Assignment File Detection"
CLA_PATTERNS=("CLA" "ICLA" "CCLA" "COPYRIGHT_ASSIGNMENT" "contributor-license" "cla.md" "CLA.md")
FOUND_CLA=0

for pattern in "${CLA_PATTERNS[@]}"; do
    if find . -not -path './.git/*' -iname "*${pattern}*" 2>/dev/null | grep -q .; then
        found_file=$(find . -not -path './.git/*' -iname "*${pattern}*" | head -1)
        warn "CLA-related file found: ${found_file}"
        warn "This may indicate a copyright assignment requirement (Oracle/Sun pattern)."
        FOUND_CLA=1
    fi
done

[[ $FOUND_CLA -eq 0 ]] && ok "No CLA / copyright assignment files detected."

# Check for DCO file
if [[ -f "./DCO" ]]; then
    ok "DCO file present — project uses Developer Certificate of Origin."
else
    warn "No DCO file found. Consider adding one (see init_oss_project.sh)."
fi

# ── 6. Copyright header scan ──────────────────────────────────────────────────
section "6. Copyright Header Analysis"
info "Scanning source files for copyright headers..."

declare -A org_counts
total_with_header=0

while IFS= read -r -d '' file; do
    header=$(head -5 "$file" 2>/dev/null || true)
    if echo "$header" | grep -qi "copyright"; then
        total_with_header=$((total_with_header + 1))
        org=$(echo "$header" | grep -i "copyright" | head -1)
        # Extract year + entity (crude but effective)
        entity=$(echo "$org" | sed 's/.*[Cc]opyright[^0-9]*//' | sed 's/[0-9][-,0-9 ]*//' | sed 's/^[[:space:]]*//' | cut -c1-40)
        org_counts["$entity"]=$(( ${org_counts["$entity"]:-0} + 1 ))
    fi
done < <(find . -not -path './.git/*' \( -name "*.py" -o -name "*.java" -o -name "*.js" -o -name "*.ts" -o -name "*.c" -o -name "*.cpp" -o -name "*.go" -o -name "*.sh" \) -print0 2>/dev/null)

if [[ ${#org_counts[@]} -eq 0 ]]; then
    warn "No copyright headers found in source files."
else
    echo "  Copyright holders found in source headers:"
    for entity in "${!org_counts[@]}"; do
        echo "    ${org_counts[$entity]} files  →  ${entity}"
    done
fi

# ── 7. Governance file check ──────────────────────────────────────────────────
section "7. Governance & Community Files"
files_to_check=(
    "GOVERNANCE.md:Governance policy (board composition, decision rules)"
    "CONTRIBUTING.md:Contribution guidelines"
    "CODE_OF_CONDUCT.md:Code of conduct"
    "SECURITY.md:Security policy"
    "DCO:Developer Certificate of Origin"
    "LICENCE:Licence file"
    "LICENSE:Licence file (US spelling)"
)

for entry in "${files_to_check[@]}"; do
    fname="${entry%%:*}"
    desc="${entry##*:}"
    if [[ -f "./${fname}" ]]; then
        ok "${fname} — ${desc}"
    else
        warn "MISSING: ${fname} — ${desc}"
    fi
done

# ── 8. Risk summary ───────────────────────────────────────────────────────────
section "8. Risk Summary"
echo ""
echo -e "  ${BOLD}Concentration Risk Tier:${RESET}"
if [[ $TOP_PCT -ge 70 ]]; then
    echo -e "  ${RED}  ██████████  HIGH   — Single entity dominates (${TOP_PCT}%). Structural alarm.${RESET}"
elif [[ $TOP_PCT -ge 40 ]]; then
    echo -e "  ${YELLOW}  ██████░░░░  MEDIUM — Significant concentration (${TOP_PCT}%). Monitor.${RESET}"
else
    echo -e "  ${GREEN}  ███░░░░░░░  LOW    — Reasonably distributed (${TOP_PCT}%). Healthy signal.${RESET}"
fi

echo ""
echo -e "  ${BOLD}DCO / Copyright Risk:${RESET}"
if [[ $UNSIGNED -gt $((TOTAL_COMMITS / 10)) ]]; then
    echo -e "  ${RED}  HIGH   — Majority of commits lack DCO sign-off.${RESET}"
elif [[ $FOUND_CLA -eq 1 ]]; then
    echo -e "  ${YELLOW}  MEDIUM — CLA / copyright assignment file found.${RESET}"
else
    echo -e "  ${GREEN}  LOW    — DCO present or no CLA detected.${RESET}"
fi

echo ""
echo -e "  ${CYAN}Full report saved: ${REPORT_FILE}${RESET}"
echo ""
echo -e "  ${BOLD}Reference:${RESET} Section A.2 & D.3 — The Fork in the Road"
echo -e "  ${BOLD}Author   :${RESET} Sparsh Kapoor | 24BAI10017 | VIT Bhopal"
