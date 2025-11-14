# Top-level integrator (NPU_TOP) — responsibilities & notes

**Functionality & responsibilities**

* Acts as the coordination shell that ties all NPU subsystems to the rest of the SoC.
* Provides the canonical boundary for power, clock, reset, and secure/privileged interactions.
* Exposes control/status space to the host (register map), top-level interrupts, and debug access.
* Supervises safe sequences for bring-up/shutdown (power-gating, reset sequencing), firmware load, and test modes.

**Design & RTL notes**

* Keep only integration logic here (no heavy combinational datapaths). Use it to implement top-level glue, address mapping, and domain isolation.
* Implement clear error containment: top-level should accept and centralize error reports so host can choose to reset only affected islands.
* Provide versioning and capability registers to allow host-side drivers to adapt.
* Implement safe firmware upgrade path (shadow write + commit) to avoid mid-flight inconsistency.

**Verification & observability**

* Add top-level self-check: ensure register bus parity, sanity checks on major counters, and that cluster/PMU states are coherent.
* Provide global snapshot command to freeze key counters and state for host reads.

**Perf/Safety considerations**

* Keep host-visible actions idempotent where possible (e.g., job enqueue), and make abort semantics defined (what happens to in-flight DMA/compute).

---

# Host & System Interface (HOST_IF) — functionality & responsibilities

**What it does**

* The canonical control plane: accepts job descriptors, configuration, and host commands; reports status, exceptions, and perf counters.
* Provides the interface for software/OS/drivers to express inference workloads and query hardware telemetry.

**Key responsibilities**

* **Register map management** — authoritative source of control/status, including soft resets, mode selects, interrupts, and perf/counters.
* **Job descriptor handling** — accepts descriptors or doorbells, validates them, and enqueues into the internal job queue.
* **Interrupt aggregation** — collates and masks interrupts from DMA, compute clusters, and PMU, and delivers prioritized notifications to the host.
* **Security/Access control** — enforces access policies for firmware upload and privileged registers (if required).
* **Debug access** — readback of internal buffers, trace readout, and trigger/control for internal tracing.

**Practical RTL/implementation notes**

* Use shadow/commit semantics for multi-field configuration writes that must apply atomically (e.g., tiling params).
* Implement safe readback/snapshot for 64-bit values on 32-bit buses (two-stage read-snapshot mechanism).
* Validate descriptors on enqueue: basic bounds, alignment, and resource fit (simple checks to avoid runtime faults).
* Provide W1C (write-1-to-clear) semantics for status bits that may race with events.
* Keep read-only counters as snapshot-on-read to avoid slow host loops reading inconsistent values.

**Verification hooks**

* Check descriptor validation paths: invalid pointers, misaligned buffers, overflowed lengths — hardware should return deterministic error codes.
* Exercise interrupt masking/unmasking; ensure no lost or duplicated interrupts on rapid toggle.

**Perf/observability**

* Provide a small set of host-visible perf counters: queue depth, avg job latency, job failure count, and register read/write counts to help debugging driver interactions.

---

# Job Scheduler & Tile Manager (JOB_SCHED) — functionality & responsibilities

**What it does**

* Transforms layer-level or descriptor-level work (host-supplied) into concrete hardware work-units (tiles/stripes) that fit on on-chip memory and map efficiently onto the compute fabric.
* Orchestrates concurrency across clusters and DMA channels while preserving data dependencies.

**Key responsibilities**

* **Graph readiness & dependency tracking** — for multi-layer workloads, mark when nodes are ready to execute (parents done).
* **Tile generation** — partition a layer into tiles based on available on-chip memory, configured tile policies, and the chosen dataflow (weight-stationary, output-stationary, input-stationary).
* **Resource allocation** — reserve DMA channels, local SRAM banks, and compute cluster resources to avoid runtime conflicts.
* **Prefetch policy and overlap strategy** — schedule DMA prefetches to hide memory latency while ensuring bandwidth constraints aren’t exceeded.
* **Backpressure & QoS** — throttle job submission or prefetching when banks or DMA are overloaded; implement priority overrides if needed.

**Practical RTL/implementation notes**

* Make tile parameters tunable — the hardware should not hardcode tile sizes; instead, expose dataflow mode and tile heuristics via config registers.
* Avoid complex arithmetic in combinational logic: divide/ceil operations should be implemented via counters/iterative logic or handled by a small microcontroller (microcode) for practicality in RTL.
* Maintain a lightweight run-time resource map (bank usage table) to track reserved regions and detect potential bank conflicts pre-scheduling.
* Implement simple leakage checks: if a given tile set would cause buffer overflow, provide a deterministic fail/adjust back to host.

**Verification hooks**

* Validate tiling decisions produce correct DRAM addresses and do not exceed allocated buffers.
* Stress test scheduling under extreme resource pressure (many simultaneously queued jobs) to ensure correct backpressure behavior.

**Perf/observability**

* Host-visible per-tile telemetry: tile execution start/stop timestamps, bank conflict rates per tile, and tile-level compute cycles. These allow compiler/device driver to refine tiling heuristics.

---

# DMA Controller & Data Movement Engine (DMA_CTRL) — functionality & responsibilities

**What it does**

* Acts as the data plane bridge between off-chip DRAM and on-chip buffers: fetches weights/activations, performs writebacks, and supports scatter-gather, stride and 2D/3D transfer patterns required by tiled deep-learning kernels.

**Key responsibilities**

* **Address generation** — support nested-loop address patterns (linear, 2D stride, transpose) to carve DRAM transfers matching tiles.
* **High-throughput AXI interactions** — issue aligned bursts, manage outstanding transactions, and merge/coalesce small transfers where beneficial.
* **Channelization** — separate channels for weight fetch, activation fetch, and writeback to maximize concurrency and reduce head-of-line blocking.
* **Backpressure & flow control** — avoid overfilling on-chip FIFOs and coordinate with the scheduler for prefetch limits.
* **Error handling** — detect alignment faults, unexpected AXI response errors, and length mismatches; report recoverable/non-recoverable conditions.

**Practical RTL/implementation notes**

* Use descriptor-based scatter-gather: descriptors hold base, stride, counts — DMA fetches descriptor, iterates nested loops to generate bursts.
* Implement per-channel outstanding limits and separate FIFO depths to tune latency vs resource usage.
* Make burst alignment parameterizable to target the underlying memory system; align bursts to a "line" size chosen to maximize DRAM efficiency.
* Prefer simple FSM-based address generation logic (counters + increments) over large combinational arithmetic to ease timing closure.
* Provide prefetch hints and allow scheduler to set prefetch depth/policy via registers.

**Verification hooks**

* Exhaustively test nested-loop address generation: stride wrap-around, non-power-of-two sizes, odd alignment.
* Stress concurrency: interleave multiple DMA channels competing for AXI; ensure arbitration is fair and no starvation occurs.

**Perf/observability**

* Expose per-channel counters: outstanding bursts, average burst length, time stalled waiting for memory, retry/error counts — critical for tuning dataflow and tile sizes.

---

# On-chip Memory & Bank Controller (ONCHIP_MEM / SRAM_BANK_CTRL) — functionality & responsibilities

**What it does**

* Provides fast local storage for activations, weights, partial sums (accumulators), and metadata; enforces multi-client arbitration and reduces off-chip traffic by maximizing reuse.

**Key responsibilities**

* **Banking & address mapping** — partition physical memory into banks to allow parallel access and minimize contention.
* **Access arbitration** — schedule and prioritize read/write requests from the DMA, compute clusters, and debug accessors to meet QoS needs.
* **Conflict resolution** — detect and handle bank conflicts (queue or remap), and expose conflict counts for optimizer feedback.
* **Protection & ECC** — offer ECC/parity, optionally provide region-based permissions and error-reporting.
* **BIST & diagnostics** — provide built-in self-test for memory arrays and runtime error recovery (e.g., re-fetch on single-bit correctable errors).

**Practical RTL/implementation notes**

* Bank mapping strategy should be aligned with tiling choices: choose bank granularity so typical tile footprints map to multiple banks (reduce conflict).
* Implement read-before-write semantics and write-forwarding where needed to preserve coherency in single-cycle read/write systems.
* Provide almost-full and almost-empty thresholds on per-bank FIFOs to allow upstream DMA throttling before overrun.
* Balance bank count vs area/synthesis complexity. For FPGA PoC, map banks to BRAM/URAM; for ASIC, map to SRAM macros with known latency.

**Verification hooks**

* Create synthetic bank conflict tests: simultaneous accesses to same/different banks and observe arbitration fairness and latency.
* Verify ECC paths using fault injection: single-bit flip corrected, double-bit detected and reported.

**Perf/observability**

* Bank conflict rate, bank busiest/idle ratio, average access latency, and arbitration starvation counters are essential counters to tune scheduling heuristics.

---

# Compute Subsystem (COMPUTE_CLUSTER) — responsibilities & notes

**What it does**

* Implements arithmetic kernels: matrix multiply, convolution inner-loops, elementwise ops, activation functions, and reduction logic using arrays of PEs or vector lanes.

**Key responsibilities**

* **Throughput-oriented compute** — perform MAC operations with deep pipelining for high clock rates and high utilization.
* **Local data reuse** — exploit temporal locality by keeping working sets (weights/activation tiles) as close to PEs as possible in local buffers or RFs.
* **Support a range of primitives** — convolution (im2col or direct), GEMM, depthwise conv, pooling, and fused ops (conv+bn+relu).
* **Reduce & writeback** — aggregate partial sums and commit finalized outputs back to on-chip memory for writeback.

**Practical implementation notes**

* Design PEs to be parameterizable in bit-widths and accumulation width to support mixed precision (INT8->INT32 accumulation, FP16->FP32).
* Pipeline inside PEs: operand fetch → multiply → accumulate → activation/quantization → writeback. Add bypass or forwarding for low-latency paths if needed.
* Organize compute as either systolic arrays (best for dense GEMM/well-structured conv) or SIMD lanes with scatter/gather ability for more irregular computation.
* Prefer local small register files per PE for highest reuse and then larger local buffers shared by a PE tile for weight broadcasts.
* Implement broadcast and neighbor links carefully: avoid long global buses; use local interconnect or streaming links to keep routing and timing manageable.

**Verification hooks**

* Per-PE functional correctness across value ranges, including saturation/overflow paths for quantized arithmetic — exhaustive corner-case tests.
* Ensure fused operations (e.g., conv + bias + clip) precisely match reference model across precisions.

**Perf/observability**

* Track PE utilization, pipeline stalls due to operand starvation, and per-PE error conditions (overflows, rounding anomalies).
* Provide snapshot of reduction network to detect bottlenecks (e.g., reduction tree saturating).

---

# Processing Element (PE) internals — functionality & responsibilities

**What it does**

* Primitive arithmetic building block performing multiply-adds, small activation functions, local quantization, and temporary register buffering.

**Key responsibilities**

* **Arithmetic** — perform MAC with required precision and accumulation semantics, including saturate/clamp.
* **Local buffering** — hold inputs, partial sums, and local parameters like scale/zero-point for quantized ops.
* **Activation & post-processing** — apply ReLU, clamp, or simple approximations to nonlinearities and optionally elementwise adds.
* **Clock gating & power management** — allow PAUSE/IDLE states to reduce power when inactive.

**Practical RTL notes**

* Implement MAC as a pipelined datapath to meet target frequency; the register stages are good places to insert power gating groups or enable bits.
* Keep the quantize/requantize unit close to the accumulator to reduce routing delays.
* Expose a mode bit (or per-PE register) for operational mode: accumulate-only (no activation), activation-only (for fused ops), bypass, or test-mode to ease verification.
* For mixed precision, choose an accumulator width that guarantees no overflow for maximum reduction chain length or provide periodic draining to reduce accumulation depth.

**Verification hooks**

* Unit tests for overflow, underflow, saturate behavior; tests for the correctness of rounding modes (floor/nearest/towards-zero).
* Randomized long-chaining tests to ensure accumulation behaves correctly across many cycles.

---

# Reduction Network & Accumulator Management — responsibilities & notes

**What it does**

* Consolidates partial results across PEs (spatially or temporally) into final outputs; manages accumulation precision and writeback windows.

**Key responsibilities**

* **Tree or systolic reduction** — implement a scalable adder tree or streaming accumulation that trades latency for area.
* **Partial-sum buffering** — store intermediate sums when kernel fan-in/fan-out requires multiple passes over input.
* **Atomicity & merge** — if multiple producers can update same output region, provide atomic add capability or enforce disjoint output mapping.

**Practical RTL notes**

* Pipeline reduction tree levels with registers to meet timing; place wide adders into their own pipeline stages.
* For quantized flows: accumulate in wider integer and only apply requantize at final stage to minimize accuracy loss.
* Avoid multiple writers to same accumulator unless you provide locking or atomic add support — simpler scheduler design avoids the need.

**Verification hooks**

* Validate accumulation across boundary conditions (long chains, mixed-signed inputs) and check post-quantization correctness vs golden model.

**Perf/observability**

* Expose reduction throughput, tree stall counters, and partial-sum writeback latency for scheduler tuning.

---

# Control & Microsequencer (MICROSEQ) — responsibilities & notes

**What it does**

* Converts higher-level scheduling intents into low-level timed control sequences for DMA, compute clusters, and bank controllers — effectively the NPU’s small control processor.

**Key responsibilities**

* **Micro-op dispatch** — read micro-op sequence (from ROM/RAM or host) and produce events for the compute fabric.
* **Loop control & branching** — implement compact microcode constructs to control nested tiled loops (repeat, conditional jump).
* **Event synchronization** — provide wait/notify primitives to coordinate DMA completion and compute start.
* **Error handling & recovery** — execute fallback or recovery microcode in case of runtime errors.

**Practical RTL notes**

* Keep micro-op encoding compact but expressive: include opcodes for load weights, start compute, wait, and branch.
* For PoC, micro-sequencer can be a small FSM; for more flexibility, a tiny RISC-like microcontroller is useful.
* Provide a safe execution mode and secure microcode region if running in secure contexts.

**Verification hooks**

* Unit tests to verify loop counters and conditional jumps behave consistently; verify concurrency between microseq events and actual DMA/compute completions.

**Perf/observability**

* Count cycles attributed to microcode overhead; expose micro-op throughput to decide whether microcode is a bottleneck for complex kernels.

---

# Interconnect / Network-on-Chip (NOC) & Arbitration — responsibilities & notes

**What it does**

* Routes high-bandwidth traffic between DMA, banks, clusters, and host interface while providing QoS, ordering, and flow control.

**Key responsibilities**

* **Routing & switching** — deliver packets/transactions with acceptable latency and ordered semantics per AXI ID when required.
* **VC & VC arbitration** — provide virtual channels to separate control vs data traffic and prevent head-of-line blocking.
* **QoS enforcement** — prioritize critical traffic (PE reads) over low-priority writebacks.
* **Flow control** — credit-based or backpressure mechanisms to avoid buffer overflows.

**Practical RTL notes**

* Keep router logic simple for PoC: a small crossbar with round-robin arbitration often suffices. NoC complexity only necessary when scaling to many clusters/banks.
* Preserve transactional ordering where protocol requires it; otherwise, aggressive reordering can improve throughput.
* Implement deadlock avoidance via virtual channels or escape VC if cycles are possible.

**Verification hooks**

* Stress with pathological traffic to ensure no livelock or starvation and that QoS policies produce expected performance isolation.

**Perf/observability**

* Measure latencies, flit utilization, and packet arbitration fairness to tune VC counts and arbitration weights.

---

# Coherency / Cache Interface & TLB (COHERENCY) — responsibilities & notes

**What it does**

* Optional component: enables NPU to participate in system coherency (snoop protocol) and/or use virtual memory via TLB/SMMU.

**Key responsibilities**

* **Address translation** — translate host virtual addresses to physical before DMA transactions if virtual addresses are provided.
* **Snoop & coherency** — maintain cache coherency semantics when NPU reads/writes data that CPU caches may hold.
* **DMA & TLB exceptions** — provide error reporting for translation faults or snoop failures.

**Practical RTL notes**

* Coherency adds major complexity; for PoC designs, require the host to flush/invalidate caches and provide physical addresses.
* If you must support virtual addresses, integrate with platform SMMU or provide a small TLB and translation walk logic.

**Verification hooks**

* Tests for translation faults, TLB shootdowns, and snoop races (ensuring memory ordering rules are respected).

**Perf/observability**

* Report TLB hit/miss rates, snoop latencies, and additional bus traffic due to coherency — helps decide whether coherency is worth the complexity.

---

# Power Management Unit (PMU) — responsibilities & notes

**What it does**

* Controls power/clock gating across islands, coordinates safe transitions, and exposes thermal/protection signals.

**Key responsibilities**

* **Clock gating & power gating** — allow per-cluster/per-PE gating to save power during idle intervals.
* **DVFS hooks** — accept requests for voltage/frequency changes and coordinate safe ramping with OS/PMU.
* **Thermal & reliability** — monitor thermal sensors and throttle/perf-limit to avoid overheating.
* **Safe sequencing** — ensure ongoing DMA/compute drains and state is saved or flushed before power-down.

**Practical RTL notes**

* Implement handshake for gated power state transitions; avoid abrupt clock stops that break synchronous FIFOs.
* Keep minimal retained state (status/reg bank) in retention domains to speed wake-up if possible.
* Expose explicit `drain` and `resume` control flows to allow software to prepare before gating.

**Verification hooks**

* Simulate gating sequences with in-flight DMA and compute; verify no data corruption or undefined states on resume.

**Perf/observability**

* Counters for time spent in each power state, wake-up latency measurements; these are useful to tune gating granularity.

---

# Debug, Trace & Test (DEBUG/DFT) — responsibilities & notes

**What it does**

* Capture and expose internal events for debug, provide testability hooks for manufacturing, and surface important telemetry.

**Key responsibilities**

* **Trace capture** — record micro-op execution, DMA events, tile IDs, perf counters and short snippets of data for post-mortem debugging.
* **Perf instrumentation** — a comprehensive set of counters for utilization, stalls, bank conflicts, and AXI metrics.
* **Built-in self test (BIST)** — memory tests, scan chains, and built-in error injection for ECC testing.
* **Error handling & logging** — centralize error codes, and provide a consistent fatal vs recoverable classification.

**Practical RTL notes**

* Keep trace bandwidth limited and configurable: full trace should be possible during post-silicon debug but normally disabled due to area and bandwidth cost.
* Implement sampling-mode trace to reduce area/overhead yet give statistically significant signals.
* Provide read-only debug region and read-only/perf-only registers to avoid accidental corruption from host.

**Verification hooks**

* Test trace triggers, overflow handling, and ensure trace readout doesn’t disturb normal operation.
* Inject ECC faults and ensure error propagation, counters increment, and host-visible error codes are correct.

**Perf/observability**

* Provide both real-time counters and historical snapshot buffers. A minimal set: PE utilization, DMA bandwidth achieved, bank conflicts, and stall cycles.

---

# Optional advanced blocks (Sparsity, Mixed-Precision, Compiler Hooks) — responsibilities & notes

**Sparsity accelerator**

* **Functionality**: compress sparse tensors, skip zero-multiply operations, reduce memory footprint and compute cost for sparse models.
* **Notes**: Hardware gains are largest for structured sparsity (block sparsity). Irregular sparsity requires sophisticated indexing support and often results in more memory/logic overhead than benefits unless sparsity is high.

**Mixed-precision units**

* **Functionality**: support multiple operand precisions (INT8/INT16/FP16/FP32) with appropriate accumulation width and requantization.
* **Notes**: Requantization and rounding behavior must be consistent with software frameworks. Provide per-kernel/per-layer scale factors and rounding modes.

**Compiler hooks & profiling**

* **Functionality**: expose hardware performance counters and a simple ABI for the compiler to upload micro-op kernels and profile real runs to adjust tile sizes.
* **Notes**: The best performance usually comes from co-design: compiler uses runtime counters to tune tile sizes and scheduling heuristics.

**Security & isolation**

* **Functionality**: region protection, secure microcode, and firmware signature checks to prevent unauthorized kernel execution or memory access.
* **Notes**: Add minimal security footprint for PoC — e.g., signature check on microcode load or allow secure firmware region.

---

# Pipeline & Concurrency considerations (cross-cutting)

**Pipeline stages**

* Typical flow: DRAM -> DMA -> On-chip buffer -> PE feed -> MAC pipeline -> reduction -> postprocess -> writeback -> DRAM.
* Within PE: register read -> multiply -> add -> activation/quantize -> writeback (4–6 pipeline stages typical).
* Reduction tree and inter-PE streaming needs pipelining to meet timing; stage registers help.

**Concurrency strategies**

* Double-buffering of activations and weights to overlap DMA and compute.
* Multi-cluster parallelism: independent tiles scheduled across clusters.
* Prefetch depth control: avoid prefetch over-commit that floods on-chip memory or AXI bus.

**Hazard management**

* Bank conflicts, FIFO over/underflow, and microseq mis-synchronization are common hazards; detect and surface these via counters/trace.
* Use credit-based flow control and valid-ready handshakes to avoid deadlocks.

**Latency vs throughput**

* Aggressive pipelining increases throughput but increases latency; for inference both matter — provide a low-latency path for small-batch inference when necessary (e.g., bypass deep pipelines).

---

# Memory bandwidth & throttling considerations (cross-cutting)

**Design goals**

* Aim to mask DRAM latency via prefetch overlap and maximize bandwidth via aligned bursts and multiple AXI masters.
* Keep compute utilization high by choosing tile sizes that yield long compute time per DRAM fetch.

**Throttle mechanisms**

* DMA controller should implement backpressure signals into the scheduler and host interface.
* Bank-level almost-full signals should feed back to the scheduler to pause prefetch.

**Observability**

* Provide counters: achieved AXI bandwidth, AXI utilization %, DMA stalled cycles, bank conflict cycles. These are crucial to adapting tile sizes and scheduling.

---

# Register & configuration guidance (cross-cutting)

**Principles**

* Keep control registers minimal, but expose enough to tune dataflow: tile sizes, dataflow mode, prefetch depth, DMA channel configs, cluster enable mask, and perf counter controls.
* Use shadow/commit registers for multi-field changes; make critical control writes idempotent or transactional.
* Keep error/status registers readable and provide clear enumerated error codes.

**Observability**

* Perf counter read snapshot mechanism; counters freeze on read or snapshot register to avoid partial read anomalies.
* Provide simple register API for trace start/stop and trace pointer readback.

---

# Verification & testability guidance (cross-cutting)

**Unit testing**

* Each block: golden reference model (C/Python) and SV testbench for functional correctness across edge cases.

**Integration testing**

* UVM or TB orchestration to mimic host behavior: queue multiple jobs, simulate DMA performance, and verify end-to-end correctness against golden model.

**Performance validation**

* Build a performance model (cycle estimator) to predict throughput from PE counts, memory bandwidth, and tile sizes; use RTL counters to validate and tune.

**Formal & assertions**

* Insert assertions on handshakes (valid-ready), descriptor bounds, and FIFO invariants. Formal verification applied to control plane FSMs, not huge data paths.

---

# Final practical advice (summary for an RTL engineer)

1. **Start small and parameterize** — build a single-cluster PoC with few banks and a modest PE array. Parameterize sizes to scale later.
2. **Design for observability** — perf counters and traces early pay off massively during tuning.
3. **Keep control simple** — complex scheduling logic can be offloaded to software/host while hardware implements efficient primitives (DMA + microseq).
4. **Avoid premature NoC complexity** — start with a crossbar/arbiter and only invest in NoC when multi-cluster scaling proves necessary.
5. **Test for bank conflicts and DMA stalls early** — these are the typical performance bottlenecks.
6. **Document micro-op semantics and register contracts** — hardware/software co-design depends on precise ABI.
