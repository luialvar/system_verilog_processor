.section .text
.global init_display

# Does not save any registers
init_display:
    # t0: Address of I2C display
    # t1: Storing the byte

    li t0, 0x01000003
    li t1, 60
    sw t1, 1(t0) # Store 60 in device addr
    li t1, 3
    sw t1, 2(t0) # 3 in byte mask (two LSBs)

#00: control byte, Co (7th bit) = 0, last control byte, only data bytes to follow
#                  D/notC (6th bit) = 0, data byte is for command operation

    li t1, 0x000000AE   # 1010 1110 11. display off (oled panel)
    sw t1, 0(t0)

    li t1, 0x000000A4   # 1010 0100 7. normal display on (0th bit = 0)
    sw t1, 0(t0)

    li t1, 0x000000D5   # 1101 0101 5. set frequency of internal clock to 
    sw t1, 0(t0)

    li t1, 0x00000050   # 0101 0000 ^^
    sw t1, 0(t0)

    li t1, 0x000000A8   # 1010 1000 9. 
    sw t1, 0(t0)

    li t1, 0x0000003F   # 0011 1111 ^^
    sw t1, 0(t0)

    li t1, 0x000000D3    # 1101 0011 14. Display offset
    sw t1, 0(t0)

    li t1, 0x00000000   # 0000 0000 ^^
    sw t1, 0(t0)

    li t1, 0x00000040   # 0100 0000 4. Start line address
    sw t1, 0(t0)

    li t1, 0x000000AD   # 1010 1101 10. DC-DC voltage control, 
    sw t1, 0(t0)

    li t1, 0x0000008B   # 1000 1011 ^^turn on (0th bit)
    sw t1, 0(t0)

    li t1, 0x000000DA   # 1101 1010 17.
    sw t1, 0(t0)

    li t1, 0x00000012   # 0001 0010 ^^
    sw t1, 0(t0)

    li t1, 0x00000081   # 1000 0001 5. contrast mode
    sw t1, 0(t0)

    li t1, 0x000000CF   # 1100 1111 ^^ pretty high contrast ig, 256 steps
    sw t1, 0(t0)

    li t1, 0x000000D9   # 1101 1001 16. Dis-charge/Pre-charge period
    sw t1, 0(t0)

    li t1, 0x00000022   # 0010 0010 ^^
    sw t1, 0(t0)

    li t1, 0x000000DB   # 1101 1011 18. VCOM deselect
    sw t1, 0(t0)

    li t1, 0x00000035   # 0011 0101 ^^
    sw t1, 0(t0)

    li t1, 0x000000A4   # 1010 0100 7. set entire display on/off (0th bit = 0)
    sw t1, 0(t0)

    li t1, 0x000000A6   # 1010 0110 8. set normal/reverse indiation (0th bit = 0 -> normal)
    sw t1, 0(t0)

    li t1, 0x000000DA   # 1101 1010 17. again
    sw t1, 0(t0)

    li t1, 0x00000012   # 0001 0010 ^^
    sw t1, 0(t0)

    li t1, 0x000000A1   # 1010 0001 6. Set segment remap
    sw t1, 0(t0)

    li t1, 0x000000C8   # 1100 1000 13. set common output scan direction
    sw t1, 0(t0)

    li t1, 0x00000000   # 0000 0000 1. set lower column address to 0000 (last 4 bits)
    sw t1, 0(t0)

    li t1, 0x00000010   # 0001 0000 2. set higher column address to 0000 (last 4 bits)
    sw t1, 0(t0)

    li t1, 0x000000AF   # 1010 1111 11. Display on (0th bit = 1)
    sw t1, 0(t0)

    # added:
    li t1, 15
    sw t1, 2(t0) # 15 in byte mask (all 4 byte pairs will be used from now on)

    jalr x0, ra, 0 # Return from function
