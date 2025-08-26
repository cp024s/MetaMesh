# <p align = center> Pull Request Template </p>

## Summary
Briefly summarize the purpose of this pull request (one or two lines).
Example: `Add 16x16 Systolic PE array and corresponding unit tests.`

---

## What & Why
- **What**: Describe the changes introduced by this PR (features, fixes, refactors).
- **Why**: Explain the motivation and rationale. Why is this change necessary?
- Link related issue(s): `Fixes #<issue_number>` (if applicable).

---

## Scope of Changes
List the main files/directories changed and a short sentence about each:
- `src/...` — RTL added/modified (describe intent).
- `tb/...` — Testbench/tests added or updated.
- `dv/...` — Verification scenarios or config updated.
- `scripts/...` — Automation or flow scripts added/modified.
- `docs/...` — Documentation updates.

If the PR is large, break changes into logical sections to help reviewers.

---

## Verification & Tests
Describe how this change was validated and what tests were run.

- **Unit tests**:
  - Test name(s): `tb/<module>/...`
  - Command to run: `./scripts/sim/unit/run_unit_tb.sh --test <testname>`
- **Regression**:
  - Tests executed: `dv/regression/<list>`
  - Command to run: `./scripts/sim/regression/run_regression.py --list dv/regression_list.txt`
- **Formal** (if applicable):
  - Properties checked: `dv/properties/...`
  - Command: `./scripts/formal/run_proofs.sh --prop dv/properties/<prop>.sva`
- **Synthesis smoke** (if applicable):
  - Command: `./scripts/synth/yosys/synth.sh --top NPU_TOP`

Attach or link to simulation logs, waveform snapshots, coverage reports, and formal proof logs as applicable.

---

## Checklist (required)
- [ ] Branch is based on the latest `main`
- [ ] Commits follow commit message convention (`[Module]: Short description`)
- [ ] Code passes linting (Verible / shellcheck / black)
- [ ] Unit tests pass locally
- [ ] Regression tests (or smoke tests) pass where applicable
- [ ] Documentation updated (if behavior/interface changed)
- [ ] No large binaries committed ( > 5MB )

---

## Backwards Compatibility & Risks
- Does this change alter on-disk formats, wire-level interfaces, or public APIs? If yes, document versioning/migration steps.
- List potential risks or areas that require careful review (timing-critical paths, DMA/AXI interactions, power domains, etc.).

---

## Notes for Reviewers
- Areas requiring special attention:
  - e.g., "Check PE accumulation rounding/overflow handling"
  - e.g., "Verify AGU address wrap behavior for odd tile sizes"
- Recommended reviewers (module owners or experts).

---

## Deployment / Merge Notes
- Any required follow-up tasks (e.g., update CI, add regression cases, update PD scripts).
- If this PR requires a release note, provide a one-line entry for the changelog.

---

## Attachments
- Link to logs / waveforms / coverage (or attach in PR):
  - `reports/sim/<pr-id>/...`
  - `reports/coverage/<pr-id>/...`

---

## Signed-off-by
`Signed-off-by: Your Name <your.email@example.com>`
