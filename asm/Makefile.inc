.DEFAULT_GOAL := assemble
.PHONY: assemble readable clean

PORT = /dev/ttyACM0

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
	clang --target=riscv32 --print-supported-cpus -march=rv32im -o $@ -c $<
#	clang --target=riscv32 -march=rv32im -o $@ -c $<

$(FILE).tmp: $(OBJS)
	ld.lld -T ../hwp_tinyrv2.ld -o $(FILE).tmp $(OBJS)

$(FILE).bin: $(FILE).tmp
	llvm-objcopy -O binary $(FILE).tmp --set-start 0 $(FILE).bin

$(FILE).txt: $(FILE).bin
	hexdump -v -e '1/1 " %02X" "\n"' $(FILE).bin | sed 's/ //g' > $(FILE).txt
