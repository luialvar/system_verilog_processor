# Setup

## Required Tools

The Makefiles expect the following commands to be available:

- `make`
- `iverilog`
- `vvp`
- `yosys`
- `nextpnr-ice40`
- `icepack`
- `dfu-util`
- `clang`
- `ld.lld`
- `llvm-objcopy`
- `python3`

The local course folder already contains an OSS CAD Suite archive/extraction in
`../install/oss-cad-suite-linux-x64-20251030/oss-cad-suite`. From the repository
root, source its environment:

```sh
source "$PWD/../install/oss-cad-suite-linux-x64-20251030/oss-cad-suite/environment"
```

That local OSS CAD Suite contains the FPGA/simulation tools (`iverilog`,
`yosys`, `nextpnr-ice40`, `icepack`). In the current local extraction, the LLVM
assembly tools `ld.lld` and `llvm-objcopy` were not present, so install LLVM or
put those commands on `PATH` before using the `asm/` Makefiles.

## Hardware Access

The `udev/` directory contains rules for the pico-ice board and logic analyzer.
Install them once on a local Linux machine:

```sh
sudo cp udev/* /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger
```

The course lab machines may already have these rules installed.

## RTL Workflow

Most RTL folders include a `Makefile` that imports `rtl/Makefile.inc`.

```sh
cd rtl/alu
make simulation
make clean
```

Common targets:

- `simulation`: compile and run the testbench with Icarus Verilog.
- `synthesis`: generate a Yosys JSON netlist.
- `pr`: run place and route with nextpnr.
- `gen_bitstream`: create the FPGA bitstream.
- `flash_bitstream`: program the board with `dfu-util`.
- `clean`: remove generated artifacts.

## Assembly Workflow

Assembly folders import `asm/Makefile.inc`.

```sh
cd asm/fib
make
make readable
make clean
```

Common targets:

- `assemble` or `make`: build the binary.
- `readable`: produce a text hexdump.
- `program_sram`: send the binary to SRAM using `program_sram.py`.
- `clean`: remove generated assembly outputs.
