# NPU RTL Architecture — Engineer’s Handbook

## 1) Dataflow & Numerics (design knobs)

| Knob         | Options (typical)                                                    | Impact                                                              |
| ------------ | -------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Dataflow     | **Weight-stationary**, **Output-stationary**, **Row/NoC-stationary** | Changes PE buffering & address generators; throughput vs SRAM usage |
| Precision    | INT8/INT4, FP16/BF16, mix-precision (e.g., INT8 MAC + FP accum)      | Multiplier width, accumulator depth, saturation rules               |
| Array shape  | `M x N` systolic (e.g., 64×64)                                       | Area ∝ M×N; bandwidth must feed M and N each cycle                  |
| On-chip SRAM | Weight/Activation banks, line buffers                                | Bank count/width determines conflicts & DMA burst sizes             |
| Coherency    | Non-coherent AXI vs CHI/ACE coherent                                 | Simpler DMA vs easier SW integration / cache sharing                |
| Clocking     | Single vs multi-domain (Compute, DMA, CSR)                           | CDC FIFOs/syncs; closing timing per island                          |
| Reliability  | Parity/ECC on SRAM/FIFOs                                             | Area/power vs field robustness                                      |

---

## 2) Top-Level Hierarchy

### 2.1 NPU Subsystem (SoC-integrated)

| Module             | Purpose                | Key Interfaces                                          | Clk/Rst               | Params                                          |
| ------------------ | ---------------------- | ------------------------------------------------------- | --------------------- | ----------------------------------------------- |
| `NPU_TOP`          | SoC IP wrapper         | AXI-M (DRAM), AXI-Lite/APB (CSR), IRQ, optional CHI/ACE | `clk_sys`, `rstn_sys` | `P_DTYPE`, `P_M`, `P_N`, `P_BW_SRAM`, `P_BANKS` |
| `Host_Interface`   | CSR, job push/pull     | AXI-Lite/APB slave, IRQ to GIC                          | CSR clk               | `P_NUM_Q`                                       |
| `Control_Unit`     | Schedules layers/tiles | internal buses to DMAs/arrays                           | sys clk               | `P_MICROCODE` (1=ISA)                           |
| `Compute_Engine`   | Math core              | to Buffers/AGUs                                         | compute clk           | `P_M,P_N,P_DTYPE`                               |
| `Memory_Subsystem` | Local SRAM + DMAs      | AXI-M, to Compute\_Engine                               | sys/compute clk       | `P_BANKS,P_BANK_WIDTH`                          |
| `Debug_Perf`       | Trace/counters         | CSR, optional trace port                                | sys clk               | —                                               |

---

## 3) Compute\_Engine Breakdown

| Submodule         | Purpose           | Internals                                                | Key Signals                                              |
| ----------------- | ----------------- | -------------------------------------------------------- | -------------------------------------------------------- |
| `MAC_Array`       | GEMM/Conv core    | `M×N` **PEs** in systolic mesh; optional diagonal bypass | `in_act`, `in_wt`, `psum_in/out`, `valid/ready`, `stall` |
| `Vector_Unit`     | Elementwise ops   | SIMD lanes (add/mul/clip), broadcast path                | `vec_in`, `vec_out`, `op_sel`                            |
| `Activation_Unit` | ReLU/tanh/sigmoid | LUT (piecewise linear) or CORDIC                         | `act_in`, `act_out`, `mode`                              |
| `Pooling_Unit`    | Max/Avg pooling   | window reducer + stride controller                       | `pool_in`, `pool_out`, `win_sz`, `stride`                |
| `Quant_Dequant`   | Scale & clamp     | shifters, multipliers, saturators                        | `q_in`, `q_out`, `scale`, `zp`                           |
| `PostProc_Pack`   | Layout convert    | transpose/packers, channel interleave                    | `pp_in`, `pp_out`, `fmt_sel`                             |

**PE (leaf) micro-architecture (per lane):**

| Block       | Detail                                                   |
| ----------- | -------------------------------------------------------- |
| Multiplier  | Booth/Wallace or DSP macro (`P_DTYPE`-wide)              |
| Accumulator | Wider than product (e.g., INT8→INT32), with **saturate** |
| Registers   | Input/weight regs for dataflow; pipeline regs per stage  |
| Control     | `valid/ready`, bubble/stall, zero-skip (optional)        |

Typical pipeline: **Load → Multiply → Accumulate → (Optionally) Activate → Quantize**.

---

## 4) Memory\_Subsystem

| Submodule                 | Purpose                            | Notes                                                          |
| ------------------------- | ---------------------------------- | -------------------------------------------------------------- |
| `Weight_Buffer`           | Banked SRAM for stationary weights | `P_BANKS_W`, power-of-two banks; dual-port or time-multiplexed |
| `Activation_Buffer`       | Tiles/line buffers                 | stride/dilation aware; double-buffer for overlap with compute  |
| `PSUM_Buffer`             | Partial sums                       | sized for output-stationary; ECC optional                      |
| `DMA_Read/Write`          | Burst in/out of DRAM               | AXI-M: INCR bursts; 64–512-bit data bus; QoS/ID cfg            |
| `AddrGen_Act/Weight/PSUM` | AGUs per dataflow                  | generates `addr, beat_cnt, stride, wrap`                       |
| `Prefetch/Writeback`      | Hide DRAM latency                  | Watermark-based start; back-pressure compute                   |
| `Format_Adapter`          | NCHW↔NHWC, tiling pack             | aligns to array width and bank width                           |

**Banking rule of thumb:** `bank_count ≥ max(read_ports)` and `bank_width × banks × fclk ≥ required_bw`.

---

## 5) Control\_Unit

| Submodule                | Purpose                     | Style                           |
| ------------------------ | --------------------------- | ------------------------------- |
| `Job_Queue`              | Queue layer/tiles           | SW pushes descriptors; HW pulls |
| `Scheduler`              | Issue plan for compute+DMA  | DAG of ops; hazard/stall mgmt   |
| `Microcode_Engine` (opt) | Small ISA for layer kernels | 16–32b micro-ops, jumps, wait   |
| `Exceptions`             | Faults/timeout              | AXI errors, ECC, watchdog       |
| `Sync_Fences`            | Multi-tile ordering         | Semaphores/events to host       |

---

## 6) Interfaces

| Interface          | Signals               | Notes                            |
| ------------------ | --------------------- | -------------------------------- |
| AXI-Lite/APB (CSR) | `aw/ar/w/r/b`         | 32-bit regs; side-effect safe    |
| AXI-M (DRAM)       | `aw/ar/w/r/b`, IDs    | Burst 16–256 beats; align to 64B |
| Coherent (opt)     | CHI/ACE               | Cacheable weights/acts           |
| IRQ                | `irq_done`, `irq_err` | Maskable; W1C status             |
| Trace (opt)        | `tdata,tvalid`        | Non-intrusive perf dump          |

---

## 7) Leaf RTL Blocks (reusable across the design)

| Leaf                | What it is              | Notes                     |
| ------------------- | ----------------------- | ------------------------- |
| `fifo_sync/async`   | Skid & CDC FIFOs        | async for clk islands     |
| `axi_{m,slv}`       | AXI master/slave shells | Prefer proven IP          |
| `csr_bank`          | Param CSR w/ W1C/W1S    | Autogen from YAML         |
| `mul_add_*`         | DSP primitives          | Map to vendor macros      |
| `lut_pwl`           | Activation LUT          | Piecewise linear tables   |
| `saturator`         | Clamp w/ rounding modes | ties to quant unit        |
| `addr_gen_nd`       | n-D strided AGU         | conv2d, im2col modes      |
| `xbar_arb`          | Bank/crossbar arbiter   | RR or QoS weighted        |
| `clk_gate/pwr_gate` | Low-power cells         | inst per sub-cluster      |
| `ecc/parity`        | SRAM/FIFO protection    | SECDED on large blocks    |
| `cdc_sync`          | 2-FF/gray code sync     | for ctrl pulses, counters |

---

## 8) Reuse vs Custom (IP choices)

| Function            | Prefer IP?     | Typical Source           | Custom Notes                |
| ------------------- | -------------- | ------------------------ | --------------------------- |
| AXI-Lite/APB slaves | Yes            | Vendor/open (e.g., PULP) | Only customize CSR map      |
| AXI Master DMA      | Yes (base)     | Vendor DMA core          | Add NPU-specific AGUs & QoS |
| RISC-V µ-ctrl       | Yes            | Open cores/licensed      | Tight coupling to scheduler |
| SRAM macros         | Yes            | Foundry macro            | Size/banks from floorplan   |
| DSP/FP mul          | Yes            | Library macro            | Pipeline to target Fmax     |
| CHI/ACE coherent    | Yes            | Licensed                 | Complexity is high          |
| MAC array, PE       | **No**         | —                        | Core NPU differentiation    |
| Activation/Pooling  | Usually custom | —                        | Tuned to dataflow/precision |
| Quant/Dequant       | Custom         | —                        | Model-matched rounding      |
| Tiling/AddrGen      | Custom         | —                        | App-specific throughput     |

---

## 9) Control & Status Registers (example map)

| Addr (offset) |        Name |                             Bits | Reset | Description              |
| ------------- | ----------: | -------------------------------: | ----: | ------------------------ |
| 0x000         |      `CTRL` | `[0]start [1]soft_rst [4:2]mode` |     0 | Kick job, mode select    |
| 0x004         |    `STATUS` |         `[0]busy [1]done [2]err` |     0 | W1C for `done/err`       |
| 0x008         |    `IRQ_EN` |                 `[0]done [1]err` |     0 | Interrupt enables        |
| 0x00C         | `DESC_BASE` |                         `[31:0]` |     0 | DMA descriptor ring base |
| 0x010         | `DESC_HEAD` |                         `[15:0]` |     0 | SW head pointer          |
| 0x014         | `DESC_TAIL` |                         `[15:0]` |     0 | HW tail pointer          |
| 0x020         | `CFG_ARRAY` |                 `[15:8]M [7:0]N` | synth | Read-only array dims     |
| 0x024         |  `CFG_PREC` |          `[3:0]dtype [7:4]acc_w` | synth | INT4/8/16/FP16/BF16      |
| 0x030         |  `PERF_CYC` |                         `[31:0]` |     0 | Cycle counter snapshot   |
| 0x034         | `PERF_UTIL` |                         `[31:0]` |     0 | MAC utilization ×1e-3    |
| 0x038         |  `ERR_CODE` |                          `[7:0]` |     0 | AXI/ECC/watchdog code    |

*(Extend with per-layer window/stride regs if you support single-layer immediate mode without descriptors.)*

---

## 10) DMA Descriptor (ring) — example

| Field          | Bits | Description                      |
| -------------- | ---: | -------------------------------- |
| `op_type`      |    4 | 0=conv2d,1=gemm,2=eltwise,…      |
| `act_src_addr` |   64 | DRAM src base (aligned)          |
| `wt_src_addr`  |   64 | DRAM weights base                |
| `out_dst_addr` |   64 | DRAM dest base                   |
| `shape0`       |   32 | N,H,W,C packed or M,K,N for GEMM |
| `shape1`       |   32 | K, kernel, stride, pad packed    |
| `tile_cfg`     |   32 | tile\_h, tile\_w, tile\_c        |
| `quant_cfg`    |   32 | scale, zp, mode                  |
| `flags`        |   16 | chain, irq\_en, fence, last      |
| `reserved`     |   16 | —                                |

Descriptor processing FSM: **Fetch → Validate → Prefetch → Issue compute → Writeback → Post**.

---

## 11) Throughput & Bandwidth (sanity checks)

* Peak MACs/cycle = `M × N`.
* Peak TOPS = `M×N×fclk / 10^12` (for INT8 multiply-accumulate counts as 2 ops if you count mul+add).
* Required input BW (acts + weights) ≈
  `BW ≥ (act_reuse? reduce : ) (M×dtype_bits + N×dtype_bits) × fclk`, tuned by dataflow and tiling.
* Sustain rule: **keep array ≥85% utilized** by sizing **banks, DMA bursts, and double-buffering**.

---

## 12) Verification Plan (SV/UVM)

### 12.1 Testbench Topology

| Component      |        Instances | Role                                |
| -------------- | ---------------: | ----------------------------------- |
| `uvm_env`      |                1 | Container                           |
| AXI-Lite Agent |       1 (active) | CSR R/W, negative tests             |
| AXI Master VIP | 1 (passive/resp) | DRAM model (BFMs + mem)             |
| IRQ Agent      |      1 (passive) | Sample/score IRQ timing             |
| Scoreboard     |                1 | Compares RTL vs golden              |
| Coverage       |                1 | Func + cross + toggles              |
| DPI-C Bridge   |                1 | Python/C golden model (NumPy/Torch) |

### 12.2 Stimulus & Sequences

* **Smoke**: CSR access, soft reset, single tile GEMM.
* **Convolution suite**: various `K, stride, pad, dilation`, odd sizes, depthwise/separable (if supported).
* **Precision suite**: INT4/8, FP16/BF16, mixed-accum, saturation/rounding edges.
* **DMA stress**: misaligned base, burst crossing 4KB, back-pressure, interleaved reads/writes, AXI error injection.
* **Banking conflicts**: crafted strides to force collisions; verify arbiter fairness & no deadlock.
* **Power/clock**: clock-gating enable/disable mid-flight; retention tests.
* **Exceptions**: invalid descriptor, watchdog timeout, ECC single/double error.
* **Performance**: utilization ≥ spec across canonical nets (conv/gemm/eltwise).

### 12.3 Checkers & Assertions (examples)

* AXI protocol SVA (ready/valid, last, burst length).
* **No-loss**: FIFO overflow/underflow never asserted.
* **Forward progress**: if `start` then eventually `done` unless `err`.
* **CSR semantics**: W1C flags clear within 1 cycle of write.
* **PE math**: saturator never wraps; rounding modes honored.
* **CDC**: gray counters monotonic; no metastability exposure.

### 12.4 Coverage (high level)

* Dataflow × precision × kernel shapes × stride/pad × tile sizes.
* Every bank used as hot/cold path; arb wins per master.
* All exception codes; all IRQ paths.

---

## 13) Synthesis/Timing/Power/DFT Checklist

| Area        | Items                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------ |
| Timing      | Pipeline multipliers; isolate long add trees; constrain multi-cycle paths explicitly       |
| Clocks      | Gated clocks per sub-cluster; CDC FIFOs with false-path on async crossings                 |
| Resets      | Async assert / sync de-assert; per-domain resets                                           |
| Power       | Operand isolation; gated register enables; power domains for SRAM islands                  |
| DFT         | Scan insertion boundaries; MBIST for SRAMs; LBIST optional; test bypass on arrays          |
| Floorplan   | Place arrays centrally; bring SRAMs adjacent by bank; short routes for high-fanout control |
| Reliability | ECC/Parity enable options; error logging CSRs; watchdog                                    |

---

## 14) Reference RTL File/Dir Structure

```
npu/
├─ rtl/
│  ├─ top/                 # NPU_TOP, wrappers
│  ├─ control/             # scheduler, jobq, microcode
│  ├─ compute/
│  │  ├─ array/            # MAC_Array, PE.v
│  │  ├─ vector/
│  │  ├─ activation/
│  │  ├─ pooling/
│  │  └─ quant/
│  ├─ memsys/
│  │  ├─ sram_if/          # bank wrappers, ECC
│  │  ├─ dma/              # AXI masters, burst gen
│  │  ├─ agu/              # addr generators
│  │  └─ format/           # pack/unpack, transpose
│  ├─ interconnect/        # xbar, arbiters
│  ├─ if/                  # AXI/APB shells, IRQ
│  ├─ debug/               # perf, trace
│  └─ common/              # fifo, cdc, clk_gate, csr_bank
├─ ip/                     # licensed or hardened IP wrappers
├─ tb/
│  ├─ env/                 # UVM env, agents
│  ├─ seq/                 # sequences
│  ├─ sb/                  # scoreboards, models
│  ├─ cov/                 # covergroups
│  └─ top/                 # tb_top.sv, mem models
├─ dv_model/               # C++/Python golden, DPI glue
├─ sim/                    # Makefiles, run scripts
├─ syn/                    # constraints.sdc, scripts
├─ pd/                     # floorplan notes, tcl
├─ docs/                   # specs, CSR yaml → auto-gen
└─ cfg/                    # parameter sets (json/yaml)
```

---

## 15) Parameter Set (one place to drive elaboration)

| Param             | Meaning                                  | Typical       |
| ----------------- | ---------------------------------------- | ------------- |
| `P_M, P_N`        | Array dims                               | 32–256        |
| `P_DTYPE`         | 0\:INT4,1\:INT8,2\:INT16,3\:FP16,4\:BF16 | 1 or 3        |
| `P_ACC_W`         | Accumulator width                        | 24–48 bits    |
| `P_BANKS_W/A/P`   | Banks (W/A/PSUM)                         | 8–32          |
| `P_BANK_WIDTH`    | Bits per bank per cycle                  | 64–256        |
| `P_AXI_DATA_W`    | AXI bus width                            | 256–512       |
| `P_DESC_DEPTH`    | Descriptor ring entries                  | 64–1024       |
| `P_HAS_COHERENCY` | 0/1                                      | SoC-dependent |

---

## 16) Common Pitfalls & Remedies

| Pitfall                 | Symptom             | Fix                                                                 |
| ----------------------- | ------------------- | ------------------------------------------------------------------- |
| Bank conflicts          | Utilization <60%    | Re-stripe channels; add xbar/secondary ports; pad strides           |
| Under-pipelined mul-add | Fmax wall           | Add pipeline regs; retime; DSP hard macros                          |
| DMA bubbles             | Array starves       | Deeper prefetch; dual rings; QoS/IDs; larger bursts                 |
| Quant mismatch          | LSB errors vs model | Align rounding (ties-to-even), clamp exactly, export scales from SW |
| IRQ lost                | Sporadic hangs      | Level-sensitive IRQ; W1C with read-back; deglitch                   |
| CDC issues              | Rare sim mismatches | Formal CDC; gray code; two-FF sync; async FIFO                      |

---

## 17) Tiny Scheduling Pseudocode (micro-engine idea)

```
for tile in tiler(layer_cfg):
  dma.prefetch(weights[tile], acts[tile])
  wait dma.ready(weights) && dma.ready(acts)
  compute.load(tile)
  compute.run(tile)         // array busy; psum buffered
  dma.writeback(outputs[tile])
  if tile.flags & FENCE: wait all_done
irq.raise(DONE)
```
