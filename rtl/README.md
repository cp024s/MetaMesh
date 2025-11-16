# src

Source design files (Verilog, VHDL, SystemVerilog)


## Working

#### 1. PE array
PE is a small synchronous module that:

- **Consumes** a pair of operands (A from West, B from North) when they are valid and local resources allow.
- **Performs** a multiply (or other op) and accumulates into a running partial-sum (PSUM).
- **Forwards** its A to the East neighbor and B to the South neighbor every cycle (or when valid) that’s the data movement that makes the systolic pipeline.
- Exposes **minimal control** (ready/valid or equivalent) so upstream/downstream can exert back-pressure.