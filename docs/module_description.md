# <p align = center> 3. Module Description </p>

## NPU\_TOP

**Purpose:** top-level integration wrapper. glues host, control, memory, compute, interfaces, and debug; exposes SoC boundary.
**Responsibilities**

* Instantiates clusters (Host\_Interface, Control\_Unit, Memory\_Subsystem, Compute\_Cluster, Interfaces, Debug\_Unit).
* Manages top-level resets, clock domain crossings, and power/gating controls.
* Exposes top-level CSR window and IRQ lines to SoC.
  **Submodules:** host\_iface, control\_unit, memsys, compute\_cluster, axi/iface wrappers, debug\_unit.
  **Config params:** global widths (`AXI_DATA_W`), clock domain names, power island masks.
  **Design notes**
* Keep NPU\_TOP minimal logic — mostly wiring and domain sync.
* Provide a single source-of-truth parameter/config file (JSON/YAML) used to generate RTL params and DV configs.
  **Verification / DV**
* Validate SoC-level integration: CSR accessibility, IRQ behavior, reset sequences, clock gating enables.
  **DFT/Power**
* Top-level scan wrapper, power domain enables, island on/off control.

---

# Host\_Interface

**Purpose:** control plane: accepts jobs/commands from CPU/firmware, exposes CSRs, and issues jobs to Control\_Unit.
**Responsibilities**

* Map and expose register bank (control/status/perf) via AXI-Lite/APB slave.
* Provide a Command/Descriptor ring or Job Queue for multiple outstanding jobs.
* IRQ generation and masking/priority. Provide status snapshot and error reporting.
  **Submodules**
* `axi_lite_slave` (or APB): bus frontend.
* `csr_bank` (auto-generated from YAML): grouped registers (CTRL/STATUS/CFG/PERF).
* `job_queue` (ring or FIFO): descriptor storage with head/tail management & validation.
* `desc_fetcher/validator`: basic sanity checks on descriptors (alignment, size, flag checking).
* `irq_controller`: masks, priorities, aggregation.
  **Behavior / Algorithms**
* Descriptor validation policies (e.g., to reject misaligned base addresses).
* Support both immediate mode (CSRs → run) and descriptor mode (ring → run).
* Optional security checks (auth tokens) for production flows.
  **Params**
* `DESC_DEPTH`, `CSR_WIDTH`, `MAX_JOBS`.
  **DV checklist**
* CSR access timing, W1C / W1S behaviors, concurrent host writes, invalid descriptor injection tests, IRQ masking/unmasking semantics.
  **DFT / Power**
* Retention regs for CSR in low-power; scan chain insertion in csr\_bank.

---

# Control\_Unit

**Purpose:** global orchestration — decode incoming jobs, schedule/tiling, engine selection, dependency resolution.
**Responsibilities**

* Read descriptors or CSRs, decode to sequences of micro-ops (or uops).
* Engine\_Selector: choose Systolic vs MAC (policy table or heuristics).
* Tiling\_Manager: break large tensors into tiles sized for engines & buffers.
* Job\_Dispatcher: issue DMA requests and compute start commands; manage fences/barriers.
* Track outstanding tiles, manage completion, and error propagation.
  **Submodules**
* `instruction_decoder` / `microcode_engine` (if micro-ops used).
* `tiler` (multi-dimensional tiler supporting im2col and direct-conv tiling).
* `engine_selector` (policy logic + thresholds).
* `dispatcher` & `job_tracker` (state machine per job/tile).
* `dependency_checker` (simple tag-based or full DAG logic).
  **Algorithms / Modes**
* Static rule table (e.g., if `M,N,K >= T` → systolic) and dynamic adjustments using perf counters.
* Tile ordering strategies: row-major, cache-friendly stripe, or K-major for different dataflow.
* Support for double-buffering coordination: prefetch next tile while current computes.
  **Params**
* `TILING_STRATEGIES`, `SCHED_POLICY`, `MAX_OUTSTANDING_TILES`.
  **DV checklist**
* Tiler correctness for all edge cases (non-multiples, padding, stride/dilation), scheduler stalling, dependency violation tests, job timeout/watchdog tests.
  **Power/DFT**
* Provide replay/rollback hooks for error recovery and debug.

---

# Memory\_Subsystem (cluster)

**Purpose:** feed compute engines with data and store intermediate results with minimal DRAM traffic; manage DMA.
**Responsibilities**

* Host-buffer management: activation buffer, weight buffer, PSUM buffer (banked SRAMs).
* Provide address generation suitable for each engine.
* DMA engine for efficient DRAM transfers with prefetch/writeback.
* Arbitration and QoS between engines and DMA.
  **Submodules**
* `activation_buffer` (banked ping-pong SRAMs + bank arbiter).
* `weight_buffer` (banked SRAMs + prefetcher).
* `psum_buffer` (optionally partitioned per engine).
* `agu_cluster`:

  * `agu_systolic`: emit contiguous burst addresses aligned to wavefront schedule.
  * `agu_simd`: emit stripes/gather/scatter patterns and tail masking.
* `dma_cluster`:

  * `axi_master_core` (reorder/ID management).
  * `read_fsm` / `write_fsm` / `outstanding_tracker`.
* `prefetch_controller` and `writeback_controller`.
* `bank_arbiter` / `crossbar` between buffers and compute engines.
  **Behavior / Algorithms**
* Bank interleaving policies to avoid conflicts (e.g., low- conflict mapping used by scheduler).
* Watermark-driven prefetch: fill buffers when occupancy below threshold.
* Burst alignment to AXI boundaries (64B/128B) for efficiency.
* Reorder handling for AXI responses, support for ID-tag based reassembly in read path.
  **Params**
* `BANK_COUNT_A/W/P`, `BANK_WIDTH`, `SRAM_DEPTH`, `AXI_DATA_W`, `MAX_OUTSTANDING`.
  **DV checklist**
* Bank-conflict injections, misaligned base tests, AXI error injection, ECC error injection and recovery, DMA reordering tests.
  **DFT / Power**
* MBIST controllers for SRAM macros; ECC parity optional; per-bank power gating support.

---

# Systolic\_Array\_Engine

**Purpose:** high-throughput dense matrix multiply and conv core using a 2D systolic dataflow.
**Responsibilities**

* Stream tiles of A and B into an R×C PE mesh in a skewed/wavefront fashion; compute many MACs with local reuse.
* Provide deterministic throughput and predictable latency per tile.
* Minimize external memory bandwidth by reusing data on-chip.
  **Submodules**
* `systolic_array_controller` (fill/run/drain FSM, flow control).
* `systolic_pe_array` (grid of PEs; neighbor links).
* `input_stream_buffer` (north/west streamers, skew registers).
* `output_collector` (east/south drains, packer to PSUM buffer).
* `local_sched` (tile-level micro scheduler; supports partial replays).
  **PE micro-architecture**
* Basic operations: `multiply -> addacc -> forward` with local registers to hold activation/weight and psum.
* Optional features: zero-skip gating, partial accumulation to local SRAM, configurable precision pipelines.
  **Dataflow**
* Wavefront skew aligns k-steps; each cycle shift data along rows/cols so each PE multiplies appropriate operands.
  **Parameters**
* `ROWS`/`COLS`, `PE_PIPELINE_DEPTH`, `DATAFLOW_MODE` (weight-stationary / output-stationary variants), precision options.
  **Performance / Considerations**
* High throughput for large tile sizes; underutilized for tiny tiles due to fill/drain overhead.
* Design impact: inter-PE routing complexity and timing at high frequencies.
  **DV checklist**
* Correct corner-case tiling: non-square tiles, K partial tiles, skew correctness, handshake/ready-valid per border, fairness & deadlock avoidance.
  **DFT / Power**
* Per-row/col clock gating, debug taps at border PEs, scan insertion guidance (careful with neighbor links).

---

# MAC\_Array\_Engine (SIMD-style)

**Purpose:** flexible array for smaller GEMMs, elementwise ops, and irregular patterns — complements systolic engine.
**Responsibilities**

* Provide vector-style lanes capable of performing multiple MACs per cycle with easy support for reductions and elementwise ops.
* Support small matrix shapes and gather/scatter style accesses more efficiently than systolic.
  **Submodules**
* `mac_array_controller` (issue and tile sequence control).
* `mac_pe_array` (banks/tiles of PEs, each with local regfiles).
* `input_distributor` (broadcast/striping logic).
* `output_accumulator` (local reduction trees, writeback gather).
* `dataflow_controller` (masking, lane coordination, tail proccessing).
  **PE micro-architecture**
* Typically wider datapath, supports lane masking, predication, local accumulation registers, vector ALU ops.
  **Parameters**
* `LANES`, `LANE_WIDTH`, `ACC_DEPTH`, supported precisions (INT8/BF16/FP16).
  **Performance**
* Better at small-sized GEMMs, depthwise convs, and elementwise chains; lower area-efficiency for huge GEMMs compared to systolic.
  **DV**
* Test reduction correctness, predication/masking edge cases, lane utilization measurement, stall/backpressure interactions with memory subsystem.
  **DFT / Power**
* Per-lane power gating; simulate enabling/disabling lanes to save power.

---

# Vector\_Units (shared)

**Purpose:** elementwise operations, reductions, normalization primitives that are used by both engines and postproc.
**Responsibilities**

* Provide vector add, sub, mul, min/max, shift, compare, reduction (sum/max), and small scalar ops (bias add, scale).
* Serve LayerNorm/BatchNorm building blocks and other small linear algebra primitives.
  **Submodules**
* `vector_alu` (multi-lane ALU), `reduction_tree`, `mask_unit` (predicate application), `broadcast_unit`.
  **Params**
* `VECTOR_WIDTH`, `LANE_COUNT`, `MASK_SUPPORT`.
  **DV**
* Verify elementwise ops across lane-level masking, sign/unsigned correctness, saturating/non-saturating modes.
  **Power**
* Clock gating when idle.

---

# Activation\_Unit (shared)

**Purpose:** compute nonlinear activation functions required by networks.
**Responsibilities**

* Support ReLU (cheap), LeakyReLU, PWL-LUT approximations (Sigmoid/Tanh/GELU), and iterative/CORDIC options for exp/log for softmax.
* Provide batched softmax (exp->sum->div) path in cooperation with vector units.
  **Submodules**
* `relu_block`, `pwl_lut_block` (configurable segments), `cordic_core` (if precise exp/log needed), `softmax_controller` (reduction + normalization).
  **Params**
* LUT depth & segment count, CORDIC iterations, fixed-point vs FP mode.
  **DV**
* Verify numerical matching to golden-model (Python) including rounding/quantization behavior.
  **Power**
* LUT-block clock gated; separate config registers for activation modes.

---

# Pooling\_Unit

**Purpose:** spatial aggregation operations (max/avg/global).
**Responsibilities**

* Sliding-window pooling with configurable kernel sizes and strides; support for NCHW/NHWC conversions if needed.
  **Submodules**
* `window_reducer`, `stride_shifter`, optional `padding_handler`.
  **DV**
* Verify border handling, stride/dilation combos, and overlap behaviors.

---

# Quantization\_Unit

**Purpose:** precision conversions and affine quantization ops common in inference.
**Responsibilities**

* Per-tensor/per-channel scale & zero-point application, rounding modes (RNE/RTZ), saturation/clamping.
* Convert FP16/BF16 to INT8 and back, or INT32->INT8 with correct scaling and clipping.
  **Submodules**
* `scale_mul` (fixed-point multiplier), `barrel_shifter`, `rounder`, `saturator`.
  **Params**
* `ROUNDING_MODE`, `SCALE_WIDTH`, `RANGE_CLAMP`.
  **DV**
* Validate bit-exact matching against golden reference for quantized model inference, edge saturation.

---

# PostProcessing (shared wrapper)

**Purpose:** pipeline outputs through activation, pooling, quantization, packing and format conversion prior to writeback.
**Responsibilities**

* Provide a small pipeline that accepts partial results, applies activation/pooling/quant, packs into writeback format (NCHW/NHWC), and forwards to writeback controller.
  **Submodules**
* `activation_unit`, `pooling_unit`, `quant_unit`, `packager`.
  **Behavior**
* Accepts backpressure; must be fast enough to avoid stalling compute engines or provide local small FIFO.

---

# Interfaces (AXI master, AXI-Lite/APB, coherency)

**Purpose:** SoC connectivity.
**Responsibilities**

* `AXI_Master_IF`: high-throughput read/write for DMA (burst align, ID management).
* `AXI-Lite_APB_IF`: CSR access for host.
* `Cache_Coherency_IF` (optional): translate coherent snoops or support CHI/ACE.
  **Submodules**
* `axi_master_core` (with outstanding trackers), `apb_slave`, `coherency_adapter`.
  **DV**
* AXI protocol compliance checks, outstanding limits, error handling.
  **DFT / Security**
* Bus-level watchdogs, firewall for DMA addresses.

---

# Debug\_Unit

**Purpose:** observability & bring-up support.
**Responsibilities**

* `perf_counters`: counters for per-engine utilization, memory stalls, DMA bandwidth, bank conflicts.
* `trace_buffer`: circular buffer of selected events/transactions for post-mortem.
* `tap_sites`: selectable internal taps (PE outputs, border streams) for debug.
* `jtag_scan`: boundary-scan and MBIST controller connections.
  **Design notes**
* Make trace configurable: light sampling vs full trace (size vs overhead).
  **DV**
* Validate counters under deterministic workload; trace replay; MBIST pass/fail.

---

# DFT & Test Blocks

**MBIST Controller**

* For each SRAM bank, MBIST engine providing March tests or chosen patterns.

**Scan Chains**

* Partitioned scan architecture respecting power islands and enabling partial-scan for compute islands.

**Logic BIST (optional)**

* For smaller modules if required.

**Verification Hooks**

* Error injection points for ECC/fault handling.

---

# Cross-cutting design considerations (applies to many modules)

**Parameterization**

* Central config file defines sizes: `ROWS`, `COLS`, `LANES`, `BANKS`, `AXI_DATA_W`, datatypes. Use this to generate SV params and DV scenarios.

**Clock Domains & CDC**

* Typical domains: `sys_clk` (host, DMA), `compute_clk` (engines & buffers), `csr_clk` (CSR/perf). Use async FIFOs and gray counters for pointer crossing.

**Backpressure semantics**

* Use valid/ready streaming contracts within compute/memory pipelines. Ensure skid buffers at domain boundaries.

**Power**

* Provide `clk_en` and `pwr_state` signals to critical modules (compute arrays, buffers). Keep gating coarse at first (per-cluster) then refine (per-row).


