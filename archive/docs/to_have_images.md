## Suggested Images for Your NPU Repo

### 1. **Top-Level Architecture Diagram**

* **What it shows:**

  * NPU\_TOP connecting to Host Interface, Compute Engine, Memory Subsystem, Control Unit, Interfaces, and Debug Unit.
  * Flow of data between these blocks.
* **Why:** Gives a **bird’s-eye view** of the system.
* **Style tip:** Keep it clean, block-and-arrow style with labels.

---

### 2. **Compute Engine Diagram**

* **What it shows:**

  * Dual engines: Systolic Array Engine and MAC Array Engine.
  * Shared Vector/Activation/Pooling/Quantization units.
  * Input/Output buffers.
* **Why:** Visualizes **how computation is organized** inside the NPU.
* **Style tip:** Color-code engines differently to distinguish them.

---

### 3. **Systolic Array PE Array Diagram**

* **What it shows:**

  * 2D grid of PEs with neighbor connections.
  * Dataflow for multiply-accumulate operations (wavefront).
  * Local registers and accumulation.
* **Why:** Explains **data propagation and compute parallelism**.

---

### 4. **MAC Array PE Array Diagram**

* **What it shows:**

  * SIMD-style PE array.
  * Input distribution and output accumulation paths.
  * Local registers for partial sums.
* **Why:** Shows **flexibility for irregular workloads** and how it differs from the systolic array.

---

### 5. **Memory Subsystem Diagram**

* **What it shows:**

  * Weight, Activation, PSUM buffers.
  * AGUs for Systolic and MAC engines.
  * DMA engine, prefetch, and writeback flows.
* **Why:** Helps understand **how data moves efficiently** and how memory bandwidth is managed.

---

### 6. **Control Unit & Scheduling Diagram**

* **What it shows:**

  * Instruction decoding, engine selection, job dispatch, dependency checking.
  * Interaction with compute engines and memory buffers.
* **Why:** Explains **how the NPU decides what to compute and when**.

---

### 7. **Dataflow Diagram**

* **What it shows:**

  * End-to-end flow: job submission → data fetch → compute → post-processing → writeback.
  * Highlight which modules participate at each step.
* **Why:** Makes it clear for anyone reading how **operations actually flow**.

---

### 8. **Debug & Performance Monitoring Overview**

* **What it shows:**

  * Trace buffers, performance counters, JTAG/scan chains.
* **Why:** Demonstrates how verification and performance profiling can be done.

---

### Optional / Nice-to-Have Images

* **Tile-level operation diagram**: How weights and activations are loaded into tiles for compute engines.
* **Pipeline timing diagram**: Shows overlapping execution, DMA prefetch, and compute execution.
* **Parameterization illustration**: Different array sizes, buffer depths, or engine configurations.

---

💡 **Tip:**

* Start with **Top-Level Architecture**, **Compute Engine**, and **Memory Subsystem diagrams**. These are the **most important for understanding your design at a glance**.
* Then add PE-level and control/dataflow diagrams for **technical depth**.
* Keep diagrams **clean, labeled, and color-coded** so even someone new to NPUs can follow.

---
