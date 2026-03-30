#!/usr/bin/env bash
# =============================================================================
# init_oss_project.sh
# Initializes a new open-source project with DCO-based governance structure
# Inspired by: Section D.3 — Governance Recommendations for a New Project
#              (The Fork in the Road — Sparsh Kapoor | 24BAI10017 | VIT Bhopal)
#
# Rationale: OpenOffice.org's copyright assignment to Sun/Oracle was its
# structural flaw. This script sets up a project where contributors RETAIN
# their own copyright (DCO model), with codified governance from day one.
# =============================================================================

set -euo pipefail

# ---------- Colours ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

# ---------- Prompt helpers ----------
ask() {
    local prompt="$1" default="$2" reply
    read -rp "$(echo -e "${BOLD}$prompt${RESET} [$default]: ")" reply
    echo "${reply:-$default}"
}

# ---------- Banner ----------
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ╔══════════════════════════════════════════════════════╗
  ║        OSS Project Initialiser — DCO Edition         ║
  ║   "Genuine openness requires not only a permissive   ║
  ║    licence but a governance structure that            ║
  ║    distributes power."  — The Fork in the Road       ║
  ╚══════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

# ---------- Gather inputs ----------
PROJECT_NAME=$(ask "Project name"        "my-oss-project")
AUTHOR_NAME=$(ask  "Your name"           "Your Name")
AUTHOR_EMAIL=$(ask "Your email"          "you@example.com")
LICENCE=$(ask      "Licence (MIT/Apache-2.0/GPL-3.0/LGPL-2.1)" "Apache-2.0")
ORG_NAME=$(ask     "Foundation / Org name (for GOVERNANCE.md)" "Community Foundation")
CORP_CAP=$(ask     "Max % any single company may hold on board (D.F. uses 33)" "33")

TARGET_DIR="./${PROJECT_NAME}"

[[ -d "$TARGET_DIR" ]] && die "Directory '$TARGET_DIR' already exists."

# ---------- Directory skeleton ----------
info "Creating project skeleton at ${TARGET_DIR}/"
mkdir -p "${TARGET_DIR}"/{src,docs,tests,.github/ISSUE_TEMPLATE}

cd "$TARGET_DIR"

# ---------- Git init ----------
git init -q
success "Git repository initialised."

# ---------- DCO file ----------
info "Writing Developer Certificate of Origin (DCO 1.1)..."
cat > DCO << 'DCOEOF'
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.

NOTE: Contributors retain copyright over their own contributions.
This project does NOT require a Joint Copyright Assignment. Your
code remains yours.
DCOEOF
success "DCO written. Contributors keep their own copyright."

# ---------- GOVERNANCE.md ----------
info "Writing GOVERNANCE.md with corporate concentration caps..."
cat > GOVERNANCE.md << GOVEOF
# Governance Policy — ${PROJECT_NAME}

Maintained by **${ORG_NAME}**

---

## Guiding Principle

This project is governed as a *stewardship*, not an ownership. No single
entity — corporate, governmental, or individual — may control it unilaterally.

*"A steward exercises authority on behalf of others and is accountable to
them; an owner exercises authority on behalf of themselves."*
— The Fork in the Road, Section B.4

---

## 1. Copyright

Contributors **retain copyright** over their own contributions.
This project uses the **Developer Certificate of Origin (DCO) 1.1** model.
There is no Joint Copyright Assignment requirement.

## 2. Board Composition

- The governing board must have a minimum of **5 members**.
- **No single company** may hold more than **${CORP_CAP}%** of board seats.
- If a board member's employer is acquired, a governance review is triggered
  within **60 days** of the acquisition completing.
- Board seats are elected by active contributors (≥1 merged PR in last 12 months).

## 3. Decision-Making

| Decision Type            | Process                                      |
|--------------------------|----------------------------------------------|
| Day-to-day development   | Maintainer approval (lazy consensus)          |
| New maintainer           | Simple majority of current maintainers        |
| Licence change           | **Supermajority (2/3)** of board + 30-day RFC |
| Architectural pivot      | **Supermajority (2/3)** of board + 30-day RFC |
| Acquiring / merging orgs | **Supermajority (2/3)** of board + 60-day RFC |

## 4. Transparency

- All board meetings are recorded; minutes published within **7 days**.
- An RFC (Request for Comments) repository is public.
- Conflicts of interest must be declared; affected members abstain from voting.

## 5. Corporate Steward Evaluation Criteria

When evaluating a corporate sponsor's trustworthiness, the board applies:

1. **Structural alignment** — Does the company's revenue depend on genuine
   community health, or only on community adoption of *its specific offering*?
2. **Governance transparency** — Are major decisions made publicly?
3. **Exit costs** — How hard is it for the community to fork or switch stewards?

## 6. Amending This Document

Amendments require a **supermajority (2/3) board vote** and a **30-day
public comment period**.

---

*${ORG_NAME} | ${PROJECT_NAME}*
GOVEOF
success "GOVERNANCE.md written with ${CORP_CAP}% corporate concentration cap."

# ---------- CONTRIBUTING.md ----------
info "Writing CONTRIBUTING.md..."
cat > CONTRIBUTING.md << CONEOF
# Contributing to ${PROJECT_NAME}

Thank you for contributing! By participating you agree to our
[Code of Conduct](CODE_OF_CONDUCT.md) and the [DCO](DCO).

## How to Sign Off (DCO)

Every commit must include a DCO sign-off:

\`\`\`bash
git commit -s -m "feat: describe your change"
\`\`\`

This adds:
\`\`\`
Signed-off-by: ${AUTHOR_NAME} <${AUTHOR_EMAIL}>
\`\`\`

**You retain copyright over your own contribution.**
We do not require a Joint Copyright Assignment.

## Pull Request Checklist

- [ ] Code follows the project style guide
- [ ] Tests added / updated
- [ ] Docs updated (if applicable)
- [ ] Commit(s) are signed-off with \`-s\`
- [ ] PR description explains *what* and *why*

## Governance

Major changes should be preceded by an RFC. See [GOVERNANCE.md](GOVERNANCE.md).
CONEOF
success "CONTRIBUTING.md written."

# ---------- Minimal README ----------
cat > README.md << READEOF
# ${PROJECT_NAME}

> A community-governed open-source project.

## Licence

${LICENCE} — see [LICENCE](LICENCE)

## Governance

This project uses the **DCO model**: contributors retain their own copyright.
See [GOVERNANCE.md](GOVERNANCE.md) and [DCO](DCO).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
READEOF

# ---------- .gitignore ----------
cat > .gitignore << 'GIEOF'
*.log
*.tmp
__pycache__/
node_modules/
.env
dist/
build/
GIEOF

# ---------- GitHub PR template ----------
cat > .github/pull_request_template.md << 'PREOF'
## Description
<!-- What does this PR do? -->

## Motivation
<!-- Why is this change needed? Link to any issues or RFCs. -->

## Checklist
- [ ] Commits are signed-off (`git commit -s`)
- [ ] Tests pass
- [ ] Docs updated if needed

## DCO Sign-Off
By submitting this PR I certify my contributions comply with the
[Developer Certificate of Origin](../../DCO).
PREOF

# ---------- Initial commit ----------
git add .
git commit -q -s -m "chore: initialise project with DCO governance structure

Sets up:
- DCO 1.1 (contributors retain copyright — no Joint Copyright Assignment)
- GOVERNANCE.md with ${CORP_CAP}% corporate concentration cap
- CONTRIBUTING.md with sign-off instructions
- GitHub PR template

Signed-off-by: ${AUTHOR_NAME} <${AUTHOR_EMAIL}>"

echo ""
success "Project '${PROJECT_NAME}' initialised successfully!"
echo -e "${BOLD}Structure:${RESET}"
find . -not -path './.git/*' | sort | sed 's|^\./||' | sed 's|[^/]*/|  |g'
echo ""
echo -e "${YELLOW}Next steps:${RESET}"
echo "  1. Add your LICENCE file (you chose: ${LICENCE})"
echo "  2. Push to GitHub:  git remote add origin <url> && git push -u origin main"
echo "  3. Enable DCO bot:  https://github.com/apps/dco"
echo "  4. Read GOVERNANCE.md and elect your initial board."
echo ""
echo -e "${CYAN}Remember: Legal openness ≠ Practical openness.${RESET}"
echo -e "${CYAN}Good governance is what makes the difference.${RESET}"
