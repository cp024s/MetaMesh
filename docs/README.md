# <p align = center> MetaMesh - NPU Design </p>
######  <p align = center> Technical Architecture & Module Reference </p>

This document describes the architecture, core components, interactions, workflows, and design decisions of the NPU project. It is intentionally technical and direct — focused on how the system is built, why certain choices were made, and how modules interact at cycle- and system-levels so an engineer can pick up the design and reason about implementation, verification, and extension.

---

## Architecture overview (logical & physical view)

At its core the design is a pipelined, VLIW-like NPU overlay optimized for memory-bound deep-learning primitives (matrix-vector, inner-product and vector elementwise ops). The NPU is organized as one or more **Cores**, each core containing a programmable pipeline of five major stages:

<img src="/docs/assets/npu_block_diagram.png" width="700px">

1. **Loader (LD)** — IO, scratchpad DMA and writeback; handles instruction-driven read/write of architecture state.
2. **Matrix-Vector Unit (MVU)** — massively parallel dot-product engines (DPEs) organized into tiles; the MVU performs the heavy inner-product work.
3. **External Vector RF (eVRF)** — small, fast register bank to bypass the MVU for non-MVU ops.
4. **Multi-Function Units (MFUs)** — vector elementwise engines (activations, adds, multiplies, quantize/dequantize).
5. **Control/Decode** — VLIW decode, μOP sequencing, hazard & tag handling.

The pipeline is highly parallel (T tiles × D DPEs × L lanes) and exposes programmable-width channels between blocks. Communication can be tightly coupled (local wires) or decoupled via a packetized NoC when the NPU is mapped into a larger RAD (reconfigurable acceleration device). The design intentionally separates compute from communication — compute modules expose latency-insensitive interfaces (AXI-S/AXI-MM wrappers) so they can be mapped either onto soft FPGA fabric or hardened accelerator islands. 

---

## Core compute datapath — inner-product unit (MAA / adder-tree)

### Rationale and topology

* **Inner-product (adder-tree) engine** is chosen as the basic computation primitive rather than classical per-MAC accumulators. The adder-tree approach shares accumulators and reduces flip-flop / clocking overhead which, in node-scaled designs, improves energy efficiency and area efficiency. This trade (less flexibility for lower power & area) was validated with post-layout comparisons (inner-product engine showing ~40% lower energy in the Samsung study). 

### Micro-structure

* A single **MAA (MAC / MUL array)** contains multiple MUL columns (e.g., 16 columns × 16 rows per column).
* Each MUL column feeds one or two adder-trees and accumulators (dual adder-tree per column) to allow intra-column multi-output accumulation and mitigate straggler lanes under sparse workloads.
* Inputs are broadcast (shared IFM lanes) to columns to reduce input bandwidth. Weight sets are local to multiplier columns (MRFs).
* Accumulators feed a local FIFO / asymmetric FIFO network for width adaptation before leaving the MVU. This is crucial where MVU outputs are wider than downstream lanes (e.g., D → L mismatch). 

### Key controls

* Reconfiguration controls allow:

  * changing adder-tree grouping (merge two 16→32 input adder-trees),
  * switching between INT8 native mode and time-multiplexed INT16 using byte-slicing and repeated accumulation at no extra accumulator count,
  * enabling/disabling sparsity unit (zero-skipping).

---

## Sparsity engine & zero-skipping

### Goal

Exploit feature-map sparsity (e.g., ReLU zeros) to skip ineffectual multiplications with minimal control overhead and good load balance.

### Mechanism

* Two modes: **intra-lane search** (look ahead inside the same lane for next nonzero) and **inter-lane search/steal** (steal a nonzero from neighbor lanes to reduce stragglers).
* A **priority-based search algorithm** resolves conflicts deterministically so hardware arbitration is cheap and predictable. The search window is tunable (intra N × inter M) to trade control complexity vs. throughput benefit. 

### Hardware components

* **Sparsity controller** — generates nonzero bit masks, implements priority search and arbitration.
* **Dense packer** — builds dense input vectors from sparse feature maps so MAAs receive contiguous data.
* **Broadcast logic** — sends the same dense input across MAA lanes, further reducing DRAM / scratchpad bandwidth.
* The sparsity path bypass can be disabled to use full deterministic dense datapath for layers or networks with low sparsity.

### Tradeoffs & dimensioning

* Inter-lane search requires extra multiplexers and MUX trees; window size beyond a small constant (2–4) yields diminishing returns but increases complexity. The design targets a sweet spot (configurable) validated in simulator/silicon experiments. 

---

## Memory subsystem and dynamic porting

### Shared scratchpad model

* Single shared on-chip scratchpad (multi-ported via physical port multiplexing) stores IFMs, weights, PSUMs.
* **Static fetchers** — dedicated fetchers for IFM, weights, PSUM.
* **Dynamic IFM/PSUM fetcher** — can be repurposed at runtime to any data type (input or partial sums) to fill transient bandwidth needs (e.g., depthwise conv where IFM bandwidth dominates). This prevents underutilized ports and avoids stalls. 

### Port assignment & double buffering

* The design uses double-buffered prefetch for weights/partials to hide memory latency and allow the MVU to run continuously.
* PSUMs are time-multiplexed when widths vary (INT8→INT32 accumulation path) so fetchers load PSUMs in smaller chunks over multiple cycles.

### Quantization & mixed precision

* Native INT8 datapath for energy-efficiency. INT16 supported via **time-multiplexing**: decompose 16-bit operands into two 8-bit halves (low/high) and carry out four sub-computations (LL, LH, HL, HH) with partial accumulation into BRAM or scratchpad. Minimal extra logic, leverages same multiplier circuitry. 

---

## MVU tiling/partitioning & dataflow

### Tiling model

* Matrix is split across tiles (T). Each tile holds D DPEs. Each DPE has L lanes. Typical parameters targeted in studies: 7 tiles × 40 DPEs × 40 lanes per tile (config examples in FPGA studies). Tiles can be split further into **slices** (MVU slices) to limit I/O width when mapping to NoC-limited RADs — a key bandwidth-driven re-structuring step. 

### Bandwidth-driven design principles

1. Convert inter-module high bandwidth channels into local intra-module (on-chip) communication where possible.
2. Split highly-parallel modules into smaller slices so each produces narrower I/O across NoC edges.
3. Separate broadcast channels with different consumer widths to avoid padding.
   These re-structurings allowed migration from a wide-bus FPGA-friendly NPU to NoC-friendly RAD mappings with modest overhead and regained most of performance. 

---

## NoC / RAD integration & RAD-Sim-guided co-design

### Why NoC matters

In multi-die or heterogenous RADs, packet-switched NoCs provide the glue between programmable fabric, hardened accelerators and processors. The NPU must expose latency-insensitive interfaces to play nicely with NoC routing, arbitration and limited interface widths. 

### RAD-Sim role

* RAD-Sim is used to model cycle-accurate NoC behavior, packetization, adapter latencies and end-to-end application performance when modules are mapped to RAD instances (FPGA-only, monolithic FPGA+ASIC blocks, 3D stacked). Use RAD-Sim to explore module placement, router assignments, VC mapping and adapter sizing before committing to RTL or physical integration. 

### NoC adapters

* Implemented AXI-S/AXI-MM adapters that packetize transactions into flits, handle VC mapping, injection/ejection FIFOs, and clock-domain crossing. Adapters can be hardened (in ASIC) or soft (in FPGA) — their implementation affects injection latency and overall latency breakdowns which RAD-Sim can quantify. 

---

## Instruction set and control microarchitecture

### VLIW + μOPs

* The NPU uses long VLIW words (mOPs) that encode an instruction per pipeline stage. Each mOP decodes into micro-ops (μOPs) dispatched to corresponding pipeline blocks (MVU, eVRF, MFUs, LD). This lets the compiler schedule independent micro-ops to fill pipeline bubbles.

### Tags, hazards & writeback

* Hardware supports tag-based hazard resolution for temporally-dependent streams; in the LI (latency-insensitive) mapping to NoC, tag updates become point-to-point messages that increase count of sequential messages but preserve correctness. To reduce stalls, the LD block broadcasts or sequences tag updates via dedicated writeback channels that can be parallelized by adding slice-to-slice message passing. 

### Multi-threading model

* MVU slices can interleave multiple independent threads (instruction streams) to hide inter-layer or sequence dependencies. Each thread directs its outputs to different EW slices; this increases throughput at a modest area cost (extra EW slices). Empirically, 2× or 4× threading produced ~38% and ~57% average performance gains in RAD-Sim experiments. 

---

## Accumulators, reductions & routing-friendly MVU

### BRAM-based accumulators

* When mapping to chained tensor blocks (or when batching multiple inputs in register banks), accumulation becomes interleaved — simple per-DPE accumulators are replaced by **BRAM-based scratchpad accumulators** supporting indexed writes & reads so multiple interleaved partials can be accumulated with a single adder — trades area (BRAM) for routing simplicity and lower register count. This was used in the Stratix-10-NX enhanced design. 

### Daisy-chain reduction

* Instead of a global wide bus feeding a central adder tree (routing bottleneck), a **daisy-chain local reduction** passes local reduced results from tile to tile, performing binary reductions locally — reduces routing congestion at the cost of a few cycles of additional latency. Valuable when MVU outputs are ×3 wider (batching) or when device routing resources are constrained. 

---

## System-level tradeoffs and decisions

### Compute granularity

* Coarse-grained hard accelerator blocks (MVU slices) vs. fine-grained soft fabric: hard blocks improve energy and area efficiency for repeated patterns (MVU common in DL), but sacrifice flexibility. The project’s co-design approach positions MVU-like blocks as candidates for hardening while keeping control and less-common functions in fabric. RAD-Sim experiments showed multi-die RADs with MVU hard blocks can achieve substantial improvements vs. pure soft FPGA mapping. 

### Bandwidth sensitivity

* The original FPGA NPU used very wide latency-sensitive buses (e.g., thousands of bits). Mapping those to RADs without re-structuring causes catastrophic performance loss due to NoC interface width limits. The bandwidth-driven re-architecting (slice splitting, localizing broadcast) is the key system decision to preserve throughput across heterogeneous interconnect constraints. 

### Utilization vs. peak TOPS

* Peak TOPS are misleading — real workloads often underutilize tensor units. FPGA-based persistent NPU overlays can achieve much higher effective utilization at small batch sizes compared to GPU tensor cores thanks to persistent weight storage, direct streaming, and low-latency interconnects — the enhanced Stratix10-NX study demonstrates large real-world throughput gains on small-batch low-latency inference. These system-level observations inform decisions about batching, register-bank mapping, and whether to optimize for throughput or latency. 

---

## Verification & performance modeling workflow

1. **High-level SystemC models** — model MVU slices, LD, MFUs and NoC adapters at cycle-level for rapid exploration and functional checking. These are much faster than RTL sims and match RTL timing within low error bounds (~5%!). RAD-Sim uses SystemC wrappers and BookSim integration for NoC modeling. 
2. **RAD-Sim exploration** — test NoC/router topologies, adapter widths, VC counts, placement constraints, and module partitioning across dice to iterate architectures quickly.
3. **RAD-Gen (ASIC flow)** — take hardened block RTL and run synthesis/place/route for area/power/timing estimates (not covered in detail here; part of co-design flow). 
4. **RTL/HW correlation** — validate key SystemC results via cycle-accurate RTL simulation (selected instances) and silicon measurement for final confirmation (Samsung silicon case & Stratix NX implementation evidence).  

---

## Observed empirical results (summary)

* Inner-product engine and reconfigurable MAC array + dynamic porting produced geomean speedups up to ~2× when combined and up to ~2.11× on some networks in the Samsung-style NPU study (using zero-skipping + reconfigurable MACs). Real silicon validated high TOPS/W and FPS numbers at 5nm. 
* Enhanced NPU on Stratix 10 NX (with tightly-integrated tensor blocks and BRAM-accumulators) achieved very high effective throughput and utilization for small-batch inference, reaching multi-10s TOPS effective on realistic workloads (and significantly outperforming T4 / V100 GPUs on small batches in their experiments). This underlines that architecture + system co-design (persistence, routing, batching) matters more than peak TOPS alone. 
* RAD-Sim showed that re-structuring to bandwidth-friendly slices and multi-threading could regain and even exceed baseline FPGA performance when mapping to NoC-constrained RADs, with modest area/memory overhead. 

---

## Interfaces & integration points (practical engineering)

* **Module I/O:** AXI-Streaming wrappers for all module ports; AXI-MM options for memory-mapped control. Adapters perform packetization into NoC flits, VC mapping, clock-domain crossing. 
* **Control:** VLIW/micro-op bus feeding centralized decoder; per-module instruction FIFOs and local issue logic. LD controls DMA and global writebacks.
* **Configuration:** Parameters exposed at compile/run time: tile count T, DPE count per tile D, lane width L, AXI-S interface width, NoC router width, VC counts, sparsity search window sizes, dynamic porting policy. These parameters are the levers used during RAD-Sim exploration and RTL implementation. 

---

## Design guidance & recommended parameter knobs

* Start with a **baseline soft-MVU** implementing inner-product engine with reconfigurable adder-tree; set L ≈ D to reduce I/O mismatch.
* Enable sparsity with a conservative search window (intra = 2, inter = 2) and measure in SystemC before increasing complexity.
* Use RAD-Sim to choose NoC router interface width and mapping of MVU slices — if NoC width < original bus width, split into MVU slices until per-slice output ≤ router width. 
* For silicon/ASIC targets: consider hardening MVU slices (matrix-vector accelerators) and keep MFUs & control in programmable fabric for flexibility. Validate accumulator design (BRAM vs register) based on routing constraints. 

---

## Closing engineering rationale

This NPU design is engineered around the principle that **real-world throughput arises from balanced systems**, not raw peak arithmetic. The architecture focuses on: reducing clocking / register overhead (adder-tree inner-product units), maximizing useful compute via sparsity and reconfigurable datapaths, and exposing latency-insensitive module interfaces so the design can scale into heterogeneous RADs. Cycle-accurate simulation (SystemC + RAD-Sim), combined with targeted RTL/silicon validation, forms the feedback loop for selecting concrete tile/MAA/NoC parameters that meet the application’s latency, throughput, and area/power constraints.   

---