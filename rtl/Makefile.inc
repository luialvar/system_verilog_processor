.DEFAULT_GOAL := all
TARGET ?= synth_ice40

.PHONY: simulation synthesis synthesis_generic visualize visualize_generic pr pr-gui formal gen_bitstream flash_bitstream all clean .FORCE

simulation: test_pre .FORCE
	vvp test_pre

test_pre: $(FILE).sv $(FILE)_tb.sv $(MODULES_SIM)
	iverilog -g2012 -o test_pre $(MODULES_SIM) $(FILE).sv $(FILE)_tb.sv

synthesis: $(FILE).json
$(FILE).json: $(FILE).sv $(MODULES_SYNTH)
	yosys -p '$(TARGET) -dsp -spram -top $(FILE); write_json $(FILE).json;' $(FILE).sv $(MODULES_SYNTH)
#	yosys -p '$(TARGET) -dsp -spram -top $(FILE); write_json $(FILE).json; show -format svg -prefix $(FILE)_yosys' $(FILE).sv $(MODULES_SYNTH)

synthesis_generic: $(FILE)_generic.json
$(FILE)_generic.json: $(FILE).sv $(MODULES_SYNTH)
	yosys -p 'hierarchy -top $(FILE); proc; write_json $(FILE)_generic.json; show -format svg -prefix $(FILE)_generic_yosys $(FILE);' $(FILE).sv $(MODULES_SYNTH)

visualize_ice40: $(FILE).pdf
$(FILE).pdf: $(FILE).json
	sed -i -e 's/inout/output/g' $(FILE).json
	netlistsvg $(FILE).json -o $(FILE).svg
	svgo $(FILE).svg
	rsvg-convert -f pdf -o $(FILE).pdf $(FILE).svg

visualize_generic: $(FILE)_generic.pdf
$(FILE)_generic.pdf: $(FILE)_generic.json
	sed -i -e 's/inout/output/g' $(FILE)_generic.json
	netlistsvg $(FILE)_generic.json -o $(FILE)_generic.svg
	svgo $(FILE)_generic.svg
	rsvg-convert -f pdf -o $(FILE)_generic.pdf $(FILE)_generic.svg

pr: $(FILE).asc
$(FILE).asc: $(FILE).json $(FILE).pcf
	nextpnr-ice40 --up5k --package sg48 --pcf-allow-unconstrained --asc $(FILE).asc --pcf $(FILE).pcf --json $(FILE).json

$(FILE).pcf:
	@echo "You didn't provide a .pcf file. Your FPGA mappings will be random and probably won't work"
	@echo "# No .pcf file was provided, so this stub was created. You may put your pin mappings here" >> $(FILE).pcf

pr-gui: $(FILE).json
	nextpnr-ice40 --up5k --package sg48 --asc $(FILE).asc --json $(FILE).json --gui

gen_bitstream: $(FILE).bin
$(FILE).bin: $(FILE).asc
	icepack $(FILE).asc $(FILE).bin

flash_bitstream: $(FILE).bin .FORCE
	dfu-util --alt 0 --download $(FILE).bin

all: simulation synthesis pr gen_bitstream flash_bitstream

clean:
	rm -f test_pre *.vcd $(FILE).json* $(FILE).asc $(FILE).bin $(FILE).pdf $(FILE).svg
	rm -f $(FILE)_generic.json* $(FILE).asc $(FILE).bin $(FILE)_generic.pdf $(FILE)_generic.svg
	rm -f $(FILE)_yosys.svg $(FILE)_yosys.dot $(FILE)_generic_yosys.svg $(FILE)_generic_yosys.dot
	rm -rf $(FILE) $(FILE)_basic $(FILE)_cover

# Just a hack to make some targets always out-of-date
.FORCE:
