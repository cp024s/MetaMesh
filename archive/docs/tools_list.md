
| **Stage**                    | **Sub-Steps**                     | **Tools (Open Source)**                               | **Description**                                                          |
| ---------------------------- | --------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------ |
| **1. RTL Design**            | Write RTL (SystemVerilog/Verilog) | VSCode + Verible (lint/format), Surelog/UHDM          | Clean, synthesizable RTL coding. Verible helps style/linting.            |
|                              | Linting & Static Checks           | Verible Linter                                        | Catch bad coding styles & synthesis blockers early.                      |
| **2. RTL Verification**      | Simulation                        | Verilator (cycle-accurate), cocotb (Python testbench) | Functionally verify RTL. cocotb provides reusable testbenches in Python. |
|                              | Testbench Environment             | cocotb / UVM (via PyUVM)                              | Drive random/constrained stimulus, scoreboard, coverage.                 |
|                              | Formal Verification               | SymbiYosys + SMT solvers (Z3, Boolector, Yices)       | Property checking, equivalence, deadlock/livelock detection.             |
| **3. Synthesis**             | Logic Synthesis                   | Yosys                                                 | RTL → Gate-level netlist (mapped to standard cells).                     |
|                              | Constraint Handling               | SDC (Synopsys Design Constraints) with Yosys          | Timing constraints, clocks, I/O delays.                                  |
|                              | Technology Mapping                | Yosys + Liberty (.lib) files from PDK                 | Map gates to target standard-cell library.                               |
| **4. DFT (Design-for-Test)** | Scan Insertion                    | Fault (AUC project)                                   | Insert scan chains into synthesized netlist.                             |
|                              | ATPG                              | Fault                                                 | Generate test patterns for manufacturing test.                           |
| **5. Physical Design (PD)**  | Floorplanning                     | OpenROAD                                              | Define die area, macro placement, I/O pins.                              |
|                              | Placement                         | OpenROAD (global + detailed placement)                | Place standard cells while minimizing congestion.                        |
|                              | Clock Tree Synthesis (CTS)        | OpenROAD                                              | Insert balanced clock tree to meet skew/jitter.                          |
|                              | Routing                           | OpenROAD (global + detailed routing)                  | Connect placed cells using metal layers.                                 |
|                              | Timing Closure                    | OpenSTA (part of OpenROAD)                            | Fix setup/hold violations, optimize buffers.                             |
|                              | Power Analysis                    | OpenROAD + Liberty                                    | Estimate switching and leakage power.                                    |
| **6. Physical Verification** | DRC (Design Rule Check)           | Magic VLSI                                            | Ensure layout obeys foundry rules.                                       |
|                              | LVS (Layout vs Schematic)         | Netgen                                                | Ensure layout matches netlist.                                           |
|                              | ERC (Electrical Rule Check)       | Magic                                                 | Check floating nodes, shorts, leakage.                                   |
| **7. GDSII Export**          | Final Export                      | Magic / KLayout                                       | Write final GDSII file for tapeout.                                      |
|                              | Signoff Checks                    | OpenLane (integrated flow)                            | Wraps DRC/LVS/timing into automated flow.                                |
