```
NPU_TOP
├─ Host_Interface
├─ Control_Unit
│  ├─ Instruction_Decoder
│  ├─ Scheduler
│  │  ├─ Engine_Selector
│  │  ├─ Tiling_Manager
│  │  └─ Barrier/Fence_Unit
│  └─ Exception_Manager
│
├─ Memory_Subsystem
│  ├─ Activation_Buffer        (A_Banks)
│  ├─ Weight_Buffer            (W_Banks)
│  ├─ PSUM_Buffer              (P_Banks)  ← optionally partitioned per engine
│  ├─ AGU_Cluster
│  │  ├─ AGU_Systolic          (streaming/wavefront)
│  │  └─ AGU_SIMD              (stripe/gather/scatter)
│  ├─ DMA_Cluster              (AXI masters)
│  └─ Prefetch_Writeback
│
├─ Compute_Cluster
│  ├─ Systolic_Engine
│  │  ├─ Systolic_Array (R×C PEs)
│  │  ├─ North/West_Ingress (aligners/skews/dup)
│  │  ├─ South/East_Collector (drain/align/pack)
│  │  └─ Local_Sched (fill/run/drain)
│  ├─ SIMD_MAC_Engine
│  │  ├─ Vector_MAC_Lanes (L lanes × W width)
│  │  ├─ Reduction_Trees / Local_Accums
│  │  ├─ Eltwise_Units (add/mul/min/max/shift)
│  │  └─ Local_Sched (issue/scoreboard)
│  └─ PostProcessing (shared)
│     ├─ Activation_Unit (ReLU/LUT/CORDIC)
│     ├─ Pooling_Unit
│     └─ Quantization_Unit
│
├─ Interfaces (AXI Master, AXI-Lite/APB, optional ACE/CHI)
└─ Debug_Perf (counters/trace/taps) + DFT
```

---

# 1) Responsibilities per major block

## Control\_Unit

* **Instruction\_Decoder**: Parses job descriptors into op type, tensor dims, datatypes, addresses.
* **Tiling\_Manager**: Generates tiles per engine (block/wave tiles for systolic; stripes/chunks for SIMD).
* **Engine\_Selector**: Maps op → engine via rules/thresholds; supports dual-issue (compute on one, prefetch on the other).
* **Barrier/Fence\_Unit**: Orders shared-buffer reuse, handles deps (e.g., “eltwise uses outputs of conv tile K”).
* **Exception\_Manager**: AXI errors, ECC faults, watchdog; surfaces IRQ/status.

## Memory\_Subsystem

* **A/W/P Buffers**: Banked SRAMs with arbitration and ECC/parity. Optional static split (per engine) or dynamic share with QoS.
* **AGU\_Cluster**:

  * **AGU\_Systolic**: Emits **contiguous, wave-aligned** streams for A/W; optional skew/diagonal schedule.
  * **AGU\_SIMD**: Emits **strided/gather/scatter** patterns, supports masks for tail handling and depthwise/pointwise convs.
* **DMA\_Cluster**: Multi-ID AXI reads/writes, burst combiner, reorder; admission control by QoS.
* **Prefetch/Writeback**: Watermark-driven prefetchers; writeback combiner for partial outputs.

## Compute\_Cluster

* **Systolic\_Engine**:

  * **PE\_Sys**: mult + accumulate + pass-through N/W→E/S; optional zero-skip gating.
  * **Ingress**: North/West edge streamers; **skew networks** to line up K dimension.
  * **Collector**: East/South drains, reduce trees or pass-through to PSUM buffer.
  * **Local\_Sched**: **fill → run → drain** FSM; tile replay on error.
* **SIMD\_MAC\_Engine**:

  * **Vector\_MAC\_Lanes**: L lanes doing dot/AXPY/row/col wise ops; supports INT8/BF16/FP16 variants.
  * **Eltwise\_Units**: add/mul/min/max/shift/abs; mask support; reduction units (sum/max).
  * **Local\_Sched**: scoreboard registers, dependency masks, lane util tracking.
* **PostProcessing** (shared):

  * **Activation** (ReLU, LUT tanh/sigmoid, CORDIC exp/log for softmax).
  * **Pooling** (window reduce with stride).
  * **Quantization** (scale/shift/round/saturate; per-tensor or per-channel).

---

# 2) Engine selection policy (practical rules)

| Op / Condition                                         | Route to     | Notes                                        |
| ------------------------------------------------------ | ------------ | -------------------------------------------- |
| GEMM/MatMul with `M,N,K ≥ T_big`                       | **Systolic** | Peak throughput, deterministic latency       |
| Conv2D (im2col / direct), feature maps “large enough”  | **Systolic** | Tile to R×C blocks; prefer output-stationary |
| Depthwise / Pointwise conv, small K or channelwise ops | **SIMD**     | SIMD lanes excel; better for small kernels   |
| All **eltwise** (bias, add, mul, clamp, norm pieces)   | **SIMD**     | Keep systolic fed with matrix work           |
| Softmax (exp + sum + div)                              | Mixed        | exp/log in PostProc; reductions often SIMD   |
| Small GEMMs (e.g., attention heads with small M,N)     | **SIMD**     | Avoid systolic fill/drain overhead           |
| Sparse/irregular patterns (unless prepacked dense)     | **SIMD**     | Or add a future Sparsity\_Unit               |

*Start with static thresholds, e.g., `T_big ≈ 32`–`64` depending on array size; refine using perf counters.*

---

# 3) Tiling & mapping (how data moves)

## 3.1 Systolic (GEMM C\[M×N]+=A\[M×K]×B\[K×N])

* **Tile shape**: choose `M_t ≤ R`, `N_t ≤ C`, `K_t` sized to buffer BW.
* **Flow**:

  1. **Fill**: Stream A rows north→south and B cols west→east with **diagonal skew** so `k` aligns per PE.
  2. **Run**: Wavefront computes psums; output-stationary or weight-stationary depending on reuse.
  3. **Drain**: Collect edges to PSUM buffer → PostProc or writeback.
* **Double buffering**: A/B tiles double-buffered; overlap DMA with compute.

## 3.2 SIMD (Conv/eltwise/reduction)

* **Conv**: Use stripes or tiles that match lane width; support im2col (optional) or direct sliding window with **line buffers** in Activation\_Buffer.
* **Eltwise**: Broadcast patterns (e.g., bias per-channel); mask tails for non-multiple lengths.
* **Reductions**: Tree reductions across lanes; accumulate in local or PSUM buffer.

---

# 4) Memory & bandwidth planning

* **Required BW (rough)**

  * GEMM: `BW ≈ (M_t*K_t + K_t*N_t + M_t*N_t)/T * data_width` per tile over compute time `T`.
  * Systolic **reduces external BW** via on-array reuse; prioritize **on-chip A/W reuse** with tiles sized to A/W buffer banks.
* **Banks & widths**

  * Pick bank count so `per-cycle words ≥ ingress demand` (e.g., R rows of A and C cols of B per step).
  * Typical: A\_Banks ≥ R, W\_Banks ≥ C, with interleavers.
* **QoS**

  * Two engines contend: give **systolic reads priority**, throttle SIMD to keep array full.
  * Writebacks can be lower priority; coalesce bursts.

---

# 5) Arbitration & sharing strategies

* **Static partition** (simple): assign A/W/PSUM banks to each engine (e.g., 60/40).
* **Dynamic share + quotas** (better): global arbiters with **credit buckets**; scheduler programs quotas per job.
* **Time-slicing**: phase engines—e.g., systolic compute while SIMD prefetches; swap on fence.

---

# 6) Pipeline & timing (at a glance)

* **Systolic\_Engine**

  * Pipeline: ingress align → PE mult → PE add/acc → neighbor pass → edge collect.
  * Latency ≈ **fill (R+C+K\_t)** + steady state + **drain**; deterministic per tile.
* **SIMD\_MAC\_Engine**

  * Pipeline: fetch → align → vector op → reduce/acc → optional postproc.
  * Issue width = lanes × elements\_per\_lane; hides memory with prefetch FIFOs.

---

# 7) Post-processing integration

* Shared unit with **two input ports** (or a crossbar) to accept results from either engine.
* **Backpressure** support: engines stall gracefully when PostProc busy.
* Optional small local pre-post blocks (e.g., bias add) to ease pressure.

---

# 8) Debug, perf & bring-up hooks (must-have)

* **Per-engine counters**: utilization %, stall causes (A underflow, W underflow, PostProc backpressure), tile time, fill/drain time.
* **Memory counters**: DMA BW, bank conflicts, arbitration stalls.
* **Trace taps**:

  * Systolic: border streams, select PE row/col taps (muxable).
  * SIMD: lane inputs/outputs at selectable intervals.
* **Replay**: tile-level re-execute on error; CRC over tile outputs (optional).
* **Watchdogs**: engine deadlock detectors.

---

# 9) Power/clock/DFT

* **Islands**: `compute_clk` island for engines; independent `sys_clk` for host/mem.
* **Gating**: per-quadrant gating for systolic rows/cols; per-cluster gating for SIMD lanes.
* **Retention**: small regfiles optional; SRAMs need MBIST.
* **DFT**: scan through engines, **MBIST** for all SRAM banks; at least parity, ideally ECC on large buffers.

---

# 10) Parameter sheet (single source of truth)

* Array: `R, C` (systolic dims), `LANES, VECW` (SIMD lanes/width).
* Precisions: `ACT_W, WGT_W, PSUM_W, OUT_W` (e.g., INT8/BF16/FP16).
* Buffers: `A_BANKS, W_BANKS, P_BANKS, BANK_WIDTH, BANK_DEPTH`.
* DMA: `AXI_DATA_W, OUTSTANDING, MAX_BURST`.
* Scheduler: thresholds `T_big_M, T_big_N, T_big_K`, quotas, QoS weights.
* PostProc: LUT depth, CORDIC iterations, quant scales mode (per-tensor/per-channel).

Keep them in YAML/JSON to autogenerate RTL params + DV configs.

---

# 11) Execution examples (how it runs)

### Example A: Big Conv2D (mapped to GEMM)

1. **Prefetch** A/B tiles to A/W buffers (systolic priority).
2. **Systolic** fill→run→drain tile 0; in parallel, **SIMD** prefetches bias.
3. **PostProc**: activation + quant on tile 0 outputs.
4. Repeat tiles; when systolic finishes layer, **SIMD** runs residual add + layernorm.

### Example B: Transformer MHA

* **QKᵀ** (big GEMM) → **Systolic**.
* **Softmax**: exp/log in PostProc, **SIMD** reductions/divisions.
* **V×softmaxᵀ** → **Systolic**.
* **Eltwise** (residual, MLP activations) → **SIMD**.

---

# 12) Risks & mitigations

| Risk                | Impact              | Mitigation                                                     |
| ------------------- | ------------------- | -------------------------------------------------------------- |
| Systolic underfed   | Lost throughput     | Prioritize A/W reads, enlarge prefetch FIFOs, raise quotas     |
| PostProc bottleneck | Backpressure stalls | Add buffering at egress; fast modes for ReLU/quant             |
| Memory thrash       | BW collapse         | Align tiles to bursts; group writebacks; time-slice engines    |
| Verification scope  | Long bring-up       | Unit-test engines; golden GEMM reference; mixed-pipeline tests |
| Area creep          | Power/area budgets  | Share PostProc; right-size PSUM; parameterize and prune        |

---

# 13) Minimal implementation roadmap

1. **SIMD\_MAC\_Engine** + PostProc + Memory (single engine path).
2. Add **Systolic\_Engine** with A/W streaming + collector.
3. Implement **Engine\_Selector** (static rules) + **Barrier/Fence**.
4. Add **QoS** in DMA/arb; enable overlapped prefetch.
5. Tune **tiling thresholds** using perf counters; add advanced tilers (conv direct vs im2col).
6. Optional: sparsity/zero-skip in systolic PEs; per-channel quant.
