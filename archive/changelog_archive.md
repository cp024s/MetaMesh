# Changelog

All notable changes to this project are documented in this file.  
This project follows **Semantic Versioning** (MAJOR.MINOR.PATCH) wherever applicable.  

---

## [Unreleased]
- Planned enhancements and features for the next release.
- Potential improvements to Compute Engine (dual engine optimizations).
- Additional regression test scenarios and coverage expansion.
- Integration of kernel-level operations and host interface extensions.
- Documentation updates in `/docs/` for architecture and module-level descriptions.

---

## [v1.1.0] - 2025-09-01
### Added
- Dual-engine support: MAC Array and Systolic Array in Compute Engine.
- New Activation Unit functions (ReLU, LUT-based functions, CORDIC).
- Pooling Unit enhancements (max pooling, average pooling support).
- Prefetch and Writeback mechanisms in Memory Subsystem.
- Job Queue and Scheduler improvements in Control Unit.
- Performance counters and trace buffers in Debug Unit.
- Regression test cases for dual-engine operations in `/dv/`.
- Scripts for automated simulation, synthesis, and regression (`/scripts/`).

### Changed
- Refactored Compute Engine interfaces for dual-engine compatibility.
- Updated memory addressing in Address Generators to support larger tiles.
- Restructured `/tb/` for better modularity and reusability of testbenches.
- Updated documentation to include new modules and dual-engine architecture.

### Fixed
- Corrected MAC accumulation overflow handling.
- Fixed scheduler deadlock issue for corner-case job sequences.
- Resolved minor timing mismatch in Activation Unit for LUT-based operations.

---

## [v1.0.1] - 2025-08-26
### Fixed
- DMA burst handling edge-case corrected.
- Regression test inconsistencies resolved for weight tiling.
- Minor bug in AXI-Lite slave interface timing fixed.

### Changed
- Minor documentation updates in `/docs/architecture/`.
- Refined Python scripts for simulation automation.

---

## [v1.0.0] - 2025-08-10
### Added
- Initial release of **NPU_TOP** RTL:
  - Compute Engine with MAC Array
  - Memory Subsystem: Weight and Activation Buffers, DMA Engine
  - Control Unit: Scheduler, Instruction Decoder
  - Host Interface: AXI/APB Slave, Interrupt Controller
  - Debug Unit: JTAG/Scan Chains, basic performance counters
- UVM-based SystemVerilog testbench framework.
- Scripts for simulation, synthesis smoke tests, and regression.
- Preliminary documentation for module-level design and hierarchy.
- Basic verification plan in `/dv/` with initial regression cases.

---

### Notes
- Future releases will include kernel integration, extended verification coverage, advanced performance profiling, and additional architecture enhancements.
- Contributors should reference this changelog for release history and module-level changes.
