.DEFAULT_GOAL := assemble
.PHONY: assemble readable clean

PORT = /dev/tty.usbmodem101

# Interactive targets
# ==========================
assemble: $(FILE).bin
program_sram: $(FILE).bin
	python3 ../program_sram.py $(PORT) $(FILE).bin

readable: $(FILE).txt

clean:
	rm -f *.bin *.out *.o *.tmp *.txt

# Proper targets
# ==========================
%.o: %.s
	/opt/homebrew/bin/riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32e -o $@ -c $<

$(FILE).tmp: $(OBJS)
	/opt/homebrew/bin/riscv64-unknown-elf-ld -T ../hwp_tinyrv2.ld -o $(FILE).tmp $(OBJS)

$(FILE).bin: $(FILE).tmp
	/opt/homebrew/bin/riscv64-unknown-elf-objcopy -O binary $(FILE).tmp --set-start 0 $(FILE).bin

$(FILE).txt: $(FILE).bin
	hexdump -v -e '1/1 " %02X" "\n"' $(FILE).bin | sed 's/ //g' > $(FILE).txt
