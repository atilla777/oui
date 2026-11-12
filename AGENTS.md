# oui maintainer safety

Experimental Odin UI kit, not a game. MIS is maintainer-only tooling.
Ordinary consumers need only selected packages/resources/native dependencies.
Agent graphics must use scripts/ui_isd.py with an explicitly selected, fully
verified ISD copy. Require linux-abstract-v1 before create and in create/status;
protocol1 alone is insufficient. Own run/input/PNG, explicit focus, and stop in
finally, retaining screenshots/logs. No main-desktop fallback. UI algorithms
remain in kit/consumer owners, never a second implementation in tooling.

## Maintainer workflow

MIS is installed in `.opencode/`; its exact source revision is recorded in
`.opencode/mis-installation`. Use `/mis-install` to check setup, `/mis-status`
for read-only task status, `/mis-plan` for authorized planning and `/mis-run <ID>`
for one verified Beads Task/Bug. Planning never authorizes implementation.
Beads uses the canonical oui `.beads/` embedded database, prefix `oui`, with
Dolt remote in the same oui Git repository. Never use a neighbouring tracker.
GitHub issue numbers are not Beads IDs. Preserve existing Issues, dependencies
and `docs/specs/1/` in the documentation branch/PR; do not import or duplicate
them without an explicit migration decision.

Existing library contracts start at `docs/README.md`; do not rewrite them or
invent product/test policy to satisfy MIS layout checks. Installation alone
does not establish plan/run readiness. Native consumers do not require MIS.
Local setup commits are authorized for this installation only; Git and Dolt
publication require separate authority. Do not infer standing push permission.
