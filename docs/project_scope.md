
# **1. INTRODUCTION**

## **1.1 Purpose of the Document**

This document defines the **complete scope, boundaries, expectations, constraints, architectural intent, verification strategy, and performance objectives** for the Neural Processing Unit (NPU) Proof-of-Concept (PoC).

Its purpose is to:

1. Create a **single unified reference** for all engineering efforts.
2. Consolidate previous discussions, architectural notes, project requirements, and uploaded NPU research materials.
3. Ensure that the design, verification, and prototype implementation follow a **consistent and traceable technical direction**.
4. Prevent scope drift by explicitly declaring both included and excluded features.
5. Enable a clear baseline for future enhancements once PoC milestones are reached.

This document is meant to guide the:

* RTL design
* microarchitecture decisions
* FPGA implementation
* verification plan
* performance evaluation
* system integration
* documentation and sign-off

---

## **1.2 Background and Context**

### **Industry Trends**

The explosive adoption of deep neural networks has increased demand for **specialized compute hardware**, giving rise to modern NPUs embedded in:

* mobile SoCs (Samsung, Qualcomm, Apple Neural Engine)
* edge devices (Google EdgeTPU)
* server-grade accelerators (NVIDIA TensorCores, Intel Gaudi, Cerebras, Graphcore)
* FPGA-based NPUs (Brainwave, Versal AI Engines, Intel Stratix 10 NX)

These NPUs follow common architectural themes:

* deeply pipelined compute engines
* systolic and semi-systolic dataflows
* tiling & reuse-heavy memory hierarchies
* sparsity exploitation
* mixed-precision arithmetic
* scalable multi-core compute tiles
* high-bandwidth, multi-ported scratchpad memory
* on-device scheduling
* decoupled host/NPU execution model

### **Insights from Uploaded Research Papers**

From the papers you provided:

#### **1) Samsung Sparsity-Aware NPU Architecture**

* Zero-skipping improves energy & throughput
* Reconfigurable MAC arrays help maintain utilization
* Dynamic memory port assignment avoids bandwidth bottlenecks

These influence PoC choices: simple pathway for sparsity, modular PEs, potential for multi-mode execution.

#### **2) Hybrid PRO3 NPU Architecture**

* Separation of pre-processing, memory management, scheduling, and programmable pipeline
* Heavy reliance on dedicated hardware blocks
* Efficient field extraction/modification engines

This informs your desire to define clean module boundaries.

#### **3) FPGA vs GPU AI Performance (Intel Brainwave + TensorBlocks)**

* Achievable throughput depends on tensor unit utilization
* Dataflow and scheduling matter more than peak theoretical TOPS
* Persistent data improves latency

These guide the PoC’s performance measurement strategy.

---

## **1.3 What This Project Is Building**

This project is not designing a production-grade NPU.
It is designing a **Proof-of-Concept NPU** with:

* a real compute engine
* realistic on-chip buffering
* basic instruction/control logic
* host-driven configuration
* working dataflow for neural workloads
* synthesizable RTL + testbench
* an FPGA prototype
* measurable throughput & latency

The design must be:

* simple enough to complete as a single-engineer PoC
* modular enough to extend later
* architecturally clean
* consistent with real-world NPU principles

---

## **1.4 Project Objectives (Extended)**

### **A. Functional Objectives**

* Execute tile-based GEMM and 1×1 conv-like operations
* Perform MAC-heavy workloads using a configurable compute engine
* Provide a deterministic micro-sequenced pipeline
* Allow host to configure/control operation
* Produce correct mathematical results validated against a reference model

### **B. Architectural Objectives**

* Define a clean top-level:

  * Compute Engine
  * Scratchpad Memory
  * Weight Buffer
  * PSUM Buffer
  * Host Interface
  * AXI data movement
  * Microsequencer or instruction FSM
* Implement reusable building-block PEs
* Enable pipeline-level performance measurement

### **C. Verification Objectives**

* Build a structured SV testbench / UVM-lite environment
* Include scoreboards, predictors, coverage points
* Produce cycle-accurate RTL-to-reference validation
* Validate on FPGA with real vectors

### **D. Performance Objectives**

* Achieve meaningful MAC utilization
* Evaluate bandwidth ceilings
* Produce cycle and latency breakdowns
* Plot sustained vs theoretical throughput

### **E. Non-Functional Objectives**

* Synthesizable, clean RTL
* Parameterized modules
* Clear documentation
* Debug instrumentation

---

## **1.5 Philosophy and Design Principles**

This PoC follows these technical principles:

### **1. Simplicity over completeness**

The PoC should prioritize clean architectural expression, not feature overload.

### **2. Determinism over dynamism**

Static scheduling and deterministic dataflow are preferred initially.

### **3. Realistic but minimal**

Design must resemble real NPUs but at a reduced scope.

### **4. Modularity**

Every block should be reusable for future scaling.

### **5. Parameterization**

Supporting configurable sizes simplifies exploration.

### **6. Measurability**

The architecture must expose:

* stall points
* bandwidth bottlenecks
* utilization metrics
* cycle-level timings

### **7. Traceability**

Every requirement must map to:

* an RTL module
* an interface
* a test scenario

---

## **1.6 Scope Boundaries (Enhanced)**

### **In-Scope Features**

✔ Compute engine (MAC array / PE architecture)
✔ On-chip memory subsystem
✔ Weight-loading and data tiling
✔ PSUM accumulation
✔ Activation unit (ReLU/basic ops)
✔ Host/NPU register interface
✔ AXI-lite configuration interface
✔ AXI-stream or AXI-master data interface
✔ Tile-based scheduler
✔ Control FSM or microsequencer
✔ Python/C++ reference model
✔ Functional & performance verification
✔ FPGA implementation

### **Explicitly Out-of-Scope**

❌ Full graph compiler
❌ Mixed precision support beyond INT8 initial target
❌ Hardware-driven sparsity detection
❌ Attention/transformer-specific blocks
❌ Multi-core NoC
❌ On-chip DRAM controllers
❌ Dynamic voltage-frequency scaling
❌ Runtime model parsing
❌ Hardware-level compression/decompression
❌ End-to-end NN runtime (like TensorRT or QNN)

These can be Phase-2 or Phase-3 evolutions.

---

## **1.7 Expected Outcomes**

At the end of the PoC, the following should exist:

* Fully functional RTL NPU core
* Synthesizable, timing-clean design
* Structured verification testbench
* Python/C++ reference for golden comparison
* FPGA prototype with:

  * real data execution
  * performance counters
  * host-driven command execution
* Documentation:

  * architecture
  * verification
  * performance summary
  * setup & integration guide

---

## **1.8 Long-Term Vision**

While the PoC is minimal, it establishes the foundation for:

* multi-core systolic expansion
* runtime-configurable ISA
* sparsity and mixed-precision support
* compiler + code generation
* integration into a full SoC
* optimization for real inference workloads

Nice — diving into **Section 2 — Functional Scope**, and I’ll make it exhaustive, technically precise, and directly actionable. I won’t hold back: expect detailed block-level behavior, dataflows, interfaces, control/ISA outlines, example sequences, and functional acceptance criteria. Read through and tell me “next” when you want Section 3 (Architectural Scope).

---


# **2. FUNCTIONAL SCOPE — NPU PoC**

## 2.1 High-level PoC Capabilities (summary)

* Execute **matrix-vector (GEMV)** and **small-matrix multiply (GEMM)** primitives as the primary compute kernel.
* Execute **conv-like** operations via **tiling** and use GEMV/GEMM as building blocks (PoC supports 1×1 conv natively; larger kernels via tiling/unrolling).
* Support **element-wise** vector operations (add, mul, clamp, ReLU).
* Baseline numeric precision: **INT8** (signed 8-bit inputs/weights), with **INT16** accumulation where required (time-multiplexed).
* Optional compile-time configuration to simulate **INT16** datapath via repeated INT8 operations (no extra accumulators).
* Implement **weight persistence** in on-chip memory (weight buffer / MRF-like storage).
* Implement **double-buffered input streaming** for hide-latency tiling.
* Provide **host control & configuration** via AXI-Lite registers.
* Provide a streaming data path for input/output via AXI-Stream or AXI master DMA-like accesses.
* Provide observable **performance counters** (cycle counts, stalls, MAC utilization, bandwidth usage) and debug hooks (trace FIFOs).
* Basic **error handling** and status reporting (parity, protocol violations, overflow flags).

---

## 2.2 Supported Operations & Micro-ops

### 2.2.1 Compute primitives (atomic operations)

* `DOT_PRODUCT(V_len)` — compute dot product between local weight vector and input vector (length configurable by design-time parameter L).
* `MAC_ACC` — single multiply-accumulate (for microsequencer or micro-op usage).
* `VEC_ADD`, `VEC_MUL` — elementwise add/mul across vectors.
* `ACT_RELU`, `ACT_CLIP` — activation ops; activation implemented in vector unit.
* `WRITEBACK` — move results from PSUM buffer to host-visible output buffer / bus.
* `TAG_UPDATE` — internal bookkeeping message to resolve hazards (PoC uses message passing to update tags).

### 2.2.2 Higher-level instructions / mOPs

* **mOP_LOAD_WEIGHTS(addr, len, dst_weight_bank)** — stage-in weight block to on-chip weight buffer.
* **mOP_START_TILE(src_ifm_ptr, dst_ofm_ptr, tile_params)** — start execution on given tile (tile_params: rows, cols, K, stride info).
* **mOP_WAIT_EVENT(event_id)** — wait for host or other block event (simple synchronization).
* **mOP_BROADCAST(tag, payload)** — issue lightweight broadcast for hazard resolution (PoC uses sequential point-to-point to preserve determinism).

> Implementation note: mOPs are translated by the control unit into micro-ops (uOPs) executed by compute blocks. PoC will implement a VLIW-lite with fields mapping to pipeline stages: MVU, eVRF, MFUs, LD (similar to Brainwave/NPU overlay but simplified).

---

## 2.3 Dataflows — canonical and examples

### 2.3.1 Key buffers & ports (logical)

* **IFM Buffer (Input Feature Map scratchpad)** — double-buffered to enable compute/transfer overlap.
* **Weight Buffer / MRF** — persistent local store for weights of a layer/tile.
* **PSUM Buffer** — stores partial sums between reduction stages.
* **IO FIFOs / AXI adapters** — interface to host / NoC (AXI-S in/out).
* **Instruction FIFO** — holds mOPs or microprogram entries for the control unit.
* **Telemetry FIFOs** — performance telemetry and traces.

### 2.3.2 Typical dataflow (tile / matrix-vector)

1. **Host config & weight load**: Host writes weight bank descriptors into AXI-Lite registers and issues `mOP_LOAD_WEIGHTS`. The weight loader DMA (AXI master) fetches weight blocks into Weight Buffer.
2. **IFM streaming**: Host or DMA populates IFM Buffer (double-buffer).
3. **Issue tile**: Host issues `mOP_START_TILE` containing tile coords and pointers; controller decodes and schedules the tile.
4. **Compute**: MVU requests input vector segments from IFM Buffer; fetches weights from Weight Buffer; computes dot-products (DPE lanes operate in parallel); results pushed to PSUM Buffer.
5. **Elementwise & activation**: After reduction, MFU unit reads from PSUM Buffer, applies `ACT_RELU` or `VEC_ADD` with possible external inputs (skip or chain).
6. **Writeback**: LD writes the final output to output FIFO or triggers AXI writeback to external memory.
7. **Tag updates / hazards**: LD issues tag updates for dependent tiles (sequential for PoC).

### 2.3.3 Dataflow diagram (text)

```
Host --> AXI-Lite regs --------------> Control FSM
                   |                             |
                   v                             v
           Weight load request               mOP stream
                   |                             |
                   v                             |
            Weight Buffer <---- DMA <--- Host memory
                   |
                   v
IFM DMA --> IFM Buffer (double-buffered)
                   |
                   v
              MVU (DPE array) --> PSUM Buffer --> MFU (activation)
                                                  |
                                                  v
                                             Writeback (AXI/stream)
```

---

## 2.4 Interfaces — behavior & requirements

### 2.4.1 Host Configuration Interface (AXI-Lite)

* **Access**: 32-bit register accesses.
* **Registers**:

  * `CTRL.START` — start/stop signal.
  * `STATUS` — idle/busy/error bits.
  * `MOP_QUEUE_PTR` — pointer to instruction/mOP queue.
  * `WEIGHT_DESC[i]` — base addr, length, target weight bank.
  * `IFM_DESC` / `OFM_DESC` — host memory addresses for IFM / OFM.
  * `PERF_CNTR_CTRL` — enable counters, clear counters.
  * `ERR_STATUS` — sticky error flags.
  * `INT_ENABLE` / `INT_CLEAR` — interrupt control.
* **Behavior**: Writes are acknowledged by returning status; control logic must confirm writes before DMA reads. Write-to-start triggers validation (basic sanity checks on params).

### 2.4.2 Data Interface (AXI-Stream / AXI Master)

* **Input path**:

  * Option A: AXI-Stream slave (host streams IFM packets)
  * Option B: AXI master DMA (controller reads IFM from host memory) — preferred for PoC reproducibility.
* **Output path**:

  * AXI-Stream master / AXI master DMA writeback.
* **Protocol rules**:

  * Flow control via TLAST/TVALID/TREADY (AXI-S) or bursts (AXI).
  * FIFO injection/ejection widths: configurable to 32/64/128 bytes; PoC default 64B.
  * ADAPT width conversion inside adapter as necessary.

### 2.4.3 Debug & Telemetry

* `TRACE_FIFO` (RX) — ejection of key events (uOP issue/retire, stalls).
* `PERF_CNTR[0..N]` — cycles, MAC_issued, MAC_active, memory_stalls, IFM_bandwidth_used, PSUM_writeback_stalls.
* Optional JTAG/ILA connection points for FPGA debug.

### 2.4.4 Interrupts & Status

* `INT_STATUS`: bits for `COMPLETION`, `ERROR`, `PERF_OVERFLOW`.
* Host can mask/unmask interrupts; PoC will assert interrupt on tile-set completion or fatal error.

---

## 2.5 Compute Topology & Operating Modes

### 2.5.1 Baseline topology

* Single **NPU core** comprising:

  * MVU with T tiles (design-time parameter)
  * Each tile contains DPEs with L lanes (DPEs x L => parallel MACs per tile)
  * eVRF (external vector register file) for skipping MVU when not required
  * Two MFUs for elementwise ops (vector ALUs)
  * Loader (LD) block for writeback & host comms

### 2.5.2 Parameterization

* `T`: # tiles (reconfigurable at synthesis/config time; PoC default T=4)
* `D`: # DPEs per tile (PoC D=8 typical)
* `L`: lanes per DPE (PoC L=16 typical)
* `IFM_BUF_SIZE`: e.g., 64–256 KB depending on BRAM resources
* `WEIGHT_BANKS`: # banks for weight storage (allows multi-threaded scenarios)

### 2.5.3 Operating modes

* **Single-threaded**: one instruction stream, deterministic.
* **Multi-threading (limited)**: PoC supports up to N logical threads by time-multiplexing MVU slices (subject to resource availability), e.g., 2 threads via partial resource replication — this is optional, configurational; default OFF.
* **Bandwidth-driven mode**: control unit can reshape tile granularity to match NoC/router widths (manually selected in PoC).

---

## 2.6 Memory & Tiling Semantics

### 2.6.1 Tiling model

* **Tile** defined by (M_rows, N_cols, K_depth).
* Tile size chosen to fit IFM + PSUM within on-chip scratchpads to avoid mid-tile DRAM accesses.
* Double-buffering: while tile `i` computes, tile `i+1` IFM is fetched.

### 2.6.2 Scratchpad semantics

* **IFM Buffer**: circular/line buffers. Read semantics are deterministic — reads are only permitted after tile prefetch completes and buffer ready bit set.
* **Weight Buffer / MRF**: persistent per-layer. Writes only via `mOP_LOAD_WEIGHTS`. When weights are loaded, a `WEIGHT_READY` flag is set per bank.
* **PSUM Buffer**: accumulative buffer with atomic add semantics for partial sums — reduction unit serializes accumulates to prevent races (PoC avoids concurrent write hazards by design).

### 2.6.3 Memory ordering & consistency

* Host-visible memory ordering follows: `LOAD_WEIGHTS` → `START_TILE` → `WAIT` complete. PoC enforces memory fences implicitly via STATUS checks; no weak-ordering behavior exposed to host.

---

## 2.7 Functional Boundaries & Limits (explicit)

### 2.7.1 Max problem sizes (PoC configuration)

* Max tile `K` limited by `WEIGHT_BANK` capacity; PoC example: K ≤ 4096 (depends on BRAM).
* Max IFM spatial dims limited by IFM Buffer; PoC typical: 64 KB–256 KB.
* Maximum supported batch-size: PoC optimized for small batch (1–6); large batches are supported but not optimized.

### 2.7.2 Timing & latency expectations (functional)

* Deterministic latency per tile: `(cycles_compute + cycles_memory + cycles_writeback)` — counters report exact cycles.
* No QoS guarantees across multiple concurrent hosts — single-host expected for PoC.

### 2.7.3 Error handling policy

* Non-fatal errors: set `ERR_STATUS`, raise interrupt (optional), halt new tile dispatches until host clears error.
* Fatal errors (bus parity, illegal mOP): set sticky error bit, require host reset to clear.
* Overflow on arithmetic result: set `OVF_FLAG` in `ERR_STATUS`; behavior configurable: saturate or wrap (default: saturate).

---

## 2.8 Control & ISA (detailed PoC proposal)

### 2.8.1 Simple instruction format (VLIW-lite — example 64-bit mOP)

Fields:

* [63:56] — opcode (8 bits)
* [55:40] — operand A (16 bits: IFM addr ptr / reg id)
* [39:24] — operand B (16 bits: weight bank / param)
* [23:8]  — immediate/flags (16 bits)
* [7:0]   — control flags / tile ID (8 bits)

Example opcodes:

* `0x01` — LOAD_WEIGHTS
* `0x02` — START_TILE
* `0x03` — WAIT_EVENT
* `0x04` — WRITEBACK
* `0xFF` — NOP / HALT

> Note: Instruction size and fields are parameterizable. The above is PO C-lean for ease of implementation. Control FSM decodes mOPs and sequences micro-ops for the MVU/MFU/LD.

### 2.8.2 Micro-op scheduling & hazard control

* PoC uses **static scheduling** — host-generated sequences must obey dependencies.
* For host convenience, PoC includes micro-checks: if host issues `START_TILE` while WeightBuffer not ready, hardware sets `ERR_STATUS` and rejects the mOP.
* Tag-based data hazard resolution exists but implemented as sequential point-to-point messages to keep control simple and deterministic.

---

## 2.9 Management, Observability & Debug

### 2.9.1 Telemetry and counters

Counters (read-only via AXI-Lite):

* `CYCLES_TOTAL`
* `CYCLES_BUSY`
* `MAC_OPS_ISSUED`
* `MAC_ACTIVE_CYCLES`
* `IFM_BW_BYTES`
* `WEIGHT_BW_BYTES`
* `PSUM_WRITES`
* `STALLS_MEM`
* `STALLS_DEP`

Counters are 64-bit with wrap/overflow flags.

### 2.9.2 Trace data

Trace FIFO emits annotated records: event type, timestamp, tile_id, uOP id. Trace depth configurable; overflow sets `TRACE_OVF` flag.

### 2.9.3 Debug hooks

* Optional instrumentation signals: `uOP_issue`, `uOP_retire`, `mem_req`, `mem_ack`.
* Recommended FPGA bring-up: include ILA cores on these signals.

---

## 2.10 Configuration & Control API (host-side)

Minimum host-side API (simple pseudo-API that maps to AXI-Lite + DMA calls):

1. `npu_reset()` — reset hardware and clear status.
2. `npu_load_weights(bank, host_addr, len)` — program WEIGHT_DESC and issue LOAD_WEIGHTS.
3. `npu_stream_ifm(host_addr, len)` — program IFM_DESC and kick DMA (or stream via AXI-S).
4. `npu_start_tile(tile_descriptor)` — issue START_TILE.
5. `npu_poll_status()` — read STATUS; block/wait until COMPLETE.
6. `npu_read_perf()` — read perf counters and trace.
7. `npu_clear_error()` — clear ERR_STATUS after handling.

Host drivers for FPGA PoC may be simple scripts that perform these in sequence.

---

## 2.11 Feature Interactions / Important Implementation Notes

* **Writeback bandwidth must match MVU throughput**: tile granularity should avoid PSUM bottlenecks; if writeback is slower, PSUM buffer will stall compute—telemetry will highlight stalls.
* **Weight buffer sizing**: design to hold at least one tile worth of weights to avoid frequent host stalls.
* **IFM Buffer double-buffering**: mandatory for continuous streaming; if disabled, compute stalls are expected.
* **Tag update overhead**: sequential point-to-point tag updates cost cycles; keep number of tag recipients minimal or add parallelism in later phases.
* **Arithmetic overflow handling**: define saturate vs wrap default; saturate recommended for inference correctness.

---

## 2.12 Functional Acceptance Criteria (how to declare functional scope complete)

To accept the Functional Scope as implemented for PoC, the system must satisfy:

1. **Correctness**:

   * Execute a set of canonical workloads (GEMV, small GEMM, a 1×1 conv mapped as GEMV) and produce outputs within acceptable numerical tolerance vs reference model (exact match for INT8 where expected or within defined quantization tolerance).
2. **End-to-end flow**:

   * Host loads weights, streams IFM (via DMA or AXI-S), triggers tile(s), and receives OFM correctly without host intervention in the middle of compute (other than polling or event wait).
3. **Determinism**:

   * For the same workload and inputs, outputs are deterministic cycle-to-cycle (verified across 100 deterministic runs).
4. **Observability**:

   * Perf counters and a trace FIFO are available; recorded cycles for at least one tile match expected compute model within ±5%.
5. **Interface compliance**:

   * AXI-Lite registers obey read/write semantics and handle invalid access gracefully (produce error status, not undefined behavior).
6. **Resource sanity**:

   * Synthesis of PoC parameters (as planned) fits within the selected FPGA (or area budget) and achieves timing at the target frequency (or a documented maximum-frequency objective).
7. **Error handling**:

   * Demonstrated host clear/recovery flow for at least 2 different error conditions (e.g., missing weight bank, writeback bus timeout).
8. **Prototype**:

   * At least one full inference example runs on the FPGA with metrics captured and documented (latency, throughput, resource utilization).

Meeting these criteria completes the **Functional Scope** validation for PoC.

---

## 2.13 Non-functional behavioral notes (clarifications)

* **Security**: PoC does not implement secure boot or encrypted weights; host-level trust assumed.
* **Power**: PoC does not optimize or measure power beyond what FPGA tools report; energy profiling is out-of-scope.
* **Real-time behavior**: Best-effort low-latency performance is targeted but hard real-time guarantees are not provided.

---

## 2.14 Example Use Cases (for verification & demos)

1. **GEMV demo**: 1024×1024 matrix (weights persistent), single input vector streamed, result compared with numpy reference.
2. **1×1 Conv pipeline**: process 128×128 feature map with channel depth 64 via tiling; compare outputs channel-wise.
3. **MLP demo**: 3-layer MLP (dense layers) executed sequentially, host validates final layer output.
4. **Perf stress test**: sustained streaming of random inputs to validate bandwidth & MAC utilization.

Each demo will have an associated test case in the verification plan.

---

# 3 — ARCHITECTURAL SCOPE (NPU PoC)



## 3.1 Top-level architecture (purpose & components)

**Goal:** a single, modular NPU core that is synthesizable to FPGA for PoC, exposes clean host interfaces (AXI-lite regfile + AXI-stream/AXI master data paths), and demonstrates realistic NPU dataflows (weight-stationary GEMV/GEMM, tiling, activation, PSUM accumulation). The PoC must be parameterizable for tile count, lanes, and BRAM sizing.

**Top-level blocks** (logical):

* `NPU_TOP` (top-level wrapper + clock/reset + host bus adapters)
* `Host_Interface` (AXI-Lite regfile, Interrupts, Job Queue).
* `Instruction_Dispatch` / `Microsequencer` (mOP fetch, decode, stall/hazard checks).
* `MVU` (Matrix-Vector Unit) composed of `Tiles` → `DPEs` → `Lanes`.
* `Weight_Buffer` / MRF (persistent on-chip weight storage).
* `IFM_Buffer` (double-buffered input scratchpad).
* `PSUM_Buffer` (partial-sum scratchpad + BRAM accumulators).
* `MFU` (multi-function unit(s): vector elementwise, activation, quantization).
* `Loader` (LD) (writeback / host DMA adaptor).
* `Data_Fetchers` (weight fetcher, IFM fetcher, PSUM fetcher).
* `Sparsity_Unit` (optional PoC block to perform zero-skipping / densification).
* `Perf_Counters` & `Trace_FIFO` (observability hooks).

The Samsung paper’s single-core breakdown and per-engine split (NPUEs, fetchers, tensor units) maps naturally to the blocks above and motivates the modular NPUE concept. 

---

## 3.2 Compute datapath: MVU, Tiles, DPEs, Lanes

### 3.2.1 MVU structure (logical organization)

* **Tile**: synthesis-time parameter. A tile contains multiple DPEs (dot-product engines). Tiles are the primary scaling axis (T).
* **DPE (Dot Product Engine)**: each DPE contains `L` multiplier lanes and a local register file / small accumulator bank. The DPE is the basic compute primitive performing vector × vector dot products over multiple cycles.
* **Lane**: single multiplier-mac slice (INT8 multiplier + optional int32 accumulation path).

Design lessons: use weight-stationary or hybrid weight-stationary/data-reuse mapping to maximize reuse and minimize off-chip bandwidth; this is consistent with the Brainwave-overlay inspired MVU and the Stratix-NX mapping strategies. 

### 3.2.2 Accumulators and BRAM-based scratchpad

* Use BRAM-based small accumulator scratchpad to support interleaved partial sums when operating on batched or tensor-block mapped inputs (this mirrors the BRAM-accumulator design used to handle interleaved accumulation in tensor-block mappings). For PoC, place accumulators after inter-tile reduction to amortize BRAM cost. 
* Widths: accumulator internal width = 32b (INT32) by default, with saturation logic option.

### 3.2.3 Daisy-chain vs centralized reduction

* **Daisy-chain local binary reduction between tiles** is the preferred PoC design for FPGA prototyping: reduces wide global wiring, eases place/route and improves timing at scale (slightly higher latency but simpler routing). Adopt daisy-chain reduction for PoC MVU. 

---

## 3.3 Sparsity support & reconfigurable MAC array (Samsung lessons)

### 3.3.1 Sparsity unit (IFM zero-skipping)

* Implement a `Sparsity_Unit` that detects zero elements in IFM and emits dense-packed tokens (index + value) for MVU consumption. Support both **intra-lane** and **inter-lane** zero-skipping windows as configuration parameters. The Samsung design shows geomean speedups for combined intra+inter skipping; for PoC implement at least intra-lane skipping to demonstrate benefit.  
* Keep sparsity unit optional (disable-able at run-time) because pruning/zero-skipping complicates ISA and verification.

### 3.3.2 Re-configurable MAC array

* Make MVU mapping flexible: allow logical re-partitioning of MAC array along input/output channel dimensions to maximize utilization across layer shapes. Implement the ability to change PE grouping at configuration time (coarse-grained reconfiguration). Samsung shows re-configurable MAC arrays significantly help utilization for mobile workloads; PoC will implement a reduced variant: a small number of pre-defined configurations (e.g., Config A, B, C) selectable at init. 

### 3.3.3 Dynamic memory port assignment

* Implement a small `Dynamic_Port_Assignment` controller that can reassign an extra small scratchpad bank between IFM / WEIGHT / PSUM usage to relieve bandwidth pressure for particular layers (Samsung suggests this helps MobileNet-v2 cases). Implement as a runtime-controlled multiplexer in the memory request arbiter. 

---

## 3.4 Memory subsystem: scratchpads, banks, fetchers

### 3.4.1 Scratchpad layout & banking

* Main on-chip scratchpad (BRAM/URAM) is partitioned into multiple **banks** to minimize bank conflicts. Minimum features:

  * `Weight_Banks` — partitioned per tile or per core to support persistent weights.
  * `IFM_Banks` — double-buffered for prefetching.
  * `PSUM_Banks` — accumulators write to these banks.
  * `Small_Extra_Bank` — dynamically assignable (per Samsung suggestions). 

* Bank sizing: parameterizable; PoC defaults (example) — IFM total 128KB, PSUM 64KB, Weights 256KB (adjust to target FPGA BRAM).

### 3.4.2 Fetchers (data movers)

* **Weight Fetcher**: responsible for streaming weight blocks from `Weight_Buffer` to DPEs; must support burst transfers and access alignment.
* **IFM Fetcher**: loads input tiles into IFM scratchpad; must support densification output when sparsity unit used.
* **PSUM Fetcher / Writer**: orchestrates read-modify-write of PSUM entries in BRAM accumulator scratchpad with atomic add semantics or serialized accumulator adder if necessary (PoC will serialize to avoid complex multi-ported BRAM writes). The Samsung NPU uses multiple dedicated fetchers for IFM/weight/PSUM to avoid contention — emulate this with multiple FSMs and arbitration. 

### 3.4.3 Memory arbitration & QoS

* On-chip memory arbiter must implement priorities (e.g., MVU read > weight prefetch > telemetry tasks) and allow a configurable policy for different layers. For PoC, a deterministic round-robin with priority bypass for MVU when busy is sufficient.

---

## 3.5 Control plane: ISA, microsequencer, scheduling

### 3.5.1 Instruction model (mOP → μOP)

* Use a *VLIW-lite* mOP model (single 64-bit mOP with fields for MVU operands, MFU ops, load/store triggers). This mirrors Brainwave-inspired overlays and Stratix-NX enhanced NPU which added batch fields and tensor control signals. The PoC ISA should include:

  * `LOAD_WEIGHTS`, `START_TILE`, `WAIT_EVENT`, `WRITEBACK`, `NOP/HALT`.
  * MVU microfields to control ping-pong register banks (if targeting tensor-block hardware later) — add control bits for bank selection and accumulation mode to keep future compatibility. 

### 3.5.2 Microsequencer responsibilities

* Translate mOPs into ordered μOP sequences: weight fetch → IFM fetch → MVU issue → inter-tile reduction → PSUM accumulation → MFU → writeback.
* Implement simple hazard checks: weight_ready, ifm_ready, psum_ready; if not satisfied, stall and increment a telemetry stall counter to aid debugging.
* Provide event signals for host (tile_complete, fatal_error, perf_overflow).

### 3.5.3 Scheduler (static vs dynamic)

* PoC will implement primarily **static scheduling** (host assembles sequences). Provide a small job-queue / job-descriptor mechanism in hardware to allow multi-job queuing but avoid complex dynamic out-of-order scheduling. This keeps verification tractable while supporting pipelined host-driven workloads.

---

## 3.6 Interfaces & integration model

### 3.6.1 Host-facing interfaces

* **AXI4-Lite** regfile: for configuration, status, interrupts, counters, job enqueue. Provide full register map (detailed map delivered in later section).
* **AXI4 (burst-capable) master interface**: for DMA reads/writes to host memory (weights/IFM/OFM). Use this for deterministic transfers in PoC.
* **AXI-Stream** optional alternative: allow streaming input for ultra-low-latency scenarios; implement a thin adapter to convert AXI-S to burst descriptors. The RAD / FPGA exploration work shows that matching internal interface widths to external bus widths significantly affects performance — design adapters to support width conversion. 

### 3.6.2 Internal interfaces

* Tile-to-tile dataflows use wide local buses; design these as parameterizable width handshakes (TVALID/TREADY style) to allow modular replacement. For FPGA mapping, align slice widths to fabric-friendly bus widths (e.g., 256–512 bits) to reduce routing congestion. The "bandwidth-friendly" restructuring approach and matching LD write-back widths shows fewer performance losses. 

### 3.6.3 System integration

* On FPGA, connect `NPU_TOP` to host CPU via PCIe or Ethernet (dev-board dependent). The Intel Stratix-NX approach indicates remote Ethernet direct access can drastically reduce system-level overhead for small sequences compared to PCIe host round-trips — keep this in mind for later benchmarking. 

---

## 3.7 Timing, clocking, and floorplan guidance

### 3.7.1 Target clock & timing

* PoC target: 200–300 MHz for FPGA prototyping (depends on device; Stratix NX experiments ran 300 MHz). For general FPGA boards (Xilinx/Intel), aim for conservative 200–250 MHz to ease timing closure. 

### 3.7.2 Clock domains

* Minimal clock domains: `clk_core` (MVU, MFU, BRAM), `clk_host` (AXI4-Lite, DMA control), `clk_debug` (trace capture). Use async FIFOs across domains only where necessary. Keep number of domains small to simplify verification.

### 3.7.3 Floorplanning & placement tips

* Place MVU tiles in spatial groups; localize the tile reduction buses to avoid long global routing. Daisy-chaining tiles reduces long cross-chip nets. If targeting Stratix-like architectures with hard tensor blocks, co-locate logic near tensor blocks for improved routing. 

---

## 3.8 Scalability & extension points (how to grow PoC later)

### 3.8.1 Multi-core / SIMT model

* Design MRFs (Weight Buffer) and instruction dispatch with the option to share weight banks across multiple logical cores (SIMT-style) so later you can add a second core that executes the same program on different inputs (this maps to the "2C-7T-40D-40L" choice in the Stratix paper). 

### 3.8.2 NoC / multi-slice partitioning

* Keep adapters and module wrappers NoC-ready: expose flit-level interfaces or standard AXI wrappers around MVU slices so future mapping to a NoC is straight-forward. The RAD/NoC experiments show a moderate performance reduction when mapped over a NoC, but it enables scale across many routers. 

### 3.8.3 Mixed-precision & tensor blocks

* Include control bits in MVU μOPs for future tensor-block control (ping-pong register bank select, cascade enable) — Stratix-NX enhanced NPU required these low-level control fields. Adding these makes it straightforward to map to hardened tensor blocks later. 

---

## 3.9 Technology & implementation constraints (PoC decisions)

### 3.9.1 Target devices & resource budget

* **Primary PoC target:** mid-range FPGA dev kit (e.g., Intel/Altera or Xilinx with ≥200–400K LUTs, ample BRAM/URAM). Select device early and size BRAM/PE counts to fit. The Stratix work shows resource usage grows rapidly when using tensor blocks; size expectations must be realistic. 

### 3.9.2 Synthesis & toolflow

* RTL in SystemVerilog; run synthesis with vendor tools (Quartus/Vivado). Use parameterized modules and clear compile-time macros to iterate. Maintain small, easy-to-place top configurations to reduce routing/time-to-bitstream during development.

### 3.9.3 Area vs complexity tradeoffs

* Where the Samsung paper shows limited re-configurability yields large area savings with limited perf impact, adopt conservative reconfigurability in PoC: 2–3 run-time modes instead of fully dynamic fine-grained reconfiguration. This lowers area and verification burden. 

---

## 3.10 Observability, verification hooks & debug-friendly design

* Expose per-block handshake/status signals for ILA capture (uOP issue/retire, mem_req/mem_ack, tile_id).
* Provide perf counters and telemetry FIFOs for cycles_busy, mac_issued, stalls_mem, stalls_dep, IFM/weight BW. These were essential in the FPGA evaluations to understand utilization. 
* Add an optional "design for debug" build with extra instrumentation that can be stripped for final timing-optimized builds.

---

## 3.11 Architectural assumptions & design rationales (short list)

* **Assumption — small batch, low-latency focus:** design optimized for small batch sizes (1–6) while still capable for larger batches. This follows the high utilization gains seen on FPGA overlays at small batches. 
* **Assumption — weight-stationary mapping:** optimize for keeping weights on-chip for layers that fit (BRAM-limited), reducing external memory traffic. 
* **Rationale — reconfigurability limited in PoC:** implement coarse reconfigurability to balance utilization vs area/verification cost (Samsung found acceptable tradeoffs). 
* **Rationale — daisy-chain reduction:** to avoid huge interconnect and meet timing on FPGA. 

---

## 3.12 Deliverables linked to architecture (what this section produces for downstream tasks)

1. **Detailed block-level RTL interfaces** (SV module headers, interface signals, handshakes).
2. **Parameter table** (T, D, L, IFM/PSUM sizes, BRAM usage per parameter set).
3. **Register map** for AXI-Lite (control, status, perf) — deliverable in Section 4/5.
4. **Timing budget & floorplan suggestions** for a selected FPGA board.
5. **Integration adapter templates** for AXI-Stream ↔ AXI4 burst conversions, and optional Ethernet/PCIe host adapters.
6. **Verification hooks** (telemetry, trace FIFO, ILA points) in RTL.

---

## 3.13 Risks & architectural mitigations

* **Risk: BRAM or DSP exhaustion** — mitigation: provide parameterized configurations and fallbacks (reduce D or L) and tools to compute resource estimates before synthesis (sizing script).
* **Risk: routing congestion on wide buses** — mitigation: use daisy-chain reduction; compile-time bus width tuning; use local reduction trees. 
* **Risk: memory bank conflicts** — mitigation: dynamic port assignment + small extra bank to relieve bottleneck as Samsung suggests. 
* **Risk: low utilization on certain layers** — mitigation: provide a couple of MAC-array configurations and tile-size knobs to remap shapes.

---

## 3.14 Quick-reference mapping to source research (why each major architectural choice is justified)

* **Sparsity & reconfigurable MAC array** — Samsung NPU: sparsity unit, dynamic port assignment, reconfigurable MAC to increase utilization & energy-efficiency. 
* **BRAM-based accumulators, daisy-chain reduction, batch mapping** — Stratix-NX enhanced NPU paper: BRAM accumulators to handle interleaved partial results; daisy-chained tiles for routing friendliness; batch-3/6 mapping to maximize tensor-block usage. 
* **Interface width / NoC & bandwidth-friendly considerations** — RAD/architecture co-design: matching internal slice widths to external link widths / NoC impacts performance and must be considered. 

---

# 4 — PERFORMANCE SCOPE (Exhaustive, actionable & measurable)

## 4.1 Summary of performance goals (top-level)

* **Primary PoC goal:** demonstrate correct, measurable acceleration of MAC-dominated kernels (GEMV/GEMM / 1×1 conv / small MLP/RNN steps) with repeatable throughput and low-latency behavior on FPGA.
* **Example numeric targets (PoC baseline / conservative):**

  * Sustained effective INT8 throughput: **≥ 10 TOPS** for medium-size workloads that fit on-chip (tunable by design params).
  * Short-sequence RNN latency: **≤ 1.5 ms** for large sequences (e.g., 256 steps) on PoC mapping (Stratix NX measured 1.1 ms for large GRU workload at batch-6). 
  * Energy-efficiency target: **> 5 TOPS/W** (hardware-dependent; advanced designs and tensor-block-enabled FPGA runs show much higher; e.g., Samsung silicon reported **13.6 TOPS/W** in 5nm test chip for their NPU core). 

> Note: the concrete achievable numbers depend on chosen FPGA board, clock target, MVU sizing (T, D, L), and BRAM/DSP/tensor resources. The above are **PoC baseline goals** — you must adapt them to the final parameter set chosen for the target board.

---

## 4.2 Workload assumptions (what we will measure against)

Pick a representative set of workloads that exercise different aspects of the datapath and memory subsystem:

1. **GEMV (matrix-vector)** — primary mapping (weight stationary): varied sizes: 512×512, 1024×1024, 1792×1792. (These are the same categories used in the Stratix study and useful for comparisons). 
2. **Small-GEMM** — square matrices that *fit persistently* on-chip (e.g., up to 3072×3072 when BRAM allows) — measure compute micro-bench. 
3. **RNN/GRU/LSTM time-step kernels** — sequences with small per-step compute (e.g., LSTM-1024-8, GRU-1152-8, long sequences 256) to evaluate latency & pipeline overhead. 
4. **MLP (dense)** — shallow multi-layer perceptron workloads (to test repeated dense mat-vecs).
5. **1×1 convolution mapped as GEMV** — image channel depth variety to exercise tiling & PSUM accumulation.
6. **Synthetic stress tests** — random data streams to saturate IFM/weight bandwidth, to measure stalls and bank conflicts.
7. **Sparsity-sensitive workloads** (optional) — MobileNet, MobileNet-v2, Inception-v3, ResNet-50 when evaluating sparsity unit benefits (Samsung measured geomean speedups and MAC utilization improvements on these). 

Define per-workload parameterization: matrix shape, batch size, sequence length, tile size (M,N,K), and input sparsity ratio.

---

## 4.3 Benchmarks & benchmark suite

Create a benchmark suite with these categories:

* **Core microbenchmarks**

  * GEMM/GEMV kernel latency & throughput (varying N,M,K)
  * Single-tile latency (measure compute-only cycles)
  * Memory fetch latency for weight & IFM transfers

* **Application-level**

  * Inception-v3 inference (as in Samsung paper) — measure FPS. Samsung reported **Inception-v3 = 290.7 FPS** on their silicon baseline; use for broad comparison. 
  * MobileNet / MobileNet-v2 / ResNet-50 — measure FPS and MAC utilization (Samsung shows significant gains with reconfigurable MAC/sparsity). 
  * RNN workloads (GRU/LSTM) with short and long sequences — measure per-step latency and end-to-end throughput (Stratix-NX results provide a useful reference). 

* **System-level**

  * End-to-end host → NPU → host round-trip latency (including DMA overhead) with PCIe and, if available, direct Ethernet path (Stratix experiments show FPGA with 100G Ethernet had significantly lower overheads than GPU PCIe host paths). 

* **Power/Energy**

  * Core active power during sustained kernel; TOPS/W measurement. Stratix NX dev kit measured ~54–70W depending on utilization; Samsung silicon reported 13.6 TOPS/W for their NPU core (5nm) — use these as references, not absolute targets.  

---

## 4.4 Target metrics, detailed

Measure and report the following for each test:

**A. Throughput**

* `Effective TOPS` (effective INT8 TOPS achieved — measure MACs executed / execution time). Use the same effective definition used in the Stratix paper (count only the tensor/MVU TBs used in MVU to compute peak). 
* `Frames-per-second (FPS)` for full inference workloads.

**B. Latency**

* `Tile latency` (cycles from tile start mOP consumed to tile writeback complete).
* `End-to-end latency` (host request arrival → result visible to host). Include breakdown: host DMA latency, weight prefetch time, compute cycles, writeback time, and host transfer time.

**C. Utilization**

* `MAC utilization (%)` — (#active MAC cycles / #peak MAC cycles available) × 100. Samsung and Stratix papers use this to explain achievable vs peak TOPS.  

**D. Memory metrics**

* `IFM BW` (bytes/s) — measured over the test.
* `Weight BW` (bytes/s).
* `PSUM_write BW` (bytes/s) and `PSUM_read BW` if applicable.
* `Bank conflict rate` — fraction of access cycles experiencing bank conflict-induced stalls.

**E. Stalls & idle cycles**

* `stall_mem_cycles`, `stall_dep_cycles`, `uop_stalls`, `issuing_stalls`. Count and present as percent of total cycles.

**F. Energy metrics**

* `Power (W)` measured at board level and, if possible, estimated core power.
* `TOPS/W` = effective TOPS / device power (specify measurement point).

**G. Determinism & variance**

* `Stddev` and `CI` of repeated runs for latency and throughput (run each test N≥20 times).

---

## 4.5 Measurement methodology & instrumentation (how to measure reliably)

### 4.5.1 Instrumentation (hardware & software)

* **On-chip counters**: hardware counters for cycles, MAC_issued, MAC_active, memory_requests, memory_stalls, PSUM_ops. Provide readout via AXI-Lite.
* **Timestamping**: use hardware timestamps in LD/IO paths to capture host-request receive time and output-write completion. This eliminates host clock measurement error. (Stratix authors used hardware timestamps to count cycles and matched to RTL simulation). 
* **Trace FIFO**: event-based trace records for debugging outliers and correlating stalls to events.
* **Power instrumentation**: board shunt or high-resolution power meter for board-level power; if available, instrument rails powering the FPGA core for finer measurement.

### 4.5.2 Test harness & repeatability

* Use a deterministic test harness: fixed PRBS seed inputs (or real-image datasets with fixed batch) and scripts to run each test multiple times.
* Warm-up run: perform a warm-up iteration or a warm-up loop to avoid cold-start effects (cache fills, JIT-like effects).
* For microbenchmarks, disable telemetry writes if they disturb timing — or measure both with and without telemetry to quantify overhead.

### 4.5.3 Measurement cadence

* **Core compute-only**: measure cycles between MVU start and MVU finish (exclude DMA times).
* **Full end-to-end**: measure time from host mOP issue to result writeback completion.
* **System-level**: measure round-trip time including network/PCIe latency, DMA queueing.

### 4.5.4 Calibration & cross-checks

* Cross-validate on-chip cycle measurements with RTL cycle-accurate simulator runs for small inputs — they should match; Stratix work confirmed hardware timestamps matched RTL cycle counts. 

---

## 4.6 Performance modeling — equations & examples

Provide simple, parameterized models to estimate expected cycles and bandwidth.

### 4.6.1 Compute cycles (tile)

Let:

* `M` = number of output rows in tile
* `N` = number of output columns in tile
* `K` = depth of inner product (dot length)
* `MACs_per_cycle` = T × D × L (tiles × DPEs × lanes) — effective parallel MACs per cycle
* `α` = micro-ops per result overhead factor (control/embedding overhead cycles per tile)

Then compute cycles for core compute (idealized):

```
compute_cycles ≈ ceil( (M * N * K) / MACs_per_cycle ) + α
```

If batched processing or interleaved accumulation is used (batch B), multiply M*N by B as appropriate.

### 4.6.2 Memory bandwidth requirement (bytes/s)

For INT8:

* `bytes_per_MAC = 2` bytes (1 byte input + 1 byte weight) ignoring reuse.
* But with weight-stationary and reuse, per-output writeback bytes vary. For persistent weights:

```
IFM_BW_bytes_per_sec ≈ (M*N*K_in_bytes / total_time)
Weight_BW_bytes_per_sec ≈ (K*weight_bytes / total_time) // often lower if weights persistent
PSUM_BW_bytes_per_sec ≈ (M*N*4 / total_time) // 4 bytes per partial sum (int32)
```

Use measured `total_time` to compute effective BW. Compare against available AXI/DRAM/PCIe bandwidth to detect bottleneck.

### 4.6.3 Utilization

```
MAC_utilization (%) = (MAC_active_cycles / total_cycles) * 100
```

Derive `MAC_active_cycles` from on-chip counters (count MAC operations executed / (MACs_per_cycle × total_cycles)). Compare expected vs measured.

---

## 4.7 Resource & bandwidth budgets (example PoC configs)

Below are exemplar budgets you can use as starting points. Final numbers must be recomputed for your exact FPGA.

**Example PoC config (conservative midrange FPGA)**

* `T` = 4 tiles
* `D` = 8 DPEs per tile
* `L` = 16 lanes per DPE
* `MACs_per_cycle` = 4 × 8 × 16 = **512 MACs/cycle**
* Target clock = **200 MHz**

  * Peak MAC throughput = 512 MACs × 200M = **102.4 GMAC/s = 102.4 G*ops/s (int8)** → **~102.4 TOPS** (int8 ops counted as 1 op per multiply-accumulate depending on definition). Realistic sustained will be lower due to stalls.

**BRAM/weight budget (example)**

* Weight buffer: sized to hold one tile of weights for 1024×1024 (approx 1M bytes for INT8 weights) — choose BRAM accordingly.
* IFM buffer: double buffer ~128KB to 256KB depending on tile size.

**AXI bandwidth targets**

* Host-to-NPU: aim for **> 10 GB/s** burst bandwidth (PCIe Gen3×8/16 or board Ethernet depending on dev-board). If AXI bus is the bottleneck, MVU will stall.

> These example numbers are scalable — the Stratix-NX paper shows how changing T/D/L and leveraging tensor blocks leads to different peak TOPS (their largest configuration achieved very high multiplier counts and peak TOPS). Use their approach for design-space exploration. 

---

## 4.8 Measurement & reporting template (what to report for each test)

For every benchmark test, produce a one-page measurement report with:

1. Test name, date, hardware target (board, FPGA model, speed grade), bitstream name.
2. Workload parameters (M,N,K, batch, sequence len).
3. Clock frequency used.
4. Measured:

   * Total runtime (ms) & stddev
   * Compute-only cycles & cycles/unit
   * Effective TOPS & MAC utilization (%) (with formula)
   * IFM / weight / PSUM BW (MB/s)
   * Board power & TOPS/W
   * Trace excerpt showing any notable stalls or events
5. Acceptance checkboxes (functional correctness vs golden model; resource usage; meets latency target; meets throughput target).
6. Notes: anomalies, observations, planned next steps.

---

## 4.9 Acceptance criteria (detailed)

The PoC performance scope is **accepted** when all of the following are true on the selected target FPGA and PoC parameter set:

1. **Functional correctness**: Output matches golden reference (bit-for-bit on quantized workloads or within agreed tolerance) for the benchmark suite.
2. **Sustained throughput**: For at least 3 representative workloads, the ratio (measured_effective_TOPS / baseline_target_TOPS) ≥ 0.8 (i.e., at least 80% of PoC target). Targets are set after final mapping to device resources.
3. **Latency**: For at least one RNN/GRU long-sequence case, measured end-to-end latency ≤ target (e.g., ≤ 1.5 ms for 256-step GRU in PoC baseline). 
4. **Utilization**: MAC utilization ≥ 40% on geomean across workloads; higher when workloads fit persistently on-chip. (Stratix paper reported geomean utilization up to ~37% at batch-6 across workloads and up to 80% on bigger problems). 
5. **Observability**: Perf counters and traces are functional and used to explain at least one bottleneck.
6. **Power & efficiency**: Provide at least one TOPS/W number (for baseline comparison). If TOPS/W is below the conservative expectation (<2 TOPS/W for FPGA dev boards), document causes and mitigation plan. (Comparative references: Stratix dev kit measured ~12–16× higher TOPS/W vs GPUs in their experiments — device-dependent.) 

---

## 4.10 Performance tuning checklist (what to try if targets not met)

If a benchmark underperforms relative to expectation, run this checklist:

1. **Check utilization counters**: Is compute idle due to memory stalls? Check `stall_mem_cycles`.
2. **Tune tile sizes**: smaller/larger tiles can change reuse and bank conflict characteristics.
3. **Adjust double-buffering**: confirm IFM double-buffering is functional and overlapped with compute.
4. **Increase prefetch depth**: prefetch more weight blocks if BW permits.
5. **Rebalance DPE/Lane counts**: ensure D matches L to avoid pipeline bandwidth mismatch (lesson from Stratix NPU). 
6. **Inspect bank conflict rates**: if high, change bank mapping or increase number of banks.
7. **Disable telemetry**: if trace writes significantly affect timing, measure compute-only with telemetry off to determine overhead.
8. **Consider enabling sparsity module**: for sparse workloads, enabling zero-skipping improves effective MAC utilization (Samsung results show up to ~1.6× speedup on some networks). 

---

## 4.11 Performance-related verification & validation plan (brief)

* **Unit-level**: Verify each block’s counters and microbench (e.g., DPE executes expected number of MACs per input sequence).
* **Integration**: Validate end-to-end throughput and latency with golden model; cross-check cycle counts vs RTL/simulator. (Stratix authors matched hardware timestamps to RTL simulation.) 
* **Regression**: Add performance regression tests to CI — e.g., run 3 canonical microbenchmarks nightly to guard against regressions.
* **Stress & corner cases**: bank-contention worst-case inputs, maximum tile sizes, high sparsity mixes.

---

## 4.12 Risks, sensitivities, and mitigations

**Risk — Memory BW is the bottleneck**

* *Mitigation:* Choose weight-stationary tiling, increase on-chip reuse, and/or decrease compute-parallelism to match BW.

**Risk — Low MAC utilization on small or narrow layers**

* *Mitigation:* Provide multiple MAC-array configurations and choose per-layer mapping; apply reconfigurable grouping (Samsung-style). 

**Risk — Routing / timing problems at high bus widths**

* *Mitigation:* Use daisy-chain reductions and local reductions; reduce global bus widths; floorplan critical blocks. This is effective for FPGA prototypes (Stratix MVU used daisy-chain to ease routing). 

**Risk — Measurement noise from host stacks (PCIe/Ethernet)**

* *Mitigation:* Use hardware timestamps; report both core-only and end-to-end; for fair comparisons include system-level overhead measurements. 

---

## 4.13 Deliverables from Performance Scope (what I will provide / you should produce)

1. **Benchmark suite (code + configs)** — scripts to run microbenchmarks and application-level tests and produce standardized reports.
2. **Performance counters & register map** — list of counters (cycles, MACs, stalls, BW) and how to read them via AXI-Lite.
3. **Measurement templates** — Excel/CSV and plot scripts to visualize utilization, latency breakdowns, and bandwidth.
4. **Resource estimator** — simple calculator (spreadsheet or script) to estimate MACs_per_cycle, BRAM needs and theoretical peak TOPS for chosen T/D/L parameters.
5. **Performance verification plan** — test matrix mapping workloads to acceptance criteria and required runs.
6. **First-pass target report** — measure on initial bitstream and document deviations + tuning steps.

---

## 4.14 Example concrete goals tied to PoC parameterization

If you finalize a PoC parameter set (say `T=4, D=8, L=16`, clock = 250 MHz) then I will generate specific numerical predicted targets using the formulas above and the resources; e.g., predicted peak MAC throughput, expected BRAM allocation for a set of tile sizes, and an expected range for sustained TOPS given a few different memory bandwidths. (Tell me the exact target FPGA and PoC parameters and I’ll compute these right away.)

---

## 4.15 References & key datapoints (from your uploaded docs)

* **Stratix 10 NX enhanced NPU:** batch-6 results show up to **32.4 effective int8 TOPS** with **80.3% utilization** on large RNN workloads; detailed per-workload latency and effective TOPS reported in Table II. Hardware timestamps matched RTL cycle counts. 
* **Stratix system-level overheads:** FPGA with 100G Ethernet showed **~10× and 2× less system overhead** than PCIe-connected GPUs for short and long sequences respectively; end-to-end, the NPU on NX averaged an **order-of-magnitude speedup** vs the studied GPUs including system-level overheads. 
* **Samsung sparsity & reconfigurable MAC results:** silicon product (5nm) reported **13.6 TOPS/W** energy efficiency and application FPS numbers (Inception-v3 = **290.70 FPS**, MobileNet = **1052.26 FPS**, MobileNet-v2 = **622.54 FPS**, ResNet-50 = **131.13 FPS**). Re-configurable MAC arrays + zero-skipping deliver geomean speedups and increased MAC utilization across networks. 
* **RAD / co-design lessons:** map modules with NoC-ready adapters and consider placement impact on timing — RAD-sim and placement-aware evaluations affect end-to-end performance predictions and are useful when scaling beyond single-FPGA PoC. 

---

## 4.16 Next practical steps I recommend (immediately actionable)

1. **Decide PoC parameter set** (target FPGA board, T/D/L, clock) — I can calculate predicted peaks & required BRAM/DSP.
2. **Build the benchmark harness** (microbench + application suite) and instrument RTL counters (cycle, MACs, stalls). I can draft the harness code templates.
3. **Implement on-chip counters & hardware timestamps** in the next RTL iteration — these are essential to get reliable cycle-level measurements. (Stratix authors used hardware timestamps to good effect.) 
4. **Run a small validation set** (GEMV 1024×1024; GRU-1024-256) and produce the first measurement report for tuning.

---
