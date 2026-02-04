FILE=id_c_large_misaligned
#FILE=cache_direct_mapped
TARGET=synth_ice40
#MODULES_SIM = ../imm_gen/imm_gen.sv# ../constants.sv
#MODULES_SYNTH = $(MODULES_SIM)
MODULES_SYNTH = ../../../bram_modules/spram.sv ../../../bram_modules/sbram.sv ../cache_module/cache_module.sv  ../../../cpu/spi_master.sv
MODULES_SIM = $(MODULES_SYNTH) ../../../cpu/sram_sim.sv
#../../../bram_modules/spram_manual.sv

include ../../../Makefile.inc
