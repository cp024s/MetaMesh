# <p align = center> MetaMesh - A NPU project </p>


## 1. Overview

This repository implements a **Neural Processing Unit (NPU)** designed to accelerate deep learning workloads at the RTL level. The NPU is conceived as a specialized hardware engine capable of executing complex tensor operations efficiently, targeting operations such as matrix multiplications, convolutions, and other high-dimensional linear algebra tasks commonly used in neural networks.

The design focuses on **hardware-level parallelism** and **dataflow optimization**, enabling multiple operations to be computed concurrently with minimal memory access overhead. It incorporates a modular and hierarchical architecture, allowing clear separation of responsibilities across compute, memory, and control subsystems. The NPU is intended as a flexible platform for experimentation and development of custom accelerators, supporting a wide variety of neural network topologies, from simple fully-connected layers to complex convolutional and recurrent structures.

At its core, the NPU leverages **tile-based computation and local buffering**, allowing data to be reused efficiently and reducing bandwidth pressure on external memory. The architecture is designed to explore different compute paradigms, such as **MAC arrays and systolic arrays**, and to provide a clean framework for implementing and verifying these approaches in RTL.

This project serves both as a **learning platform for RTL-based accelerator design** and as a foundation for building more advanced and high-performance neural processing hardware. It emphasizes **modular design**, **clear dataflow**, and **scalable computation**, making it suitable for experimentation, verification, and future extension.

---
