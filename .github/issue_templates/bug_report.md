---
name: Bug report
about: Report a reproducible bug (RTL, simulation, scripts, CI)
title: '[BUG] <short summary>'
labels: bug
assignees: ''
---

## Short description
Provide a concise summary of the problem (one or two sentences).

## Environment
- Repository commit / branch: `main` @ `<commit-hash>`
- Platform: WSL / Ubuntu 20.04 / Docker image `<image:tag>`
- Tools & versions:
  - Verilator: `vX.Y.Z`
  - Yosys: `vX.Y.Z`
  - Python: `3.x`
  - Other tools (OpenLane/OpenROAD/Magic) and versions:

## Severity
Choose one: `critical / high / medium / low`  
(Examples: critical = CI broken; high = blocker for merge; medium = feature incomplete; low = minor doc bug)

## Reproduction steps
Provide a minimal, exact sequence of commands to reproduce the issue. Include file paths, filelists, and any inputs required.

Example:
```bash
# Prepare environment
source ./scripts/utils/env/setup_env.sh

# Run unit test
./scripts/sim/unit/run_unit_tb.sh --test dma_tail_burst \
  2>&1 | tee reports/sim/dma_tail_burst.log
