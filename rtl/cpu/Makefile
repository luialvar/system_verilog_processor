FILE=cpu

#MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv memory.sv spi_master.sv i2c_master.sv uart_tx.v
#MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv ../cache/direct_mapped/id_cache_direct_mapped_large_misaligned.sv spi_master.sv i2c_master.sv uart_tx.v memory_cache.sv
MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv ../cache/set_associative/cache_set_associative.sv ../cache/set_associative/cache_way/cache_way.sv ../cache/set_associative/replacement_policy/plru_m.sv ../cache/set_associative/replacement_policy/fifo.sv spi_master.sv i2c_master.sv uart_tx.v memory_cache_set.sv
MODULES_SIM = $(MODULES_SYNTH) sram_sim.sv

include ../Makefile.inc
