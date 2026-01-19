.section .text
.global write_all
.global draw_from_coordinates


# function that writes the entire contents of an array to the display
# a0: base address of the array
# a1: size of the array (in addresses, not elements. elements*4 = addresses)
write_all:
    li t0, 1#7          # simpoint t0 holds current page, 0 to 7, test with e.g. 1
    li t1, 0x01000003 # Address of I2C display

    page_loop:
        # set page address
        li t5, 0x000080B0 
        or t5, t5, t0   
        slli t5, t5, 16
        ori t5, t5, 0x000000B0  # append same command again, as we always send four bytes, but only need two
        or t5, t5, t0

        sw t5, 0(t1) # send to display

        # display has 132 columns
        addi t2, x0, 2#132 #simpoint test with e.g. 2
        addi t3, x0, 0
        column_loop:
            # calculate 8*t0 + t2,  8*y + x, with y being the page
            addi t6, x0, 132 # 132 * 4 * pagey + 4 * x
            mul t6, t6, t0
            add t6, t6, t3 # 132 * pagey + x
            addi t5, x0, 4
            mul t6, t6, t5

            add t6, t6, a0 # add array base address

            lw t4, 0(t6)
            lw t5, 4(t6)
            andi t4, t4, 0xFF # mask least significant byte
            andi t5, t5, 0xFF

            slli t4, t4, 16
            or t4, t4, t5 # construct data bytes for two commands

            li t5, 0xC0004000 # 1100 0000 - 0100 0000
            or t4, t4, t5

            sw t4, 0(t1) # send to display, cursor is automatically advanced one column to the right

            addi t3, t3, 2 # increment x counter by 2
            bne t3, t2, column_loop

        addi t0, t0, -1 # decrement page y counter by one
        bge t0, x0, page_loop

    jalr x0, ra, 0



# function that draws a single column to the display 
# x and y specify the position of the column
    # 0x1000003: I2C data
    # 0x1000004: I2C device address
    # 0x1000005: I2C byte mask
    # we expect the byte mask to be 0xf
draw_from_coordinates:
    # a1: x - column
    # a2: y - line/page
    # a3: the 8 bit value for one column
    li t0, 0x01000003



    # first command to set the lower and higher column address

    addi t1, a1, 0   # copy x coordinate to t1
    andi t1, t1, 0xf # mask 4 last bits (lower column address)

    # 0x80: 1000 0000: next byte is for command operation + one more set to follow
    # 0xB0: 0000 0000: command 1. set lower column address + space for lower column address
    li t5, 0x00008000 
    or t5, t5, t1     # add lower column address

    slli t5, t5, 16

    # 0x00: 0000 0000: next byte is for command operation + only data bytes follow
    # 0x10: 0001 0000: command 2. set higher column address + space for higher column address
    ori t5, t5, 0x00000010
    srli a1, a1, 4
    andi a1, a1, 0xf # mask 4 last bits (higher column address)
    or t5, t5, a1    # add higher column address

    sw t5, 0(t0)    # send to display

    # second command to set page address and transmit the data byte

    srli a2, a2, 3 # we don't care about the specific line in one page
    # 0x80: 1000 0000: next byte is for command operation + one more set to follow
    # 0xB0: 1011 0000: command 12. set page address + space for page address
    li t5, 0x000080B0 
    or t5, t5, a2   # add page address

    slli t5, t5, 16

    # 0x40: 0100 0000: next byte is for ram operation + only data bytes follow
    li t4, 0x00004000
    or t5, t5, t4
    or t5, t5, a3     # add 8 bit values for column

    sw t5, 0(t0)      # send to display

    jalr x0, ra, 0
    