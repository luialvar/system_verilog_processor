# SystemVerilog Processor

SystemVerilog and FPGA-based computer architecture project focused on RTL design, simulation, synthesis and hardware implementation.

## About

This repository contains my work for a digital design / processor architecture project developed in SystemVerilog.

The project is focused on understanding how hardware is described, simulated and synthesized, starting from introductory RTL designs and moving toward processor-related concepts. It includes SystemVerilog modules, Makefile-based build flows, FPGA toolchain files and supporting documentation.

The main goal is to practice low-level hardware design by working directly with RTL, finite state machines, clocked logic, synthesis tools and FPGA programming.

## Features

- SystemVerilog RTL design
- Introductory FPGA tasks
- Traffic light finite state machine example
- Clock divider module
- Testbench-based simulation
- Synthesis with Yosys
- Place and route with `nextpnr-ice40`
- Bitstream generation
- FPGA flashing workflow
- Pin constraint files
- udev rules for hardware access
- CPU and toolchain documentation

## Project Structure

```txt
.
├── introductory-task/
│   ├── jennifer/
│   │   ├── rtl/
│   │   │   ├── Makefile.inc
│   │   │   └── traffic_light/
│   │   ├── udev/
│   │   ├── traffic_light.pcf
│   │   └── traffic_light.sv
│   │
│   └── mattes/
│       ├── rtl/
│       └── udev/
│
├── cpu_manual.pdf
├── toolchain.pdf
└── README.md
```

## Main Concepts

### RTL Design

The project uses **SystemVerilog** to describe hardware modules at register-transfer level.

Instead of writing software that runs sequentially on a CPU, the code describes digital circuits that can be simulated and synthesized into FPGA logic.

### Finite State Machines

The introductory traffic light design is based on a finite state machine.

It switches between different states such as:

```txt
Red
 ↓
Red + Yellow
 ↓
Green
 ↓
Yellow
 ↓
Red
```

This is useful for learning how synchronous hardware changes state on clock edges.

### Clock Division

The design includes a clock divider module to generate slower timing signals from the FPGA clock.

This allows visible hardware behavior, such as LEDs changing state at human-observable speeds.

## Build Flow

The repository uses a Makefile-based workflow for several hardware design steps:

```txt
Simulation
    ↓
Synthesis
    ↓
Place and Route
    ↓
Bitstream Generation
    ↓
FPGA Flashing
```

## Usage

Go into one of the RTL task folders:

```bash
cd introductory-task/jennifer/rtl/traffic_light
```

Run simulation:

```bash
make simulation
```

Run synthesis:

```bash
make synthesis
```

Run place and route:

```bash
make pr
```

Generate the FPGA bitstream:

```bash
make gen_bitstream
```

Flash the bitstream to the FPGA:

```bash
make flash_bitstream
```

Run the full flow:

```bash
make
```

Clean generated files:

```bash
make clean
```

## Toolchain

The project is intended to be used with an open-source FPGA toolchain.

Main tools used:

- `iverilog`
- `vvp`
- `yosys`
- `nextpnr-ice40`
- `icepack`
- `dfu-util`
- `make`

Depending on the system, additional packages may be required for visualization or hardware access.

## Example Module

One of the introductory modules implements a traffic light controller using:

- Clocked logic
- Reset handling
- Enumerated states
- Combinational next-state logic
- LED output assignment

This makes it a good first step before moving into more complex processor components.

## Documentation

The repository also includes:

- `cpu_manual.pdf`
- `toolchain.pdf`

These files document the processor/task requirements and the hardware toolchain setup.

## What I Learned

Through this project I practiced:

- Writing SystemVerilog modules
- Designing finite state machines
- Understanding synchronous logic
- Working with clocks and resets
- Building RTL projects with Makefiles
- Simulating hardware designs
- Synthesizing logic for FPGA targets
- Generating and flashing bitstreams
- Using an FPGA-oriented development workflow
- Thinking in hardware instead of sequential software

## Technologies

- SystemVerilog
- Verilog toolchain
- FPGA development
- RTL design
- Yosys
- nextpnr-ice40
- Icarus Verilog
- Makefile

## Notes

This repository is part of my learning process in digital design and computer architecture.

The project is especially useful for understanding how low-level hardware blocks are described, tested and prepared to run on real FPGA hardware.

## Author

**Luis Ángel Álvarez Gil**  
Computer Engineering student  
University of Málaga / University of Würzburg
