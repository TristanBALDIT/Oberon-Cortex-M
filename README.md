# Oberon-Cortex-M

[![Target](https://img.shields.io/badge/Target-ARM%20Cortex--M-orange.svg)](https://developer.arm.com/architectures/cpu-architecture/m-profile)
[![Language](https://img.shields.io/badge/Language-Oberon--07-green.svg)](https://www.projectoberon.com/)

A lightweight, bare-metal **Oberon compiler** currently targeting the **ARM Cortex-M33** core (with possible future support planned for the broader Cortex-M family including Cortex-M0, M0+, M3, M4, and M7).

> **Note:** The compiler toolchain and custom linker have currently been tested exclusively in a cross-compilation environment (building on a host machine for Cortex-M33 execution). Embedded versions of librairies modules used by the the compiler and linker are not yet developped.

Based on Niklaus Wirth's original Oberon-07 compiler from [Project Oberon](https://www.projectoberon.com/) and insights from [The Embedded Extended Oberon Operating System](https://github.com/m-spencer/extended-oberon), this compiler features a custom code generation module (`ORG`) specifically designed for emitting native **ARM Thumb-2** instructions.

---

## Key Features

* **Bare-Metal Code Generation:** Direct compilation to lean ARM Thumb-2 machine code with minimal runtime overhead.
* **Low Memory Footprint:** Zero heavy dependencies or dynamic runtime required—ideal for tight Flash/SRAM constraints.
* **Direct Hardware Manipulation:** System-level capabilities (`SYSTEM` module) for register bitwise operations, memory-mapped I/O, and peripheral access.

---

## Repository Structure

```text
Oberon-Cortex-M/
├── docs/                   # Architecture notes, language specs, & ISA docs
├── examples/               # Oberon simple programs and librairies for FRDM-MCXN947 board
│   ├── NXP_blinky/        
│   └── uart_echo/
├── src/                    # Compiler, Linker and NXP librairies Source Code
├── Tests/                  # Validation & compliance test suites
│   ├── 01/ .. 17/          # Progressive test cases adapted from Niklaus Wirth's specs
│   └── others              # Others test files for the compiler/linker
└── README.md
