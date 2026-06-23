# Repository Map

This repository was reorganized from the course folder so that the useful
material lives under `cosas_github`.

## Main Source Tree

- `introductory-task/`: original traffic-light FPGA task from the starter
  repository.
- `asm/`: assembly examples and SRAM programming helper.
- `rtl/`: SystemVerilog modules, testbenches, CPU design, cache experiments and
  FPGA constraints.
- `udev/`: hardware access rules for local Linux setup.
- `docs/`: manuals, handouts and cleanup notes.

## Integrated Sources

The final tree combines these local sources:

- `origin/main` in `cosas_github`: README, introductory task and existing PDFs.
- `../bonus/professor-frink-merge_cache_m_extension`: broad source snapshot
  containing the cache, BRAM and M-extension work. The embedded `install/`
  toolchain was not copied into Git.
- `../hardpracgit`: local worktree with uncommitted changes in the ALU, control
  unit, CPU, CSR, immediate generator, PC unit and one display assembly file.
  These files were copied last so the local work is preserved in the organized
  tree.
- `../introductory_task (1).pdf` and `../professor-frink-merge_cache_m_extension.zip`:
  course handout and original archive, now stored under `docs/`.

## Cleanup Decisions

- Removed tracked `.DS_Store` files.
- Removed tracked generated outputs such as `.vcd`, `.asc`, `.bin`, `.json` and
  `test_pre`.
- Added a root `.gitignore` for simulation/synthesis outputs and local
  toolchains.
- Kept small `.txt` program/input files when they are useful for CPU tests or
  examples.

## Local Material Not Added To Git

The top-level course folder contains large local toolchain installations in
`../install` and inside the extracted bonus snapshot. These are useful for the
environment but should not be versioned in the Git repository.
