## Tools and tech stack used in thi project:

### RTL design and simulatin 
  1. Verilator → Fast simulation & linting (good for synthesizable code).
  2. Icarus Verilog → More complete Verilog support (slower but useful).
  3. GTKWave → For waveform visualization.

### RTL Linting
  1. Yosys+SymbiYosys (SBY) → Formal verification, property checking.

### RTL Synthesis
1. Yosys
  - Maps RTL to generic gates or a standard-cell library (like SkyWater130 PDK).
  - Supports SystemVerilog (with Surelog/UHDM plugin).
  - Outputs gate-level netlist in Verilog.
