# <p align=center> 2. Architecture Overview </p>

The NPU is designed as a **modular, hierarchical accelerator** for deep learning workloads, emphasizing **hardware-level parallelism, data reuse, and scalable computation**. Its architecture is organized into **compute engines, memory subsystem, control unit, interfaces, and debug support**, each responsible for a specific aspect of the dataflow and execution.

### 1. Dual Compute Engines

At the heart of the NPU is the **Compute Engine**, which features two parallel accelerator types:

* **Systolic Array Engine**
  Optimized for dense GEMM and convolution operations, the systolic array consists of a 2D grid of **Processing Elements (PEs)** arranged for **wavefront data propagation**. Each PE performs multiply-accumulate operations and passes intermediate results to neighboring PEs, minimizing external memory accesses. Local buffering allows tiles of activations and weights to be stored and reused efficiently.

* **MAC Array Engine**
  A flexible SIMD-style array designed for smaller GEMM operations, elementwise computation, and irregular workloads. Each PE supports local accumulation and can handle vectorized operations. Input distribution and output accumulation logic maintain high throughput even with non-contiguous data.

Both engines share **vector and post-processing units** for elementwise operations, activations, pooling, and quantization, enabling flexible usage depending on workload type.

### 2. Memory Subsystem

Efficient memory access is critical for high throughput. The memory subsystem consists of:

* **Weight, Activation, and Partial Sum Buffers**: On-chip SRAM storing tiles to reduce DRAM bandwidth pressure.
* **Address Generation Units (AGUs)**: Generate addresses for tile-aligned, strided, or wavefront access patterns suitable for each compute engine.
* **DMA Engine**: Handles high-throughput data transfer between off-chip memory and local buffers. Supports prefetching and writeback to overlap computation with memory accesses.

This subsystem ensures that compute engines remain fully utilized without stalling on memory operations.

### 3. Control Unit

The Control Unit orchestrates the entire NPU operation:

* **Instruction Decoder**: Interprets operation descriptors received from the host.
* **Scheduler**: Determines which compute engine (Systolic or MAC) executes each job, and schedules tasks to maximize utilization.
* **Dependency Checker**: Ensures correct sequencing of operations and resolves data hazards.
* **Error Handler**: Monitors exceptions, ECC faults, and invalid instructions.

The Control Unit acts as the central brain, coordinating compute, memory, and post-processing pipelines.

### 4. Interfaces

The NPU connects to external systems via standardized interfaces:

* **AXI Master Interface**: High-bandwidth access to DRAM for bulk data movement.
* **AXI-Lite/APB Interface**: CPU access for configuration, status, and control.
* **Optional Cache-Coherency Interface**: Ensures memory consistency in multi-agent or heterogeneous environments.

### 5. Debug and Performance Monitoring

* **Performance Counters**: Track utilization, stalls, and throughput for each engine.
* **Trace Buffers**: Capture execution information for verification or profiling.
* **JTAG/Scan Chain**: Supports RTL testing, scan-based verification, and memory built-in self-test.

### 6. Functional Dataflow

1. **Job Submission**: Operations submitted by host via Job Queue.
2. **Instruction Decode & Engine Selection**: Control Unit parses operations and selects the appropriate engine.
3. **Data Fetch**: DMA and AGUs fetch activation and weight tiles into local buffers.
4. **Computation**: Compute engines process tiles, producing partial sums.
5. **Post-Processing**: Shared vector, activation, pooling, and quantization units finalize outputs.
6. **Writeback**: Results written back to memory with prefetch and burst optimization.
7. **Debug/Monitoring**: Execution traced and performance metrics recorded.


#### The NPU architecture emphasizes:

* **Dual-engine flexibility** for workload-specific acceleration.
* **Modular and hierarchical design** for maintainability and scalability.
* **Tile-based computation and local buffering** to reduce memory bandwidth bottlenecks.
* **Centralized control with intelligent scheduling** for optimized utilization.
