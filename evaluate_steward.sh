#!/usr/bin/env bash
# =============================================================================
# evaluate_steward.sh
# Interactive evaluator for corporate open-source stewardship trustworthiness
# Inspired by: Section D.2 — The Hypothetical: Company X and Cloud Services
#              Section D.1 — The MySQL Parallel and What It Reveals
#              (The Fork in the Road — Sparsh Kapoor | 24BAI10017 | VIT Bhopal)
#
# "The criteria I would use to evaluate whether a corporate steward can
#  be trusted are these: structural alignment, governance transparency,
#  and exit costs."  — Section D.2
#
# Runs the three-criterion evaluation framework from the case study as
# an interactive CLI questionnaire and produces a scored risk report.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'; BLUE='\033[0;34m'

# ── Score tracking ────────────────────────────────────────────────────────────
SCORE_ALIGNMENT=0        # 0–40 points
SCORE_TRANSPARENCY=0     # 0–30 points
SCORE_EXIT=0             # 0–30 points

# ── Helpers ───────────────────────────────────────────────────────────────────
ask_yn() {
    local prompt="$1" reply
    while true; do
        read -rp "$(echo -e "  ${BOLD}${prompt}${RESET} [y/n]: ")" reply
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *) echo "    Please enter y or n." ;;
        esac
    done
}

ask_scale() {
    local prompt="$1" min="$2" max="$3" reply
    while true; do
        read -rp "$(echo -e "  ${BOLD}${prompt}${RESET} [${min}–${max}]: ")" reply
        if [[ "$reply" =~ ^[0-9]+$ ]] && [[ $reply -ge $min ]] && [[ $reply -le $max ]]; then
            echo "$reply"; return
        fi
        echo "    Enter a number between ${min} and ${max}."
    done
}

section() { echo -e "\n${BOLD}${BLUE}══ $* ══${RESET}\n"; }
note()    { echo -e "  ${CYAN}ℹ${RESET}  $*"; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════════╗
  ║        Corporate Steward Trust Evaluator                       ║
  ║  Based on the three-criterion framework from:                  ║
  ║  "The Fork in the Road" — Section D.2                          ║
  ║  Sparsh Kapoor | 24BAI10017 | VIT Bhopal                       ║
  ╚═══════════════════════════════════════════════════════════════╝

  Three criteria determine whether a corporate steward can be trusted:
    1. Structural Alignment (40 pts)
    2. Governance Transparency (30 pts)
    3. Exit Costs for the Community (30 pts)

  Total: 100 points.  Score ≥70 = trustworthy.  <40 = fork warning.
EOF
echo -e "${RESET}"

read -rp "$(echo -e "${BOLD}Name of the project or software being evaluated:${RESET} ")" PROJECT_NAME
read -rp "$(echo -e "${BOLD}Name of the corporate steward being evaluated:${RESET} ")" STEWARD_NAME
echo ""

REPORT_FILE="steward_eval_${PROJECT_NAME// /_}_$(date +%Y%m%d).txt"

# =============================================================================
# CRITERION 1: STRUCTURAL ALIGNMENT (40 pts)
# =============================================================================
section "CRITERION 1: Structural Alignment (40 pts)"
note "Does the company's revenue depend on a genuinely healthy, independent"
note "community — or only on community adoption of its specific commercial offering?"
note "(Reference: Oracle's revenues came from enterprise contracts, not community"
note " health. Red Hat depends on a healthy Linux ecosystem — genuine alignment.)"
echo ""

C1_SCORE=0

# Q1.1 — Revenue model
echo -e "  ${BOLD}Q1.1${RESET} Which best describes the steward's revenue model w.r.t. this project?"
echo "    1) Revenue directly tied to community adoption & health (e.g., Red Hat / Linux)"
echo "    2) Revenue tied to cloud/SaaS built around the project (partial alignment)"
echo "    3) Revenue from unrelated enterprise contracts; project is a side asset"
echo "    4) Revenue through aggressive IP licensing / litigation"
read -rp "  Choice [1–4]: " Q11
case "$Q11" in
    1) C1_SCORE=$((C1_SCORE+20)); note "+20: Strong alignment. Community health = company health." ;;
    2) C1_SCORE=$((C1_SCORE+12)); note "+12: Partial alignment. Watch for cloud-optimised lock-in." ;;
    3) C1_SCORE=$((C1_SCORE+3));  note "+3:  Weak alignment. Oracle/OpenOffice.org pattern." ;;
    4) C1_SCORE=$((C1_SCORE+0));  note "+0:  No alignment. High risk of weaponised IP (Oracle/Java pattern)." ;;
    *) note "Invalid input; scored 0 for Q1.1." ;;
esac

# Q1.2 — Self-hosting / portability
echo ""
note "Company X cloud-adjacent scenario: does the company benefit if users"
note "self-host or use competitors' clouds, or only if they use theirs?"
if ask_yn "Does the project work equally well on any infrastructure (not optimised for steward's cloud)?"; then
    C1_SCORE=$((C1_SCORE+10)); note "+10: Vendor-neutral. Healthy signal."
else
    C1_SCORE=$((C1_SCORE+0));  note "+0:  Cloud-lock-in risk. Self-hosting is disadvantaged."
fi

# Q1.3 — Java lawsuit / prior IP aggression
echo ""
if ask_yn "Has the steward used intellectual property aggressively against open-source projects?"; then
    C1_SCORE=$((C1_SCORE+0));  note "+0:  WARNING. This is the Oracle/Java lawsuit signal. Severe risk."
    echo -e "  ${RED}  ⚠ This is the single most dangerous signal identified in the case study.${RESET}"
    echo -e "  ${RED}  ⚠ Contributors assigning rights to such a company are 'handing ammunition'.${RESET}"
else
    C1_SCORE=$((C1_SCORE+10)); note "+10: No known IP aggression. Good."
fi

echo ""
echo -e "  ${BOLD}Structural Alignment score: ${C1_SCORE}/40${RESET}"

# =============================================================================
# CRITERION 2: GOVERNANCE TRANSPARENCY (30 pts)
# =============================================================================
section "CRITERION 2: Governance Transparency (30 pts)"
note "Are major decisions made through publicly accountable processes, or internally?"
echo ""

C2_SCORE=0

if ask_yn "Are governance/board meetings recorded and minutes published publicly?"; then
    C2_SCORE=$((C2_SCORE+10)); note "+10"
else
    note "+0: Opaque governance. OpenOffice.org problem."
fi
echo ""
if ask_yn "Is there a public RFC / proposal process for major decisions?"; then
    C2_SCORE=$((C2_SCORE+8)); note "+8"
else
    note "+0: No community input mechanism for major changes."
fi
echo ""
if ask_yn "Is there a formal conflict-of-interest policy (corporate reps abstain on related votes)?"; then
    C2_SCORE=$((C2_SCORE+6)); note "+6"
else
    note "+0: Corporate reps can vote on decisions that benefit their employer."
fi
echo ""
if ask_yn "Does the governance document codify a supermajority requirement for licence/arch changes?"; then
    C2_SCORE=$((C2_SCORE+6)); note "+6"
else
    note "+0: Major changes can be made without broad community consent."
fi

echo ""
echo -e "  ${BOLD}Governance Transparency score: ${C2_SCORE}/30${RESET}"

# =============================================================================
# CRITERION 3: EXIT COSTS (30 pts)
# =============================================================================
section "CRITERION 3: Exit Costs (30 pts)"
note "How difficult is it for the community to fork or switch stewards if the"
note "relationship sours? Low exit costs = structural check on steward behaviour."
echo ""

C3_SCORE=0

if ask_yn "Do contributors retain their own copyright (DCO model, no copyright assignment)?"; then
    C3_SCORE=$((C3_SCORE+15)); note "+15: Lowest possible exit cost. Contributors can take their work elsewhere."
else
    note "+0: Copyright assignment = the Oracle lever. Steward has legal lock-in."
    echo -e "  ${RED}  ⚠ This is the highest-risk governance feature identified in the case study.${RESET}"
fi
echo ""
if ask_yn "Is the corporate concentration on the board capped (e.g., one company ≤33%)?"; then
    C3_SCORE=$((C3_SCORE+8)); note "+8"
else
    note "+0: A single company can dominate the board."
fi
echo ""
if ask_yn "Is there a documented process if the steward is acquired by another company?"; then
    C3_SCORE=$((C3_SCORE+7)); note "+7: Acquisition trigger clause. LibreOffice/MariaDB lesson applied."
else
    note "+0: Acquisition could silently transfer power (Sun→Oracle scenario)."
fi

echo ""
echo -e "  ${BOLD}Exit Costs score: ${C3_SCORE}/30${RESET}"

# =============================================================================
# FINAL REPORT
# =============================================================================
TOTAL=$((C1_SCORE + C2_SCORE + C3_SCORE))

{
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  STEWARD TRUST EVALUATION REPORT"
echo "════════════════════════════════════════════════════════════"
echo "  Project  : ${PROJECT_NAME}"
echo "  Steward  : ${STEWARD_NAME}"
echo "  Date     : $(date +%Y-%m-%d)"
echo "  Evaluator: $(whoami)"
echo ""
echo "  ┌─────────────────────────────────┬──────────┬──────────┐"
echo "  │ Criterion                       │ Score    │ Max      │"
echo "  ├─────────────────────────────────┼──────────┼──────────┤"
printf "  │ 1. Structural Alignment         │ %-8d │ 40       │\n" $C1_SCORE
printf "  │ 2. Governance Transparency      │ %-8d │ 30       │\n" $C2_SCORE
printf "  │ 3. Exit Costs                   │ %-8d │ 30       │\n" $C3_SCORE
echo "  ├─────────────────────────────────┼──────────┼──────────┤"
printf "  │ TOTAL                           │ %-8d │ 100      │\n" $TOTAL
echo "  └─────────────────────────────────┴──────────┴──────────┘"
echo ""
} | tee "$REPORT_FILE"

# Verdict
if [[ $TOTAL -ge 70 ]]; then
    echo -e "  ${GREEN}${BOLD}VERDICT: TRUSTWORTHY STEWARD (${TOTAL}/100)${RESET}"
    echo -e "  ${GREEN}  Structural alignment, transparency, and low exit costs are present.${RESET}"
    echo -e "  ${GREEN}  This steward resembles Red Hat's relationship with Linux — genuine alignment.${RESET}"
elif [[ $TOTAL -ge 40 ]]; then
    echo -e "  ${YELLOW}${BOLD}VERDICT: CONDITIONAL TRUST (${TOTAL}/100) — MONITOR CLOSELY${RESET}"
    echo -e "  ${YELLOW}  Some governance features are missing. Resembles Sun/OpenOffice.org:${RESET}"
    echo -e "  ${YELLOW}  acceptable for now, dangerous if the steward is ever acquired.${RESET}"
    echo -e "  ${YELLOW}  Recommendation: Push for governance reform now, not after a crisis.${RESET}"
else
    echo -e "  ${RED}${BOLD}VERDICT: FORK WARNING (${TOTAL}/100) — HIGH RISK${RESET}"
    echo -e "  ${RED}  This steward resembles Oracle's relationship with OpenOffice.org.${RESET}"
    echo -e "  ${RED}  The structural conditions for community capture are present.${RESET}"
    echo -e "  ${RED}  Recommendation: Explore forking, governance ultimatum, or migration.${RESET}"
    echo -e "  ${RED}  Reference: The Fork in the Road — Sections C.1 and C.3${RESET}"
fi

echo ""
echo "  Reference: Sparsh Kapoor | 24BAI10017 | VIT Bhopal"
echo "             'The Fork in the Road' — Section D.2 framework"
echo ""
echo -e "  Full report saved: ${REPORT_FILE}"
