FILE=cache_set_associative
#FILE=cache_direct_mapped
TARGET=synth_ice40
#MODULES_SIM = ../imm_gen/imm_gen.sv# ../constants.sv
#MODULES_SYNTH = $(MODULES_SIM)
MODULES_SYNTH = ../../../constants.sv ../../../cpu/spi_master.sv ./../replacement_policy/plru_m.sv ./cache_way.sv
MODULES_SIM = $(MODULES_SYNTH) ../../../cpu/sram_sim.sv

include ../../Makefile.inc
