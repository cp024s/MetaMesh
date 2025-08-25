
## Top-level tree (compact view)

```
SoC_TOP
 └─ NPU_Subsystem
    ├─ NPU_TOP (SoC wrapper)
    │  ├─ Host_Interface (CSRs, desc ring, IRQ)
    │  ├─ Control_Unit (Scheduler, Microcode, JobQueue)
    │  ├─ Interconnect_Cluster (XBar, CDC bridges)
    │  ├─ Memory_Subsystem
    │  │  ├─ DMA_Cluster (AXI RD/WR)
    │  │  ├─ AGU_Cluster (address gens)
    │  │  ├─ Buffering_Cluster (A/W/PSUM banks + bank controllers)
    │  │  └─ Prefetch/Writeback
    │  ├─ Compute_Cluster (compute_clk island)
    │  │  ├─ Compute_Engine
    │  │  │  ├─ Array_Fabric (systolic / SIMD)
    │  │  │  │  └─ PE (MAC_Unit) [Multiplier + Acc + regs + bypass]
    │  │  │  ├─ Accumulator_Buffer
    │  │  │  ├─ Vector_Unit / Eltwise
    │  │  │  ├─ PostProcessing (Activation, Pooling, Quant)
    │  │  │  ├─ Sparsity_Unit / Compression
    │  │  │  └─ Pipeline_Control
    │  │  └─ Output_Packer
    │  ├─ Coherency_Adapter (opt)
    │  ├─ Debug_Perf (counters, trace, taps)
    │  ├─ Clock_Reset_Power (gating, island mgr)
    │  └─ Test_DFT (MBIST, scan/JTAG)
    └─ NPU_Wrapper (AXI ports, IRQ, clocks)
```

---

# Now—deep dive: each main module → submodules → leaf blocks

I'll go module-by-module. Each top header below is a main NPU module; inside are the submodules and leaf-level components.

---

## 1) NPU\_TOP (SoC wrapper)

**Purpose:** SoC-facing wrapper that exposes AXI/AXI-Lite/APB ports, IRQs, and clock/reset. It instantiates the functional clusters.

**Submodules / leafs**

* `AXI_Interface_Wrapper`

  * AXI master ports for RD/WR, ID handling, outstanding trackers.
  * AXI-Lite / APB slave for CSR access.
* `Power_Reset_Nexus`

  * Top-level reset synchronizers, power control signals to islands.
* `Pin/IO_Mux` (if required)

  * Map physical IO to internal buses.

**Key signals/interfaces**

* External: `axi_master_if[]`, `axi_lite_if`, `irq_out[]`, `clk_in[]`, `rst_n[]`.
* Parameterization: `AXI_DATA_W`, `OUTSTANDING_REQ`.

**Notes**

* This module should be minimal — only glue, parameter handing, top-level DFT hooks.

---

## 2) Host\_Interface (CSR bank, descriptor ring, auth)

**Purpose:** Host (CPU/driver/firmware) control plane: CSRs, job descriptor ring, command/response, interrupts.

**Submodules**

* `CSR_Bank`

  * register blocks (W1C/W1S/RO/RW), auto-generated from YAML/CSV.
* `Descriptor_Ring`

  * descriptor SRAM, head/tail pointers, validation.
* `IRQ_Controller`

  * masks, priority, event aggregation, W1C.
* `Auth/Security` (opt)

  * decryption of encrypted weights, secure boot hooks.

**Leaf blocks**

* `csr_decoder`, `csr_write_pipeline`, `csr_read_pipeline`
* `desc_fetcher`, `desc_validator`, `desc_fsm`

**Typical ports**

* From SoC: `axi_lite_*` or `apb_*`
* To Control Unit: `job_valid, job_desc[bus], job_ack`
* IRQ: `irq_done`, `irq_err`

**Verification pointers**

* CSR atomicity, W1C semantics, descriptor wrap-around, invalid descriptor handling.

---

## 3) Control\_Unit (Scheduler & Microcode)

**Purpose:** The brain that issues DMA requests, controls compute phases, tiling, fences, multi-job scheduling.

**Submodules**

* `Scheduler`

  * global DAG planner, multi-job arbitration, QoS.
* `Tiler`

  * tile decomposition (n,h,w,c), edge masks, tile sequencing.
* `Microcode_Engine` (optional)

  * µOP ROM, fetch/decode/execution, small RISC for complex kernels.
* `JobQueue` / `EventMgr`

  * job states, semaphores, host sync.
* `Exception_Manager`

  * watchdog, AXI error handling, ECC error recovery.

**Leaf blocks**

* `tile_state_machine`, `sched_priority_arb`, `uop_fetch`, `uop_decoder`

**Interfaces**

* Upstream: `job_desc`
* Downstream: `dma_req`, `compute_start/stop`, `cfg_regs`

**Notes**

* Keep scheduler deterministic and observable (for debug).
* Provide replay hooks to re-run failed tiles.

---

## 4) Interconnect\_Cluster (XBar, format bridges, CDC)

**Purpose:** Internal data movement: crossbars, arbiters, QoS, and clock domain bridges.

**Submodules**

* `XBar_Read`, `XBar_Write`

  * multi-master/multi-slave crossbar with IDs and QoS.
* `Arbiters` & `Bank_Selectors`

  * per-bank arbitration, backpressure management.
* `CDC_Bridges`

  * safe transfers sys\_clk ↔ compute\_clk (grey-code counters, async FIFOs).
* `Format_Bridge`

  * AXI → internal streaming formatter (pack/unpack to lane width).

**Leaf blocks**

* `round_robin_arb`, `priority_arb`, `fifo_async`, `pkt_formatter`

**Design notes**

* Add per-stream QoS and bank-aware arbitration to reduce hotspots.
* Formal-check CDC boundaries.

---

## 5) Memory\_Subsystem (DMA, AGUs, Buffers)

**Purpose:** Efficiently feed compute engine with activations/weights and write back outputs — hides DRAM latency.

### 5.1 DMA\_Cluster

* `AXI_Master_Read` (Burst gen, alignment, ID/tag manager)
* `AXI_Master_Write` (Write-combiner, response tracker)
* `OutstandingTracker` (credits, reorder buffer)
* `ErrorHandler` (AXI response errors)

**Leaf IP to reuse:** vendor AXI DMA cores (but extend with custom AGU and tiler hooks).

### 5.2 AGU\_Cluster (Address Generators)

* `AGU_Act` (N-D generator supporting stride, padding, dilation, transpose)
* `AGU_Wgt` (pack to tiles / KC packing)
* `AGU_Out` (layout conversion to mem format)
* `AGU_Controller` (issue patterns, boundary masks)

**Leaf blocks**

* `nd_addr_gen`, `wrap_counter`, `mask_gen`

### 5.3 Buffering\_Cluster (SRAM Banks)

* `Activation_Buffer` (A\_Bank\[0..A\_BANKS-1])

  * bank controller, ECC/parity, bank arbiter, bank crossbar.
* `Weight_Buffer` (W\_Bank)
* `PSUM_Buffer` (P\_Bank)
* `Format_Adapters` (NCHW↔NHWC, pack/unpack, transpose)

**Leaf blocks / macros**

* `SRAM_macro_wrapper` (read/write ports, ECC interface)
* `bank_arbiter`, `bank_interleaver`, `line_buffer` (for conv sliding window)

### 5.4 Prefetch / Writeback Controllers

* `Prefetcher` (watermark-based prefetch policies)
* `Writeback` (merge/combine partial writes, reorder)

**Key considerations**

* Double-buffering to overlap DMA and compute.
* Bank count and width designed from required BW formula.

---

## 6) Compute\_Cluster (compute\_clk power island)

**Purpose:** All compute logic: array fabric, accumulators, post-processing, sparsity.

### 6.1 Compute\_Engine (top compute module)

* `Array_Fabric` — systolic or vector-based arrays.
* `Accumulator_Buffer` — PSUM handling, partial accumulation.
* `Vector_Unit` — SIMD elementwise ops.
* `PostProcessing` — activation, pooling, quantization, packing.
* `Sparsity_Unit` — mask decode, index decoder, compressed format handler.
* `Pipeline_Control` — ready/valid network, skid buffers, stall propagation.
* `Local_Scheduler` — per-tile micro-phasing, clear\_acc, save/restore.

#### 6.1.1 Array\_Fabric

**Substructure**

* `Rows[0..R-1]` × `Cols[0..C-1]`

  * Each intersection: a `PE` (Processing Element / MAC\_Unit).
* `West_Edge_IF` / `North_Edge_IF` (borders for act/wgt ingress)
* `East/South_Edge` for outputs
* `Diagonal/Skewing` networks if systolic requires rotation.

**PE (MAC\_Unit) leaf**

* Multiplier (DSP macro or RTL)
* Adder / Accumulator (wider)
* Local register file for weight and activation
* Bypass / forwarding paths
* Valid/ready per-stage handshake
* Overflow / saturation logic
* Optional skip logic (for sparsity)
* Optional pre-adder (for depthwise conv fusion)

**Signals**

* Per-PE: `act_in`, `wgt_in`, `psum_in`, `psum_out`, `vld/rdy`, `clear_acc`, `dbg_tap`.

**Design notes**

* Pipeline MAC to meet timing (multiplier latency + adder tree).
* Use DSP macros in ASIC/FPGA where possible. Add optional power gating across blocks.

#### 6.1.2 Accumulator\_Buffer

* Local PSUM FIFOs, line buffers for output-stationary/dataflows.
* ECC/Parity on larger PSUM banks.
* Read-after-write hazards handling for partial writes.

#### 6.1.3 Vector\_Unit / Eltwise

* SIMD lanes to do broadcast ops, scale+add, bias add, elementwise multiply.
* Mask support for valid lanes.

#### 6.1.4 PostProcessing

* `Activation_Unit` (ReLU, LeakyReLU, GELU via PWL LUT or CORDIC)
* `Pooling_Unit` (window reducer with stride control)
* `Quantization_Unit` (scale, shift, rounding, clamp)
* `Format_Packer` (pack to desired mem layout and tile size)

**Leaf blocks**

* `pwl_lut`, `cordic_core`, `barrel_shifter`, `saturator`

#### 6.1.5 Sparsity & Compression

* `Sparsity_Decode` (2:4 mask decode, block-sparse indices)
* `Index_to_addr` (scatter/gather logic)
* `Compressed_Reader` (RLE, CSR decode)
* `Skip_Control` (gate PEs / reduce power)

**Notes**

* Sparsity introduces variable latency & irregular memory access — must be supported by scheduler/AGUs.

#### 6.1.6 Pipeline\_Control

* Full valid/ready handshake network across compute pipeline.
* Skid buffers at domain crossings.
* Drain/flush FSMs for job completion and errors.

---

## 7) Output\_Packer / Layout Converter

**Purpose:** Convert compute results to DRAM layout and feed writeback DMA.

**Submodules**

* `Layout_Converter` (tile to global coords)
* `WriteCombiner` (pack bursts, merge partial writes)
* `Compression` (optional quant packing, bit-packing)

**Leafs**

* `packers`, `striders`, `burst_align`

---

## 8) Coherency\_Adapter (optional)

**Purpose:** If the NPU needs cache coherency with CPU/GPU (shared memory), provide ACE/CHI/ACE-Lite adaptors and snoop filters.

**Submodules**

* `Coherency_Slave` (CHI/ACE handling)
* `Snoop_Filter` (reduce snoop traffic)
* `Cache_Line_Buffer` (optionally keep local cache lines for reuse)

**Complexity**

* High. Consider using licensed IP for CHI/ACE or use software-managed coherence.

---

## 9) Debug\_Perf (observability)

**Purpose:** Telemetry, counters, trace streaming; essential for performance tuning.

**Submodules**

* `Perf_Counters` (mac\_util, stall\_by\_cause, dma\_bw, bank\_conflicts)
* `Trace_Streamer` (non-intrusive sample taps, circular buffer)
* `Event_Logger` (timestamped events)
* `Probe_Taps` (configurable taps inside array/AGUs)

**Leafs**

* `counter_unit`, `trace_fifo`, `timestamp_unit`

**Tips**

* Expose lightweight sampling mode & deterministic full-trace mode.
* Provide debug CSR registers to read counters.

---

## 10) Clock\_Reset\_Power

**Purpose:** Manage clocks, gating, power islands, and synchronize resets.

**Submodules**

* `Clock_Manager` (PLLs, clock mux)
* `Clock_Gaters` (per-row/per-quadrant gating control)
* `Power_Controller` (island on/off, retention)
* `Reset_Sync` (per-domain reset synchronizers)

**Leafs**

* `cg_cell_wrappers`, `retention_reg_bank`, `reset_ff_sync`

**RTL notes**

* Expose gating enables via CSR (for verification).
* Insert false-paths for async domain crossings in SDC.

---

## 11) Test\_DFT

**Purpose:** Make the chip testable and SRAMs BISTable.

**Submodules**

* `MBIST_Controller` (for SRAM macros)
* `Scan_Chain_Manager` (DFT inserted)
* `JTAG_Wrapper` (boundary scan)
* `LBIST_Controller` (optional)

**Leafs**

* `mbist_engine`, `bistseq`, `scan_mux`

**Notes**

* Hook MBIST into all SRAM macros, provide test mode in CSRs.

---

## 12) Security & SW Integration

**Purpose:** Protect IP / model weights and provide firmware hooks.

**Submodules**

* `Secure_Boot` / `Key_Storage`
* `AES_Decrypt` / `HASH` blocks (for secure weights)
* `FW_IF` (firmware image upload, debug disable)

**Interfaces**

* Key provisioning protocol, secure CSRs.

---

## 13) Datalayout & Format helpers

* `Im2Col` / `Winograd` support modules (optional).
* `Transpose` / `Reshape` cores.
* `QuantPack` (bit-packing intermediate values).

---

# Leaf-level building blocks (atomic RTL modules)

These are the modules you'll write once and reuse widely.

* **PE / MAC\_Unit** (multiplier + adder + accumulator + regs)
* **DSP wrapper** (map to vendor DSP macros)
* **SRAM macro wrapper** (port handling, precharge, ECC)
* **FIFO (sync / async)** (size param, almost always reused)
* **Arbiter (RR / Priority / QoS)** (per-bank)
* **Crossbar / switch** (router for noC)
* **Barrel shifter** (for quant/scale)
* **PWL LUT** (activation)
* **CORDIC** (if needed)
* **Address generator (n-d)** (parametric)
* **Rounder / saturator** (fixed point rounding)
* **Comparator / min-max** (pooling)
* **CSR generator** (auto-generate from YAML)
* **Scan/bist hooks** (DFT wrappers)
* **CDC/Gray counters** (for multi-clock domain)

---

# Interfaces & Protocols (what to expose per module)

For integration clarity, here are typical ports each major block must provide:

* **Compute\_Engine**

  * Streaming ports: `act_in[v]/act_vld/act_rdy`, `wgt_in/wgt_vld/wgt_rdy`, `psum_in/psum_vld/psum_rdy`, `out/out_vld/out_rdy`
  * Control: `start`, `stop`, `clear_acc`, `cfg_*` CSRs
  * Status: `busy`, `done`, `err_code`, `utilization`

* **DMA**

  * AXI master signals; internal request/ack handshakes; desc interface to Host\_Interface

* **Buffers**

  * Banked read/write interfaces with `addr, be, data, valid, ready`, ECC error outputs

* **Scheduler**

  * Issue signals: `issue_dma(addr,len)`, `issue_compute(tile_id)`, `fence`, `irq`

---

# Verification checklist per module (short)

* **CSR/Host\_Interface:** atomicity, reset values, W1C, overflow on descriptor ring
* **Scheduler:** tile correctness, fence ordering, VOC interleaving, job preemption
* **DMA:** AXI protocol conformance, misaligned bursts, outstanding limits, error handling
* **AGU:** correct address sequence, wrap/stride, boundary masks
* **Buffers:** bank conflict injection tests, ECC error injection & recovery
* **PE/Array:** golden-model compare across precisions, saturation/rounding match, pipeline hazards
* **Sparsity:** mask-driven correctness & alignment
* **Pipeline\_Control:** no deadlock / forward progress, drain/flush tests
* **DFT:** MBIST passes for macros
* **Power:** clock gating enable/disable mid-flight tests

---

# Parameterization (single source of truth)

Keep these params central (e.g., json/yaml):

* `ROWS`, `COLS` (array dims)
* `ACT_W`, `WGT_W`, `PSUM_W`, `OUT_W`
* `A_BANKS`, `W_BANKS`, `P_BANKS`, `BANK_WIDTH`
* `AXI_DATA_W`
* `DESC_DEPTH`
* `HAS_COHERENCY`, `HAS_SPARSITY`, `HAS_MICROCODE`
* `POWER_ISLANDS`, `CG_GRANULARITY`

---
