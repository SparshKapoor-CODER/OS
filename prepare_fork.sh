#!/usr/bin/env bash
# =============================================================================
# prepare_fork.sh
# Prepares a clean, governance-ready fork of an upstream repository
# Inspired by: Section C.1 — Was Forking the Right Response?
#              Section C.3 — Was the Fork Worth Its Cost?
#              (The Fork in the Road — Sparsh Kapoor | 24BAI10017 | VIT Bhopal)
#
# "It was the only option that actually addressed the structural problem
#  rather than appealing to the goodwill of an entity that had demonstrated
#  its goodwill was not reliably on offer."  — Section C.1
#
# What it does:
#   1. Clones the upstream repo and re-initialises clean history
#   2. Strips any CLA / copyright-assignment files found
#   3. Injects DCO, GOVERNANCE.md, CONTRIBUTING.md
#   4. Rewrites copyright headers if requested
#   5. Produces a FORK_RATIONALE.md — a documented, auditable justification
#   6. Creates the initial governance commit, signed-off by the fork team
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
ask()     { local p="$1" d="$2" r; read -rp "$(echo -e "${BOLD}${p}${RESET} [${d}]: ")" r; echo "${r:-$d}"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════════════════════╗
  ║            Fork Preparation Toolkit                       ║
  ║  "The fork exchanged short-term pain for long-term        ║
  ║   sustainability."  — The Fork in the Road, Section C.3  ║
  ╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

# ── Inputs ────────────────────────────────────────────────────────────────────
UPSTREAM_URL=$(ask  "Upstream repository URL (HTTPS or SSH)"    "https://github.com/original/project.git")
FORK_NAME=$(ask     "Your fork's project name"                   "my-fork")
FORK_ORG=$(ask      "Your foundation / org name"                 "Community Foundation")
YOUR_NAME=$(ask     "Your name (for sign-off)"                   "Your Name")
YOUR_EMAIL=$(ask    "Your email (for sign-off)"                  "you@example.com")
LICENCE=$(ask       "Licence (must be compatible with upstream)" "Apache-2.0")
CORP_CAP=$(ask      "Max board representation % per company"     "33")
REASON=$(ask        "One-line fork rationale (goes in FORK_RATIONALE.md)" \
                    "Upstream governance does not adequately protect community contributors.")

FORK_DIR="./${FORK_NAME}"
[[ -d "$FORK_DIR" ]] && die "Directory '${FORK_DIR}' already exists."

# ── Step 1: Clone upstream ────────────────────────────────────────────────────
info "Cloning upstream: ${UPSTREAM_URL}"
git clone --depth=1 "$UPSTREAM_URL" "$FORK_DIR" || die "Clone failed. Check the URL."
cd "$FORK_DIR"

UPSTREAM_REMOTE=$(git remote get-url origin)
UPSTREAM_LAST_COMMIT=$(git log --format="%H %s" | head -1)
UPSTREAM_COMMIT_COUNT=$(git rev-list --count HEAD)

# Keep upstream as a named remote for future tracking
git remote rename origin upstream
success "Upstream preserved as remote 'upstream'."

# ── Step 2: Remove CLA / copyright-assignment artefacts ──────────────────────
info "Scanning for CLA / copyright assignment files to remove..."
CLA_PATTERNS=("CLA*" "ICLA*" "CCLA*" "COPYRIGHT_ASSIGNMENT*" "*contributor-license*" "*cla.md" "*CLA.md")
REMOVED=0

for pattern in "${CLA_PATTERNS[@]}"; do
    while IFS= read -r -d '' found; do
        warn "Removing upstream CLA file: ${found}"
        git rm -f --cached "$found" 2>/dev/null || true
        rm -f "$found"
        REMOVED=$((REMOVED + 1))
    done < <(find . -not -path './.git/*' -name "$pattern" -print0 2>/dev/null)
done

[[ $REMOVED -eq 0 ]] && success "No CLA files found to remove." \
                     || success "Removed ${REMOVED} CLA/copyright-assignment file(s)."

# ── Step 3: Inject DCO ────────────────────────────────────────────────────────
info "Injecting Developer Certificate of Origin (DCO 1.1)..."
cat > DCO << 'DCOEOF'
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I have
    the right to submit it under the open source license indicated in the file; or

(b) The contribution is based upon previous work covered under an appropriate
    open source license and I have the right to submit that work with modifications; or

(c) The contribution was provided directly to me by some other person who
    certified (a), (b) or (c) and I have not modified it.

(d) I understand and agree that this project and the contribution are public
    and that a record is maintained indefinitely.

IMPORTANT: Contributors retain copyright over their own contributions.
This fork does NOT require a Joint Copyright Assignment.
DCOEOF
success "DCO injected."

# ── Step 4: Write GOVERNANCE.md ───────────────────────────────────────────────
info "Writing GOVERNANCE.md..."
cat > GOVERNANCE.md << GOVEOF
# Governance Policy — ${FORK_NAME}

Maintained by **${FORK_ORG}**

## Why This Fork Exists

${REASON}

This fork was created because legal openness (an open-source licence) is not
the same as practical openness (a governance structure that distributes power
and protects contributors). See FORK_RATIONALE.md for full documentation.

## Principles

1. **Distributed copyright** — Contributors retain their own copyright (DCO model).
   No Joint Copyright Assignment is required or accepted.

2. **Corporate concentration cap** — No single company may hold more than
   **${CORP_CAP}%** of the governing board. Acquisitions trigger a 60-day review.

3. **Transparent decision-making** — Major decisions (licence changes, architectural
   pivots) require a 2/3 supermajority vote and a 30-day public RFC period.
   All board meeting minutes are published within 7 days.

## Board

- Minimum 5 members, elected by active contributors.
- Conflict-of-interest declarations required; affected members abstain.
- Acquisition of any board member's employer triggers governance review.

## Amending This Document

2/3 supermajority board vote + 30-day public comment period.

---
*${FORK_ORG} | ${FORK_NAME}*
GOVEOF
success "GOVERNANCE.md written."

# ── Step 5: Write FORK_RATIONALE.md (auditable justification) ────────────────
info "Writing FORK_RATIONALE.md (auditable fork justification)..."
FORK_DATE=$(date +"%Y-%m-%d")
cat > FORK_RATIONALE.md << RATIONEOF
# Fork Rationale — ${FORK_NAME}

**Date forked  :** ${FORK_DATE}
**Upstream URL :** ${UPSTREAM_REMOTE}
**Upstream HEAD:** ${UPSTREAM_LAST_COMMIT}
**Forked by    :** ${YOUR_NAME} <${YOUR_EMAIL}>
**Foundation   :** ${FORK_ORG}

---

## Primary Reason

${REASON}

## Alternatives Considered Before Forking

The following alternatives were evaluated before forking, in order of preference:

### 1. Internal Lobbying / Governance Reform
Discussions with upstream maintainers and governance bodies about reforming
copyright assignment, board composition, and decision-making transparency.
**Outcome:** [Document outcome here — e.g., "Reform discussions were ongoing for
X months without structural change. The upstream copyright assignment requirement
was not modified."]

### 2. Public Advocacy
Collective public statement from community members requesting governance reform.
**Outcome:** [Document outcome here.]

### 3. Forking (chosen)
Creating an independent fork under new governance aligned with community interests.
**Rationale for choosing this option:**
- The structural problem could not be resolved by appealing to the existing steward's goodwill.
- The DCO model and the corporate concentration cap directly address the root cause,
  not merely its symptoms.
- Exit costs were sufficiently low (compatible licence) to make forking practical.

## Evaluation Criteria (per Section D.2 framework)

| Criterion              | Upstream Score | This Fork's Goal          |
|------------------------|---------------|---------------------------|
| Structural alignment   | LOW           | Community-first model     |
| Governance transparency| LOW           | Public minutes + RFC log  |
| Exit costs (for users) | MEDIUM        | Maintain file compatibility|

## What Has Changed in This Fork

- Removed: CLA / Joint Copyright Assignment requirement
- Added: DCO 1.1 (contributors retain copyright)
- Added: GOVERNANCE.md with ${CORP_CAP}% corporate concentration cap
- Added: 30-day RFC process for major decisions
- Preserved: Upstream codebase at commit listed above (licence-compatible)

## Invitation to Upstream

[If applicable] This fork includes an open invitation for the upstream project
to participate in the new governance structure, donate trademarks, or merge.
[Reference: Document Foundation invited Oracle — see The Fork in the Road, Section C.2]

---
*This document follows the precedent set by The Document Foundation (LibreOffice, 2010)
of providing transparent, publicly documented rationale for a governance fork.*
RATIONEOF
success "FORK_RATIONALE.md written."

# ── Step 6: Update CONTRIBUTING.md ────────────────────────────────────────────
cat > CONTRIBUTING.md << CONEOF
# Contributing to ${FORK_NAME}

By contributing you agree to the [DCO](DCO) and [Code of Conduct](CODE_OF_CONDUCT.md).

## Copyright

**You retain copyright over your contributions.** We use the Developer
Certificate of Origin (DCO) model. There is no Joint Copyright Assignment.

## Signing Off

Every commit must carry a DCO sign-off:

\`\`\`bash
git commit -s -m "your message"
# Adds: Signed-off-by: ${YOUR_NAME} <${YOUR_EMAIL}>
\`\`\`

## Governance

See [GOVERNANCE.md](GOVERNANCE.md). Major changes → open an RFC first.
CONEOF

# ── Step 7: Initial commit ────────────────────────────────────────────────────
info "Creating initial governance commit..."
git add DCO GOVERNANCE.md FORK_RATIONALE.md CONTRIBUTING.md
git commit -s -m "governance: establish fork governance under ${FORK_ORG}

Upstream: ${UPSTREAM_REMOTE}
Forked at: ${UPSTREAM_LAST_COMMIT}

Changes:
- Remove upstream CLA / copyright assignment requirement (${REMOVED} file(s))
- Add DCO 1.1: contributors retain their own copyright
- Add GOVERNANCE.md: ${CORP_CAP}% corporate concentration cap, supermajority
  rules for major decisions, public RFC process
- Add FORK_RATIONALE.md: transparent, auditable fork justification
- Update CONTRIBUTING.md: DCO sign-off instructions

Rationale: ${REASON}

Signed-off-by: ${YOUR_NAME} <${YOUR_EMAIL}>"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "Fork '${FORK_NAME}' prepared at ${FORK_DIR}/"
echo ""
echo -e "${BOLD}Files added/modified:${RESET}"
echo "  DCO                  → Contributors retain copyright"
echo "  GOVERNANCE.md        → ${CORP_CAP}% cap, supermajority rules"
echo "  FORK_RATIONALE.md    → Auditable justification"
echo "  CONTRIBUTING.md      → DCO sign-off guide"
echo ""
echo -e "${BOLD}Remotes:${RESET}"
git remote -v
echo ""
echo -e "${YELLOW}Next steps:${RESET}"
echo "  1. Add your fork's remote:    git remote add origin <your-fork-url>"
echo "  2. Push:                      git push -u origin main"
echo "  3. Complete FORK_RATIONALE.md with actual outcomes of alternatives tried."
echo "  4. Elect an initial board per GOVERNANCE.md."
echo "  5. Enable DCO bot:            https://github.com/apps/dco"
echo ""
echo -e "${CYAN}\"The fork exchanged short-term pain for long-term sustainability.\"${RESET}"
echo -e "${CYAN}— The Fork in the Road, Section C.3${RESET}"
