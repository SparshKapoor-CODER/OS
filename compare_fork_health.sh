#!/usr/bin/env bash
# =============================================================================
# compare_fork_health.sh
# Compares two Git repositories on health metrics that matter for governance:
# release cadence, contributor diversity, commit velocity, and bus factor.
#
# Inspired by: Section C.3 — Was the Fork Worth Its Cost?
#   "LibreOffice, by the early 2020s, had over 200 million users, active
#    contributions from thousands of developers across dozens of countries...
#    Apache OpenOffice went years without a major version release."
#   — The Fork in the Road, Sparsh Kapoor | 24BAI10017 | VIT Bhopal
#
# Section D.1 — The MySQL Parallel
#   Compares two repos that share a common ancestor — exactly like
#   LibreOffice vs Apache OpenOffice, or MariaDB vs MySQL.
#
# Usage:
#   ./compare_fork_health.sh /path/to/repo-A /path/to/repo-B [label-A] [label-B]
#   ./compare_fork_health.sh ./libreoffice ./apache-openoffice "LibreOffice" "Apache OO"
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'; BLUE='\033[0;34m'

REPO_A="${1:-.}"
REPO_B="${2:-.}"
LABEL_A="${3:-Project A}"
LABEL_B="${4:-Project B}"

[[ -d "$REPO_A/.git" ]] || { echo "Usage: $0 <repo-A> <repo-B> [label-A] [label-B]"; exit 1; }
[[ -d "$REPO_B/.git" ]] || { echo "Usage: $0 <repo-A> <repo-B> [label-A] [label-B]"; exit 1; }

report() { local f="$1"; shift; echo -e "$*" | tee -a "$f"; }

OUTPUT="fork_health_comparison_$(date +%Y%m%d_%H%M%S).txt"
> "$OUTPUT"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}" | tee -a "$OUTPUT"
cat << EOF | tee -a "$OUTPUT"
  ╔═════════════════════════════════════════════════════════════════╗
  ║           Fork Health Comparison                                 ║
  ║  "Apache OpenOffice went years without a major version release   ║
  ║   and had a fraction of LibreOffice's development activity."     ║
  ║   — The Fork in the Road, Section C.3                           ║
  ╚═════════════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}" | tee -a "$OUTPUT"

# ── Metric collector ──────────────────────────────────────────────────────────
collect_metrics() {
    local repo="$1"
    cd "$repo"

    TOTAL_COMMITS=$(git rev-list --count HEAD 2>/dev/null || echo 0)
    UNIQUE_AUTHORS=$(git log --format='%ae' | sort -u | wc -l | tr -d ' ')
    UNIQUE_DOMAINS=$(git log --format='%ae' | sed 's/.*@//' | sort -u | wc -l | tr -d ' ')

    # Commits in last 365 days
    SINCE_1Y=$(date -d "365 days ago" +%Y-%m-%d 2>/dev/null || date -v-365d +%Y-%m-%d 2>/dev/null || echo "2024-01-01")
    COMMITS_1Y=$(git log --since="$SINCE_1Y" --format='%H' | wc -l | tr -d ' ')

    # Commits in last 90 days
    SINCE_90D=$(date -d "90 days ago" +%Y-%m-%d 2>/dev/null || date -v-90d +%Y-%m-%d 2>/dev/null || echo "2024-10-01")
    COMMITS_90D=$(git log --since="$SINCE_90D" --format='%H' | wc -l | tr -d ' ')
    AUTHORS_90D=$(git log --since="$SINCE_90D" --format='%ae' | sort -u | wc -l | tr -d ' ')

    # Top contributor share (bus factor proxy)
    TOP_AUTHOR_EMAIL=$(git log --format='%ae' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
    TOP_AUTHOR_COUNT=$(git log --format='%ae' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    TOP_AUTHOR_PCT=$(( TOP_AUTHOR_COUNT * 100 / (TOTAL_COMMITS + 1) ))

    # First and last commit
    FIRST_COMMIT=$(git log --reverse --format="%ad" --date=short | head -1)
    LAST_COMMIT=$(git log --format="%ad" --date=short | head -1)

    # Tagged releases
    TAG_COUNT=$(git tag -l | wc -l | tr -d ' ')
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "(none)")

    # DCO sign-off rate
    SIGNED=$(git log --format="%B" | grep -c "^Signed-off-by:" || true)
    DCO_PCT=$(( SIGNED * 100 / (TOTAL_COMMITS + 1) ))

    cd - > /dev/null
}

# ── Collect for both repos ────────────────────────────────────────────────────
echo -e "${BOLD}Analysing ${LABEL_A}...${RESET}"
collect_metrics "$REPO_A"
A_TOTAL="$TOTAL_COMMITS"; A_AUTHORS="$UNIQUE_AUTHORS"; A_DOMAINS="$UNIQUE_DOMAINS"
A_1Y="$COMMITS_1Y"; A_90D="$COMMITS_90D"; A_AUTH90="$AUTHORS_90D"
A_TOP_PCT="$TOP_AUTHOR_PCT"; A_TOP_EMAIL="$TOP_AUTHOR_EMAIL"
A_FIRST="$FIRST_COMMIT"; A_LAST="$LAST_COMMIT"
A_TAGS="$TAG_COUNT"; A_LTAG="$LATEST_TAG"; A_DCO="$DCO_PCT"

echo -e "${BOLD}Analysing ${LABEL_B}...${RESET}"
collect_metrics "$REPO_B"
B_TOTAL="$TOTAL_COMMITS"; B_AUTHORS="$UNIQUE_AUTHORS"; B_DOMAINS="$UNIQUE_DOMAINS"
B_1Y="$COMMITS_1Y"; B_90D="$COMMITS_90D"; B_AUTH90="$AUTHORS_90D"
B_TOP_PCT="$TOP_AUTHOR_PCT"; B_TOP_EMAIL="$TOP_AUTHOR_EMAIL"
B_FIRST="$FIRST_COMMIT"; B_LAST="$LAST_COMMIT"
B_TAGS="$TAG_COUNT"; B_LTAG="$LATEST_TAG"; B_DCO="$DCO_PCT"

# ── Render comparison table ───────────────────────────────────────────────────
winner() {
    # $1 = A value, $2 = B value, $3 = "higher" or "lower" is better
    local va="$1" vb="$2" dir="${3:-higher}"
    if [[ "$dir" == "higher" ]]; then
        [[ $va -gt $vb ]] && echo "${GREEN}▲ ${LABEL_A}${RESET}" && return
        [[ $vb -gt $va ]] && echo "${RED}▼ ${LABEL_B}${RESET}" && return
    else
        [[ $va -lt $vb ]] && echo "${GREEN}▲ ${LABEL_A}${RESET}" && return
        [[ $vb -lt $va ]] && echo "${RED}▼ ${LABEL_B}${RESET}" && return
    fi
    echo "${YELLOW}Tie${RESET}"
}

echo "" | tee -a "$OUTPUT"
echo -e "${BOLD}${BLUE}════  Health Comparison Report  ════${RESET}" | tee -a "$OUTPUT"
echo "" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s %s\n" "Metric" "$LABEL_A" "$LABEL_B" "Winner" | tee -a "$OUTPUT"
printf "  %-35s %-20s %-20s %s\n" "$(printf '─%.0s' {1..35})" "$(printf '─%.0s' {1..20})" "$(printf '─%.0s' {1..20})" "$(printf '─%.0s' {1..15})" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Total commits" "$A_TOTAL" "$B_TOTAL"
echo -e "$(winner $A_TOTAL $B_TOTAL higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Unique contributors (all time)" "$A_AUTHORS" "$B_AUTHORS"
echo -e "$(winner $A_AUTHORS $B_AUTHORS higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Contributor email domains" "$A_DOMAINS" "$B_DOMAINS"
echo -e "$(winner $A_DOMAINS $B_DOMAINS higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Commits (last 12 months)" "$A_1Y" "$B_1Y"
echo -e "$(winner $A_1Y $B_1Y higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Commits (last 90 days)" "$A_90D" "$B_90D"
echo -e "$(winner $A_90D $B_90D higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Active contributors (90 days)" "$A_AUTH90" "$B_AUTH90"
echo -e "$(winner $A_AUTH90 $B_AUTH90 higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Top contributor % (bus factor)" "${A_TOP_PCT}%" "${B_TOP_PCT}%"
echo -e "$(winner $A_TOP_PCT $B_TOP_PCT lower)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "Tagged releases" "$A_TAGS" "$B_TAGS"
echo -e "$(winner $A_TAGS $B_TAGS higher)" | tee -a "$OUTPUT"

printf "  %-35s %-20s %-20s " "DCO sign-off rate %" "${A_DCO}%" "${B_DCO}%"
echo -e "$(winner $A_DCO $B_DCO higher)" | tee -a "$OUTPUT"

echo "" | tee -a "$OUTPUT"
echo -e "${BOLD}${BLUE}════  Additional Details  ════${RESET}" | tee -a "$OUTPUT"
echo "" | tee -a "$OUTPUT"
echo "  ${LABEL_A}:"
echo "    First commit : ${A_FIRST}"
echo "    Last commit  : ${A_LAST}"
echo "    Latest tag   : ${A_LTAG}"
echo "    Top author   : ${A_TOP_EMAIL} (${A_TOP_PCT}% of commits)"
echo ""
echo "  ${LABEL_B}:"
echo "    First commit : ${B_FIRST}"
echo "    Last commit  : ${B_LAST}"
echo "    Latest tag   : ${B_LTAG}"
echo "    Top author   : ${B_TOP_EMAIL} (${B_TOP_PCT}% of commits)"

# ── Interpretation ────────────────────────────────────────────────────────────
echo "" | tee -a "$OUTPUT"
echo -e "${BOLD}${BLUE}════  Interpretation (LibreOffice / MariaDB Framework)  ════${RESET}" | tee -a "$OUTPUT"
echo "" | tee -a "$OUTPUT"
echo "  A healthy fork (LibreOffice pattern) shows:"
echo "    ✓ Higher recent commit velocity than the original"
echo "    ✓ More diverse contributor domains (not concentrated in one company)"
echo "    ✓ Lower top-contributor % (more distributed bus factor)"
echo "    ✓ More frequent tagged releases"
echo "    ✓ Higher DCO sign-off rate (better governance hygiene)"
echo ""
echo "  A stagnating original (Apache OpenOffice pattern) shows:"
echo "    ✗ Declining commit velocity over time"
echo "    ✗ Shrinking active contributor pool"
echo "    ✗ Few or no major version releases in recent years"
echo ""
echo -e "  ${CYAN}Reference: Section C.3 & D.1 — The Fork in the Road${RESET}"
echo -e "  ${CYAN}Sparsh Kapoor | 24BAI10017 | VIT Bhopal${RESET}"
echo ""
echo -e "  Report saved to: ${OUTPUT}"
