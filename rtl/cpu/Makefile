FILE=cpu

# two level set associative cache
# MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv ../two_level_cache/cache_module_set.sv ../two_level_cache/cache_way.sv ../two_level_cache/d_cache_set_associative.sv ../two_level_cache/cache_set_associative.sv spi_master.sv i2c_master.sv uart_tx.v memory_cache_set.sv ../cache/set_associative/replacement_policy/plru_m.sv ../cache/set_associative/replacement_policy/fifo.sv ../bram_modules/spram.sv ../bram_modules/sbram.sv

# original cpu
#MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv memory.sv spi_master.sv i2c_master.sv uart_tx.v

# direct mapped misaligned, needs different mem-module
#MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv ../cache/direct_mapped/cache_module/cache_module.sv ../cache/direct_mapped/id_c_large_misaligned/id_c_large_misaligned.sv spi_master.sv i2c_master.sv uart_tx.v memory_cache.sv ../bram_modules/spram.sv ../bram_modules/sbram.sv

# set associative
MODULES_SYNTH = ../csr/csr.sv ../alu/alu.sv ../control/control.sv ../imm_gen/imm_gen.sv ../pc_unit/pc_unit.sv ../regs/regs.sv ../cache/set_associative/cache_set_associative.sv ../cache/set_associative/cache_way/cache_way.sv ../cache/set_associative/replacement_policy/plru_m.sv ../cache/set_associative/replacement_policy/fifo.sv spi_master.sv i2c_master.sv uart_tx.v memory_cache_set.sv
MODULES_SIM = $(MODULES_SYNTH) sram_sim.sv


include ../Makefile.inc
