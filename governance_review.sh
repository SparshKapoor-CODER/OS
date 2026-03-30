#!/usr/bin/env bash
# =============================================================================
# governance_review.sh
# Runs the 60-day governance review triggered by a corporate acquisition event
# Produces a structured review document and checklist for the board.
#
# Inspired by: Section A.3 — Why Oracle Was the Trigger
#   "Oracle's arrival made that trust impossible to sustain."
#   The key lesson: an acquisition can change everything without changing
#   a single line of the governance documents.
#
# Section D.3 — Governance Recommendations for a New Project
#   "An acquisition should trigger a governance review and, potentially, a
#    reduction in the acquired company's representation until the new parent
#    has demonstrated its commitment to the project's values."
#   — The Fork in the Road, Sparsh Kapoor | 24BAI10017 | VIT Bhopal
#
# Usage:
#   ./governance_review.sh
#   (Interactive — prompts for all inputs)
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'; BLUE='\033[0;34m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
section() { echo -e "\n${BOLD}${BLUE}━━━  $*  ━━━${RESET}\n"; }
ask()     { local p="$1" d="$2" r; read -rp "$(echo -e "${BOLD}${p}${RESET} [${d}]: ")" r; echo "${r:-$d}"; }
ask_yn()  {
    local prompt="$1" reply
    while true; do
        read -rp "$(echo -e "  ${BOLD}${prompt}${RESET} [y/n]: ")" reply
        case "${reply,,}" in y|yes) return 0;; n|no) return 1;; esac
    done
}

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════════════════════════╗
  ║          Acquisition-Triggered Governance Review              ║
  ║  "What Oracle's acquisition changed was not the structure,    ║
  ║   but the trustworthiness of the entity that structure        ║
  ║   empowered."  — The Fork in the Road, Section A.3           ║
  ╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

# ── Inputs ────────────────────────────────────────────────────────────────────
PROJECT_NAME=$(ask    "Project name"                               "my-oss-project")
FOUNDATION=$(ask      "Foundation / governing body name"           "Community Foundation")
ACQUIRED_CO=$(ask     "Company being acquired"                     "Original Steward Inc.")
ACQUIRING_CO=$(ask    "Acquiring company"                          "NewParent Corp.")
ACQ_DATE=$(ask        "Acquisition completion date (YYYY-MM-DD)"   "$(date +%Y-%m-%d)")
REVIEW_CHAIR=$(ask    "Name of review committee chair"             "Chairperson Name")
CORP_CAP=$(ask        "Current board concentration cap (%)"        "33")
AFFECTED_SEATS=$(ask  "How many board seats does ${ACQUIRED_CO} currently hold?" "2")
TOTAL_SEATS=$(ask     "Total board seats"                          "7")

REVIEW_DEADLINE=$(date -d "${ACQ_DATE} +60 days" +%Y-%m-%d 2>/dev/null \
    || date -v+60d -j -f "%Y-%m-%d" "$ACQ_DATE" +%Y-%m-%d 2>/dev/null \
    || echo "60 days from ${ACQ_DATE}")

OUTPUT="governance_review_${PROJECT_NAME// /_}_${ACQ_DATE}.md"

# ── Generate review document ──────────────────────────────────────────────────
cat > "$OUTPUT" << MDEOF
# Acquisition-Triggered Governance Review

**Project:** ${PROJECT_NAME}
**Governing Body:** ${FOUNDATION}
**Review Triggered By:** Acquisition of ${ACQUIRED_CO} by ${ACQUIRING_CO}
**Acquisition Date:** ${ACQ_DATE}
**Review Deadline (60 days):** ${REVIEW_DEADLINE}
**Review Chair:** ${REVIEW_CHAIR}
**Document Created:** $(date +%Y-%m-%d)

---

> *"An acquisition should trigger a governance review and, potentially, a reduction in the
> acquired company's representation until the new parent has demonstrated its commitment
> to the project's values."*
> — The Fork in the Road, Section D.3 | Sparsh Kapoor | 24BAI10017 | VIT Bhopal

---

## 1. Situation Summary

${ACQUIRED_CO}, which currently holds **${AFFECTED_SEATS} of ${TOTAL_SEATS} board seats**
($(( AFFECTED_SEATS * 100 / TOTAL_SEATS ))%), has been acquired by **${ACQUIRING_CO}**.

Under the project's GOVERNANCE.md, this acquisition automatically triggers a 60-day
governance review. The purpose of this review is not to assume bad faith on the part of
${ACQUIRING_CO}, but to apply the structural lesson of the Oracle/OpenOffice.org acquisition:

> **The ethical risk of a copyright assignment or governance authority is inseparable from
> the character and intentions of the entity receiving it. The same structure can be benign
> under one steward and dangerous under another.**

---

## 2. Immediate Protective Measures (Effective Immediately)

The following measures take effect automatically upon acquisition, pending review:

- [ ] ${ACQUIRED_CO} board members' voting rights are **suspended** on decisions that
      primarily benefit ${ACQUIRING_CO} (conflict-of-interest policy, GOVERNANCE.md §4).
- [ ] All proposed licence changes, architectural pivots, and trademark decisions are
      **frozen** pending completion of this review.
- [ ] The project's legal counsel reviews any copyright assignments previously made to
      ${ACQUIRED_CO} for implications under ${ACQUIRING_CO} ownership.

---

## 3. Evaluation Criteria for ${ACQUIRING_CO}

The board will assess ${ACQUIRING_CO} against three criteria from Section D.2 of the
case study framework. Each criterion must be scored Low / Medium / High.

### 3.1 Structural Alignment

Does ${ACQUIRING_CO}'s revenue model depend on a genuinely healthy and independent
community, or only on community adoption of ${ACQUIRING_CO}'s specific commercial offering?

**Key questions:**
- [ ] Does ${ACQUIRING_CO} have a history of open-source community investment?
- [ ] Does ${ACQUIRING_CO}'s revenue depend on this project's community health,
      or is the project merely an asset/liability in ${ACQUIRING_CO}'s portfolio?
- [ ] Has ${ACQUIRING_CO} used intellectual property aggressively against the
      open-source community? *(The Oracle/Java lawsuit signal — most critical.)*
- [ ] Does ${ACQUIRING_CO} have commitments to open-source governance elsewhere
      (e.g., Linux Foundation membership, other community stewardships)?

**Assessment:** [ ] LOW  [ ] MEDIUM  [ ] HIGH alignment
**Evidence:** *(Document here)*

---

### 3.2 Governance Transparency Commitment

Is ${ACQUIRING_CO} willing to participate in the project's transparent governance model?

**Key questions:**
- [ ] Has ${ACQUIRING_CO} publicly committed to respecting this project's GOVERNANCE.md?
- [ ] Is ${ACQUIRING_CO} willing to accept the ${CORP_CAP}% board concentration cap?
- [ ] Has ${ACQUIRING_CO} indicated how it will handle the existing board seats held
      by ${ACQUIRED_CO} representatives?
- [ ] Is ${ACQUIRING_CO} willing to undergo a conflict-of-interest audit for current
      board decisions?

**Assessment:** [ ] LOW  [ ] MEDIUM  [ ] HIGH transparency commitment
**Evidence:** *(Document here)*

---

### 3.3 Exit Costs Impact

Has the acquisition changed the practical freedom of contributors to fork?

**Key questions:**
- [ ] Does this project use the DCO model (contributors retain copyright)?
      If YES → exit costs unchanged. If NO → escalate copyright review immediately.
- [ ] Does ${ACQUIRING_CO} hold any registered trademarks related to this project?
- [ ] Are any architectural dependencies being introduced that create platform lock-in?
- [ ] What is the cost to the community of forking at this moment vs. in 12 months?

**Assessment:** [ ] LOW  [ ] MEDIUM  [ ] HIGH exit cost increase
**Evidence:** *(Document here)*

---

## 4. Decision Matrix

Based on the assessment above, the board will reach one of four decisions:

| Score Profile                              | Decision                                         |
|--------------------------------------------|--------------------------------------------------|
| All three criteria: MEDIUM or HIGH         | Full reinstatement — no changes to board seats   |
| Mixed: 2 HIGH, 1 LOW                       | Probationary reinstatement with 6-month review   |
| Structural Alignment: LOW                  | Seat reduction to 1 (below ${CORP_CAP}% threshold)       |
| IP aggression history OR copyright grab    | **Emergency governance meeting — fork evaluation** |

---

## 5. Precedent Reference

This review follows the precedent established by the events of 2010:

| Event                    | OpenOffice.org (Failed)         | This Project (Target)           |
|--------------------------|----------------------------------|---------------------------------|
| Acquisition trigger      | Oracle acquired Sun (Jan 2010)  | ${ACQUIRING_CO} acquired ${ACQUIRED_CO} |
| Governance review        | None conducted                   | This document (60-day process)  |
| Community response       | Reactive fork after damage done  | Proactive structural review     |
| Outcome                  | Community exodus, project decline| TBD — review in progress        |

> *"The community had been living with a loaded pistol they trusted would not be fired.
> Oracle's arrival made that trust impossible to sustain."*
> — The Fork in the Road, Section A.3

The goal of this review is to ensure we never find ourselves in that position.

---

## 6. Timeline

| Date | Milestone |
|------|-----------|
| ${ACQ_DATE} | Acquisition completes — review triggered automatically |
| ${ACQ_DATE} (immediate) | Voting suspension on conflict-of-interest matters |
| +7 days | Board convenes emergency session; assigns review subcommittee |
| +21 days | Subcommittee publishes preliminary findings publicly |
| +30 days | Public comment period opens (RFC repository) |
| +45 days | Public comment period closes |
| ${REVIEW_DEADLINE} | Final board vote on outcome (2/3 supermajority required) |
| +7 days post-vote | Decision published with full rationale |

---

## 7. Signatures

This review was initiated in accordance with GOVERNANCE.md, Section [Acquisition Clause].

| Role                | Name                  | Date     | Signature |
|---------------------|-----------------------|----------|-----------|
| Review Chair        | ${REVIEW_CHAIR}       | ${ACQ_DATE} |           |
| Board Secretary     |                       |          |           |
| Legal Counsel       |                       |          |           |
| Community Rep       |                       |          |           |

---

*${FOUNDATION} | ${PROJECT_NAME}*
*Governance Review triggered: ${ACQ_DATE}*
*Reference: "The Fork in the Road" — Sparsh Kapoor | 24BAI10017 | VIT Bhopal*
MDEOF

echo ""
info "Governance review document generated: ${OUTPUT}"
echo ""
echo -e "${BOLD}Summary:${RESET}"
echo "  Acquisition : ${ACQUIRED_CO} → ${ACQUIRING_CO}"
echo "  Review by   : ${REVIEW_DEADLINE} (60 days)"
echo "  Board seats affected: ${AFFECTED_SEATS} of ${TOTAL_SEATS} ($(( AFFECTED_SEATS * 100 / TOTAL_SEATS ))%)"
echo ""

PCT=$(( AFFECTED_SEATS * 100 / TOTAL_SEATS ))
if [[ $PCT -gt $CORP_CAP ]]; then
    echo -e "${RED}  ⚠ ALERT: ${ACQUIRED_CO} currently holds ${PCT}% of seats, exceeding the${RESET}"
    echo -e "${RED}    ${CORP_CAP}% cap. This must be resolved regardless of review outcome.${RESET}"
elif [[ $PCT -eq $CORP_CAP ]]; then
    echo -e "${YELLOW}  ⚠ ${ACQUIRED_CO} is exactly at the ${CORP_CAP}% cap. Any additional influence${RESET}"
    echo -e "${YELLOW}    from the new parent would breach GOVERNANCE.md.${RESET}"
else
    echo -e "${GREEN}  ✓ Board seat count (${PCT}%) is within the ${CORP_CAP}% cap.${RESET}"
    echo -e "${GREEN}    The review's focus should be on steward character evaluation.${RESET}"
fi

echo ""
echo -e "${CYAN}\"What the acquisition changed was not the structure, but the${RESET}"
echo -e "${CYAN} trustworthiness of the entity that structure empowered.\"${RESET}"
echo -e "${CYAN}— The Fork in the Road, Section A.3${RESET}"
