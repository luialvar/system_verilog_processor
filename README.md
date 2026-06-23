# Embedded Processor Lab

Course repository for a SystemVerilog/RISC-V processor lab. It now keeps the
introductory FPGA task, the processor RTL, assembly examples, hardware access
rules and course documentation in one place.

## Repository Layout

```txt
.
|-- asm/                 RISC-V assembly examples and SRAM programming helper
|-- docs/                Course PDFs and organization notes
|-- introductory-task/   First traffic-light FPGA exercise
|-- rtl/                 SystemVerilog modules, testbenches and CPU design
|-- udev/                Local hardware access rules
|-- .gitignore           Generated files and local tools excluded from Git
`-- README.md
```

## What Is Included

- Introductory traffic-light designs from the original course task.
- Processor building blocks: ALU, control unit, CSR, immediate generator,
  PC unit, register file and CPU top level.
- Memory and peripheral support for SRAM, GPIO, UART, SPI and I2C examples.
- Cache and BRAM work from the `merge_cache_m_extension` branch.
- Assembly programs for tests and demos: Fibonacci, GPIO, UART, I2C display,
  exceptions, cache tests, Collatz and 3D display examples.
- Documentation under `docs/`, including the CPU manual, toolchain guide and
  original introductory task PDF.

## Quick Start

Set up the FPGA/toolchain binaries first. If you are using the local course
OSS CAD Suite that lives next to this repository, source its environment:

```sh
source "$PWD/../install/oss-cad-suite-linux-x64-20251030/oss-cad-suite/environment"
```

Run a simple RTL simulation:

```sh
cd rtl/alu
make simulation
```

Build an assembly example:

```sh
cd asm/fib
make
```

The assembly flow also needs LLVM tools such as `ld.lld` and `llvm-objcopy` on
`PATH`.

Run the complete FPGA flow for a design with a `.pcf` file:

```sh
cd rtl/traffic_light
make
```

Clean generated files in any module folder:

```sh
make clean
```

## Documentation

- [docs/README.md](docs/README.md) lists the course documents and archived
  material.
- [docs/setup.md](docs/setup.md) explains toolchain and hardware setup.
- [docs/repository-map.md](docs/repository-map.md) explains how the current
  tree was organized from the different local copies.
- [docs/branches.md](docs/branches.md) summarizes the remote branches that
  were present in the copied Git repository.

## Notes

Generated simulation and synthesis files are intentionally ignored. The source
tree should contain code, Makefiles, constraints, documentation and small input
data files; large local toolchains and build outputs should stay outside Git.
