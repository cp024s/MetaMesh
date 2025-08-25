# <p align = center> MODULE WISE JOBS </p>

# **NPU\_TOP**

* **Responsibilities:**

  * Top-level wrapper coordinating all sub-modules.
  * Handles system-level clock, reset, and interconnects between compute engines, memory, host interface, and debug.
  * Aggregates global configuration and status for host access.
* **Interactions:** Connects **Compute\_Engine**, **Memory\_Subsystem**, **Control\_Unit**, **Interfaces**, and **Debug\_Unit**.

---

## **Host\_Interface**

* **AXI/APB\_Slave**

  * Provides CPU access to NPU configuration, status, and control registers.
  * Supports read/write transactions with optional handshaking and address decoding.
* **Interrupt\_Controller**

  * Monitors error flags, job completion, or performance thresholds.
  * Signals interrupts to CPU with priority and masking options.
* **Job\_Queue**

  * Buffers jobs/operations submitted by the CPU.
  * Provides first-in-first-out (FIFO) access to Control\_Unit for scheduling.

---

## **Compute\_Engine**

### **Systolic\_Array\_Engine**

* **Systolic\_Array\_Controller**

  * Manages tile-level execution, including fill/run/drain of data wavefronts.
  * Implements a local FSM to sequence operations efficiently.
* **Systolic\_PE\_Array**

  * 2D grid of PEs performing multiply-accumulate.
  * Each PE passes data to neighbors, reducing external memory accesses.
  * Supports partial sum storage locally.
* **Input\_Stream\_Buffer**

  * Aligns activations and weights to the systolic array wavefront.
  * Provides double-buffering to hide DMA latency.
* **Output\_Collector**

  * Aggregates outputs from PE array edges and writes to PSUM buffer.
  * Supports reduction if needed.
* **Dataflow\_Scheduler**

  * Controls tile scheduling, load balancing, and pipeline timing.
  * Tracks wavefront progression and avoids hazards.

### **MAC\_Array\_Engine**

* **MAC\_Array\_Controller**

  * Issues instructions to MAC PEs and schedules tiles.
  * Supports flexible operations (GEMM, dot-products, small convolutions).
* **MAC\_PE\_Array**

  * SIMD-style PEs performing multiply-accumulate.
  * Local register file per PE for accumulation.
  * Supports small vector ops and elementwise operations.
* **Input\_Distributor**

  * Broadcasts activations/weights to MAC PEs according to tile mapping.
  * Handles alignment and padding if needed.
* **Output\_Accumulator**

  * Collects partial sums and writes to PSUM buffers.
  * Can perform local reductions before writing out.
* **Dataflow\_Controller**

  * Manages instruction issue and ensures data availability per PE.
  * Handles tiling, masking, and alignment.

### **Vector\_Units**

* Performs **elementwise operations** across vectors/tensors.
* Includes **adder, multiplier, normalization/reduction units**.
* Handles residual additions, bias, and other per-element ops.

### **Activation\_Unit**

* Implements all activations: **ReLU, Sigmoid, Tanh, Softmax, GELU, Swish**.
* Uses **LUTs, CORDIC, or iterative approximation** depending on precision.
* Shared across engines for post-processing outputs.

### **Pooling\_Unit**

* Computes **Max, Average, or Global Pooling**.
* Supports different window sizes and strides.
* Works on outputs from both engines.

### **Quantization\_Unit**

* Handles **FP16 ↔ INT8 conversions**, scaling, clipping, and rounding.
* Supports **per-tensor and per-channel quantization**.
* Used during post-processing or inference.

---

## **Memory\_Subsystem**

* **Weight\_Buffer**: SRAM banks storing weights locally; minimizes DRAM access.
* **Activation\_Buffer**: SRAM for input/output activations, double-buffered for latency hiding.
* **PSUM\_Buffer**: Stores partial sums from engines before post-processing.
* **AGU\_Cluster**:

  * **AGU\_Systolic**: Generates addresses in **wavefront order** for systolic engine.
  * **AGU\_SIMD**: Generates **row/col/stride/gather/scatter addresses** for MAC engine.
* **DMA\_Engine**:

  * Manages AXI transactions to DRAM.
  * Supports multiple outstanding read/write bursts.
* **Prefetch\_Writeback**:

  * Prefetches tiles to buffers in advance.
  * Coalesces writebacks to reduce bus contention.

---

## **Control\_Unit**

* **Instruction\_Decoder**: Parses jobs into engine instructions.
* **Scheduler**:

  * **Engine\_Selector**: Maps each operation to MAC or Systolic engine.
  * **Job\_Dispatcher**: Sends tiles/jobs to engines while respecting dependencies.
  * **Dependency\_Checker**: Ensures proper sequencing of operations.
* **Error\_Handler**: Monitors ECC faults, illegal instructions, or execution errors.

---

## **Interfaces**

* **AXI\_Master\_IF**: High-bandwidth interface to DRAM.
* **AXI-Lite/APB\_IF**: CPU control and status monitoring.
* **Cache\_Coherency\_IF (optional)**: Maintains memory coherence for multi-agent systems.

---

## **Debug\_Unit**

* **Performance\_Counters**: Tracks engine utilization, stalls, memory BW, and throughput.
* **Trace\_Buffers**: Captures execution traces for post-mortem debugging.
* **JTAG/Scan\_Chain**: Provides RTL scan testing and optional MBIST access for memories.

---
