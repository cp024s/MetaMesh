
# 🔹 1. **RTL Design Dependencies**

These are what your RTL modules need to function:

* **Arithmetic IPs**

  * Fixed-point or floating-point multiplier/divider IPs (FP32, BF16, INT8).
  * Vendor DSP macros (e.g., Xilinx DSP48E2, Synopsys DesignWare multipliers).

* **Memory IPs**

  * SRAM macros (single-port, dual-port, multi-bank).
  * FIFOs (async FIFO for clock domain crossing).
  * Cache controllers (optional).

* **Standard Bus IPs**

  * AXI4 / AXI-Lite interconnect fabric.
  * Arbiter, crossbar, NoC fabric.

* **Clock & Reset**

  * PLL / DLL IP for frequency scaling.
  * Clock gating cells for low power.
  * Reset synchronizers.

* **DFT / BIST**

  * Scan chain insertion.
  * MBIST (Memory BIST for SRAMs).
  * LBIST (optional for logic).

---

# 🔹 2. **Verification Dependencies**

You’ll need infra around the NPU RTL:

* **SystemVerilog/UVM Libraries**

  * Base classes (uvm\_component, uvm\_driver, uvm\_monitor, etc.).
  * UVM Register Model (for programming control/status regs).
  * UVM RAL for memory-mapped registers.

* **BFMs (Bus Functional Models)**

  * AXI4 Master/Slave BFMs (to emulate host CPU and DRAM).
  * APB/AXI-Lite BFMs for register programming.

* **Reference Models (Golden Models)**

  * C/C++/Python based reference of compute engine (matrix mult, activation, pooling).
  * TensorFlow/PyTorch integration for functional checking.

* **Scoreboards & Checkers**

  * Data integrity checkers (input → output match with golden).
  * Coverage collectors (functional + code coverage).

* **Random Stimulus & Constrained Generators**

  * Layer parameters (kernel, stride, padding).
  * Random weights/inputs.

---

# 🔹 3. **Integration Dependencies**

When integrating into a SoC:

* **SoC Wrapper**

  * AXI/TileLink/CHI interface for connecting to main CPU cluster.
  * Interrupt controller (PLIC/GIC).
  * Power domain manager (UPF constraints).

* **Firmware / Drivers**

  * C driver (init, load model, run, poll status).
  * Firmware routines for DMA programming.

* **Boot/Reset Config**

  * Reset sequencing logic.
  * BootROM driver to bring NPU alive.

---

# 🔹 4. **Tool Dependencies**

The design will depend on EDA/FPGA tools:

* **Synthesis Tools**

  * Synopsys Design Compiler, Cadence Genus, Vivado (if FPGA).

* **Place & Route (Backend)**

  * Synopsys ICC2, Cadence Innovus.

* **Simulation**

  * QuestaSim, VCS, Xcelium.

* **Formal Verification**

  * JasperGold, VC Formal.

* **Emulation / FPGA Prototyping**

  * Palladium, Veloce, Zebu.
  * FPGA prototyping boards (Xilinx, Intel).

---

# 🔹 5. **System Dependencies**

Because an NPU doesn’t live alone:

* **External DRAM**

  * DDR4/DDR5/LPDDR4 controllers.
  * PHY IP.

* **System Cache / Coherency**

  * If tightly coupled with CPU, need coherency managers (ACE, CHI).

* **Power/Clock Domains**

  * DVFS infra (voltage regulators).
  * Clock muxes.

---

# 🔹 6. **Software Dependencies**

* **Compiler/Graph Compiler**

  * ONNX, TVM, Glow, TensorRT, or custom.
  * Converts neural network into NPU micro-ops.

* **Driver / Runtime**

  * Linux kernel driver for NPU.
  * User-space library (libnpu).

* **Debug Tools**

  * Perf counters accessible to software.
  * Trace dumps for profiling.

---

# 🔹 7. **Optional Advanced Dependencies**

* **Security**

  * Memory protection units (firewall for NPU DMA).
  * Crypto engines (if doing encrypted model execution).

* **Virtualization**

  * SR-IOV or SMMU (for multiple VMs to share NPU).

