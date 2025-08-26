# Contributing Guidelines

Thanks for contributing to this NPU project.
This document defines conventions, workflows, tooling, and acceptance criteria we use to keep quality high and the project maintainable. It is intended for RTL designers, verification engineers, PD/script authors, and documentation contributors.

> **Scope & intent.** The repository implements an RTL-first Neural Processing Unit (dual-engine: systolic + MAC) and a full verification, synthesis, and PD automation flow. Contributions should preserve reproducibility, be verifiable by automated CI, and follow the project’s coding, verification, and documentation standards.

---

## Table of contents

* [Quickstart: how to contribute](#quickstart-how-to-contribute)
* [Roles & maintainers](#roles--maintainers)
* [Repository layout (how we map contributions)](#repository-layout-how-we-map-contributions)
* [Branching, commits, and PR workflow](#branching-commits-and-pr-workflow)
* [Code & style guidelines (detailed)](#code--style-guidelines-detailed)
* [RTL: module template & headers](#rtl-module-template--headers)
* [Verification requirements (DV, formal, coverage)](#verification-requirements-dv-formal-coverage)
* [How to run common checks locally (commands)](#how-to-run-common-checks-locally-commands)
* [CI expectations & required checks](#ci-expectations--required-checks)
* [Synthesis / PD / scripts contributions (guidance)](#synthesis--pd--scripts-contributions-guidance)
* [Issue & PR templates (copy/paste)](#issue--pr-templates-copypaste)
* [Legal / licensing / sign-off](#legal--licensing--sign-off)
* [Review, acceptance & release process](#review-acceptance--release-process)
* [Contacts & escalation](#contacts--escalation)
* [Appendix: examples and checklists](#appendix-examples-and-checklists)

---

## Quickstart: how to contribute

1. Fork the repo and clone your fork.
2. Create a branch: `feature/<module>` or `bugfix/<issue-id>`.
3. Implement changes under the appropriate directory (see layout below).
4. Add/extend tests in `/tb` and `/dv` (unit + regression).
5. Run local checks (lint, sim, coverage) described below.
6. Push branch and open a Pull Request (PR) against `main`. Include test logs and a concise description.
7. Address review comments and obtain required approvals. Merge only when CI passes and reviewers sign off.

---

## Roles & maintainers

* **Maintainers**: people with merge rights. PRs should be reviewed/approved by at least one maintainer. (Add names/emails here when available.)
* **Module owners**: designated reviewers for subsystems (RTL, DV, PD, scripts). Use the PR reviewers field.
* **Contributors**: everyone who opens issues, PRs, docs, or testcases. You must follow this guide.

If you want to become a maintainer, open an issue describing your contributions and experience; maintainers will discuss and vote.

---

## Repository layout (how we map contributions)

Use the existing structure to place code and tests:

```
/archive   – historical artifacts, non-active results
/docs      – design docs, block diagrams, spec, README sections
/dv        – verification environment, UVM drivers/agents, config
/reports   – generated reports (synth/PnR/STA) - generated files only
/scripts   – automation (lint/sim/synth/pnr/sta/drc)
 /scripts/sim  /scripts/pnr  /scripts/synth  etc.
 /scripts/utils helpers and wrappers
/sim       – simulation harnesses, filelists, golden models
/src       – RTL (SystemVerilog) — main design
/tb        – testbenches and stimulus (SystemVerilog/cocotb)
```

**Do not** commit large binaries or generated artifacts to `/src`, `/tb`, or `/dv`. Use `/reports` or `/archive` only for final, small-signoff artifacts. Add new helpers under `/scripts/*`.

---

## Branching, commits, and PR workflow

### Branch naming

* Feature: `feature/<short-desc>` (e.g., `feature/systolic-pe-opt`)
* Bugfix: `bugfix/<issue#>-<short-desc>` (e.g., `bugfix/123-axi-read-timeout`)
* Docs: `doc/<topic>` (e.g., `doc/tiling_spec`)

### Commit message convention

Every commit must have a clear subject and optionally a body. Use the following format:

```
[Module]: Short, imperative summary

Optional longer description. Explain rationale, testing performed, and references
to issues/PR IDs. Include "Signed-off-by: Name <email>" if using DCO (recommended).
```

Example:

```
[DMA]: Fix burst length calculation for non-aligned transfers

Fixes issue where AXI burst length was computed incorrectly for tail fragments.
Added unit test (dv/dma/tail_burst.sv) and waveform. All sim/regression pass.
Signed-off-by: CP <you@example.com>
```

### Pull requests

* Open PR against `main`.
* PR title: same as the commit subject.
* PR body must include:

  * What changed, why, and how.
  * Test-plan (which tests run, where logs are).
  * Any risk or backward-incompatible behavior.
* Tag relevant module owners as reviewers.
* Keep PRs focused (one logical change per PR). Large refactors: open a design RFC issue first.

---

## Code & style guidelines (detailed)

### General

* Platform: WSL / Linux. Scripts must be POSIX-compatible where possible.
* Use `Verible` for SystemVerilog formatting/linting. Add an editorconfig or `.verible` config.
* Python: follow `black` formatting and `flake8`.
* Shell: `shellcheck` clean scripts.

### SystemVerilog / RTL rules

* Standard: SystemVerilog-2009 compatible, synthesizable subset.
* No usage of simulation-only constructs in `src/` (no `#(delay)`, no `$display` left in design).
* Prefer parametrized modules and `localparam` over hard-coded widths.
* Avoid hard-coded magic numbers; expose them as parameters in a central `params` header when relevant.

**Naming conventions**

* Module names: `UpperCamelCase` (e.g., `SystolicArrayEngine`)
* Files: `lowercase_with_underscores.sv` (e.g., `systolic_array_engine.sv`)
* Ports & signals: `snake_case` (e.g., `clk`, `rst_n`, `data_valid`)
* Parameters: `kUpperCamelCase` or `PARAM_UPPER` (pick one and be consistent)

**Example module header**

```systemverilog
// -----------------------------------------------------------------------------
// Module : SystolicArrayEngine
// File   : src/systolic_array_engine.sv
// Author : CP
// Date   : 2025-08-xx
//
// Description:
//   Parameterizable R x C systolic array wrapper. Controls ingress/egress and
//   provides local scheduler for tile fill/run/drain modes.
//
// Params:
//   int R = 16;   // rows
//   int C = 16;   // cols
//
// I/O:
//   input  logic clk, rst_n
//   // activation/weight input interfaces, psum out, control/status
//
// Notes:
//   - Synthesizable subset only.
// -----------------------------------------------------------------------------
module SystolicArrayEngine #(
  parameter int R = 16,
  parameter int C = 16
) (...);
```

### Testbench & DV conventions

* Use self-checking testbenches whenever possible. Include reference model comparisons (Python/NumPy).
* Use `tb` directory for heavyweight testbenches and `dv` for verification framework (UVM components).
* Include a minimal, fast smoke test under `/sim` for quick local sanity checks.
* Add SVA assertions in `tb` or in a separate `assertions.sv` included for simulation.

---

## RTL: module template & headers

When adding a new RTL file:

1. Add file under `/src/<module_name>/` or `/src/` if top-level.
2. Include module header comment (see example above).
3. Add a small README in the module folder describing parameters, expected area/timing, and test vectors.
4. Provide a unit test under `/tb/<module_name>/` and an entry in `/sim/filelist_unit.f`.

---

## Verification requirements (DV, formal, coverage)

Every RTL contribution must be accompanied by verification that covers the functional scope of the change.

### Unit tests

* Each module must have at least one unit test that exercises normal and boundary cases.
* Unit tests should be runnable by a single command (sample below).

### Regression & coverage

* PRs that modify behavior must add or update regression tests in `/dv/regression/`.
* Target baseline coverage: **project target = 80% statement/functional coverage** (adjustable). New modules should aim to achieve > 80% in unit scope. If coverage target cannot be met, discuss with maintainers and include a follow-up ticket.

### Formal checks

* For control/state-heavy modules (scheduler, arbiter, DMA FSM), provide formal properties in `/dv/properties/` and run SymbiYosys proofs for liveness/safety where applicable.
* Equivalence checks: for synthesized netlist changes, run RTL vs netlist equivalence (scripts provided under `/scripts/formal/`).

### Artifacts to include in PR

* Simulation log excerpts and waveforms (e.g., compressed VCD/GTKWave or PNG snapshots).
* Coverage report (HTML or CSV) for the affected modules.
* Formal proof summary or counterexample (if properties added).

---

## How to run common checks locally (commands)

Below are example commands; adapt to your local paths. All scripts live under `/scripts`.

### Lint & format

```bash
# Verible lint (SystemVerilog)
./scripts/design/lint/run_lint.sh

# Python format check
black --check .

# Shellcheck for scripts
shellcheck scripts/**/*.sh
```

### Unit simulation (Verilator + cocotb example)

```bash
# run unit tests (wrapper)
./scripts/sim/unit/run_unit_tb.sh  # expects filelist at sim/filelist_unit.f
# run a named test
./scripts/sim/unit/run_unit_tb.sh --test dma_tail_burst
```

### Regression

```bash
./scripts/sim/regression/run_regression.py --config dv/regression_list.txt
```

### Formal

```bash
./scripts/formal/run_proofs.sh --prop dv/properties/scheduler.sva
```

### Synthesis (Yosys)

```bash
./scripts/synth/yosys/synth.sh --top NPU_TOP --lib path/to/liberty
```

### Full local flow (sanity)

```bash
./scripts/utils/wrap_run_all.sh  # runs lint -> unit sim -> regression smoke
```

Include a short README in `/scripts` to point to these wrappers and validate required tools and paths.

---

## CI expectations & required checks

Every PR must pass CI. CI jobs include:

1. **Lint** (Verible for SV, black/flake8 for Python, shellcheck)
2. **Unit simulation** (fast smoke tests; run in Verilator)
3. **Regression** (longer; gated for merge or run nightly)
4. **Formal smoke** (quick properties)
5. **Synthesis smoke** (Yosys: check that top-level is synthesizable)
6. **Static checks** (no trailing whitespace, no large files > 5MB)

The repository contains a CI configuration under `/scripts/ci_cd/` — keep it up-to-date with any new check addition. PR merge is blocked until all **required** checks pass.

---

## Synthesis / PD / scripts contributions (guidance)

Contributions to automation, synthesis, or PD scripts must:

* Be parameterized (no hard-coded paths).
* Provide usage docstring and `--help`.
* Include a small smoke-run example and expected output in `/reports/` or `/archive/`.
* Respect reproducibility: scripts should be idempotent (clean run produces same outputs) and log in `/reports/<timestamp>/`.

If you add a new PD script or change flow, update `/scripts/ci_cd/` to include a smoke test.

---

## DFT / Testability contributions

* Scan insertion must use the project DFT flow (see `/scripts/dft/`).
* ATPG patterns and coverage must be generated and included in `/reports/dft/` for review.
* DFT changes require sign-off from maintainers and a check that regression remains green.

---

## Issue & PR templates (copy/paste)

### Issue template

```
### Short description
(What happened / What you want)

### Environment
- Branch / commit:
- Tool versions (Verilator/Yosys):

### Steps to reproduce
1. ...
2. ...

### Expected behavior
(What should happen)

### Actual behavior
(What happened)

### Attachments
- Logs, waveforms, filelist, minimal reproducer
```

### PR template

```
### Summary
(One-line summary of change)

### What & Why
- Detailed description of change and rationale.

### Tests
- Unit tests added / updated: list files
- Regression(s) run: list names
- Coverage: before/after percentages (if relevant)

### Checklist
- [ ] Lint passed
- [ ] Unit tests passed locally
- [ ] Regression/coverage updated
- [ ] Documentation updated (if applicable)

### Notes for reviewers
(Special areas to look at, expected reviewer time)
```

Place these under `.github/ISSUE_TEMPLATE.md` and `.github/PULL_REQUEST_TEMPLATE.md` or paste them into the PR/Issue body.

---

## Legal / licensing / sign-off

* All contributions are accepted under the repository `LICENSE`. By contributing you agree to license your contributions accordingly.
* We require a developer sign-off per commit: append a `Signed-off-by: Name <email>` line to commits (DCO). You may automate this with `git commit -s`. Maintainers will reject unsigned commits or request sign-off.

---

## Review, acceptance & release process

* PR review: one required maintainer approval for small changes; two for core RTL or PD changes.
* CI green is mandatory.
* For major design changes (new engine, banking model revision), open an RFC issue first to discuss architecture and gain buy-in.
* Releases (tags) are made by maintainers. Release notes must include synthesis/PNR signoff artifacts and a summary of regressions.

---

## Contacts & escalation

* Primary maintainer(s): add names/emails here.
* For urgent issues (broken regression, CI failure), open a high-priority issue with `[CRITICAL]` in title and ping maintainers.

---
