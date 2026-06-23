# program:
# base array address: s0
# hx: s6
# hy: s7
# tx: s8
# ty: s9
# fx: s10
# fy: s11
# 00: right
# 01: down
# 10: left
# 11: up
# dir: s5
_start:
#-------------------initialization sequence-------------------

    #disable interrupts:
    #csrw 0x300, x0 # mstatus, set everything to 0 (shouldn't do that if other bits are in use...)
    csrw mstatus, x0  # also possible if you don't want to remember register address

    # load stack pointer address into sp
    li sp, 0x00ffffff

    # load base address of isr jump table
    # external interrupts will be used to update the current walking direction
    la t0, isr_jt
    ori t0, t0, 0b01  # enable vectored mode
    csrw mtvec, t0    # store base addresss of ISRs in mtvec (0x305)

    # enable external interrupts (not global interrupt enable, that is in mstatus)
    li t1, 2048
    #add t0, x0, t1
    csrw mie, t1

    reset:
        # disable interrupts globally
        csrw mstatus, x0

        # load start address of array into s0
        li s0, 5000 # TODO: choose some start address

        # initialize array with 0s
        # number of 32-bit words (1056) needed to store all elements (8448)
        # loop counts down
        li t0, 4224 # array start address offset = 1056 * 8  #test with e.g. 64
        add t0, t0, s0
        array_init_loop:
            addi t0, t0, -16 # 8448 is divisible by 16

            sw x0, 0(t0)
            sw x0, 4(t0)
            sw x0, 8(t0)
            sw x0, 12(t0)

            blt s0, t0, array_init_loop  # branch if s0 < t0. Prevent additional loop execution if x0 == t0
        # initialize threed
        li t0, 0x00000001  # least significant bit 1 with direction right (00)
        # initial size is three, which is why we need to store two elements
        sw t0, 0(s0)
        sw t0, 4(s0)
        #li t0, 0x00010001  # downwards
        sw t0, 8(s0)

        # jump to function initializing the display (commands only, not display data)
        # doesn't need to store return address on the stack, as this is the topmost function
        #temp jal ra, init_display
        # initialize display with contents of array
        mv a0, s0     # set first function argument to array base address
        jal ra, write_all

        # initializes variables hx/y, tx/y, fx/y
        # hx: s6
        # hy: s7
        # tx: s8
        # ty: s9
        # fx: s10
        # fy: s11
        addi s6, x0, 2  # we start three elements long
        addi s7, x0, 0
        addi s8, x0, 0
        addi s9, x0, 0
        addi s10, x0, 0  # this is technically not necessary, as position will be randomized later on
        addi s11, x0, 0

        # initializes variables dir to 00, or right
        # dir: s5
        addi s5, x0, 0

        # draw head-position to display
        #mv a1, s6
        #mv a2, s7
        #addi a3, x0, 1
        #jal ra, draw_from_coordinates

        # todo: call "randomizer" for fx/y

        # enable global interrupts
        ori t0, x0, 8
        csrw mstatus, t0

#-------------------initialization finished-------------------


# main loop, draws an eight
main_loop:
    li s3, 4
    addi s5, x0, 0 # right
    jal ra, dir_loop

    li s3, 8
    addi s5, x0, 1 # down
    jal ra, dir_loop

    li s3, 4
    addi s5, x0, 0 # right
    jal ra, dir_loop

    li s3, 4
    addi s5, x0, 3 # up
    jal ra, dir_loop

    li s3, 8
    addi s5, x0, 2 # left
    jal ra, dir_loop

    li s3, 4
    addi s5, x0, 3 # up
    jal ra, dir_loop

    j main_loop

dir_loop:
    addi sp, sp, -4 # store return address on stack ponter
    sw ra, 0(sp)

    dir_loop_inner:
    j step
    dir_loop_entry:
    addi s3, s3, -1
    bne x0, s3, dir_loop_inner

    lw ra, 0(sp)
    addi sp, sp, 4

    jalr x0, ra, 0

#performs one iteration
step:

    mv a1, s6 # hx
    mv a2, s7 # hy
    mv a3, s10 # fx
    mv a4, s11 # fy

    jal first_line # temporary for testing
    #jal coord_equal # return value in a5, 0 if true

    beq x0, a5, f_handle # t_handle

    # order of t and h update matters, as t will be skipped if f_handle is executed
    t_update:
        # load t pos from array. Remove t pos, store new value

        # calculate array address offset for tx, ty:
        mv a1, s8 # tx
        mv a2, s9 # ty
        mv a3, s0 # array_start_address

        jal ra, to_array_addr # return in a0

        lw t3, 0(a0) # t3 = t array element
        addi sp, sp, -4
        sw t3, 0(sp)   # I dont want to recalculate the array address, so store on stack

        addi t4, x0, 1
        andi t0, s9, 0x7 # only interested in page-line for t, t0 = i
        sll t4, t4, t0 # 1 << i
        not t4, t4
        and t5, t3, t4 # remove t-bit from t array element
        sw t5, 0(a0)

        # draw to display
        mv a1, s8
        mv a2, s9
        andi a3, t5, 0xFF
        jal ra, draw_from_coordinates

        # walk t in t direction (got from array element)
        andi t0, s9, 0x7 # only interested in page-line for t, t0 = i
        addi t1, x0, 2
        mul t1, t1, t0
        addi t2, t1, 16 # t2 = 16 + 2*i

        lw t3, 0(sp)
        addi sp, sp, 4

        srl t3, t3, t2 # array_element >> 16 + 2 * i
        andi a5, t3, 0x3 # direction
        mv a3, s8 # tx
        mv a4, s9 # ty
        jal ra, walk
        mv s8, a1 # new tx
        mv s9, a2 # new ty

    h_update:
        #-------------- update direction of old h:
        mv a1, s6 # hx
        mv a2, s7 # hy
        mv a3, s0 # dir
        jal ra, to_array_addr # return in a0
        lw t3, 0(a0) # t3 = h array element

        andi t0, s7, 0x7 # only interested in page-line for h, t0 = i
        addi t1, x0, 2
        mul t1, t1, t0
        addi t2, t1, 16 # t2 = 16 + 2*i

        addi t4, x0, 3 # 11 mask
        sll t4, t4, t2
        not t4, t4
        and t3, t3, t4 # remove old direction from array element t3

        sll t4, s5, t2 # t3 = dir << t2
        or t3, t3, t4 # add new direction to array element t3
        sw t3, 0(a0) # store updated array element

        #--------------- walk h in dir direction
        mv a3, s6 # hx
        mv a4, s7 # hy
        mv a5, s5 # dir
        jal ra, walk

        mv s6, a1 # new hx
        mv s7, a2 # new hy
        mv a3, s0 # move array start address to function argument
        # load h pos from array. Add h pos, dir, store new value
        jal ra, to_array_addr # return in a0
        lw t3, 0(a0) # t3 = h array element

        andi t0, s7, 0x7 # only interested in page-line for h, t0 = i
        addi t4, x0, 1
        sll t4, t4, t0
        or t3, t3, t4 # add h-pos to array element t3

        sw t3, 0(a0) # store updated array element

        #------------- draw to display
        # get element at new head position, or with head position, draw
        andi t0, s7, 0x7 # only interested in page-line for h, t0 = i
        addi t1, x0, 1
        sll t1, t1, t0
        or t3, t3, t1 # add h pos
        # only draw to display, don't store back to array
        mv a1, s6
        mv a2, s7
        andi a3, t3, 0xFF # mask the 8 bits to be drawn
        jal ra, draw_from_coordinates

    j wait

f_handle:
    # TODO: implement f_handle, works without currently
    j h_update

wait:
    #li t0, 43336
    #li t0, 21668
    #wait_loop:
    #    addi t0, t0, -1
    #    bne x0, t0, wait_loop

    j dir_loop_entry

intr_ext_handle:
    # dir: s5

isr_jt:
    nop # cause 0
    nop # cause 1
    nop # cause 2
    nop # cause 3
    nop # cause 4
    nop # cause 5
    nop # cause 6
    nop # cause 7 (timer interrupt)
    nop # cause 8
    nop # cause 9
    nop # cause 10
    j intr_ext_handle # cause 11 (external interrupt)
    nop # cause 12
    nop # cause 13
    nop # cause 14
    nop # cause 15



# direction:
# 00: right
# 01: down
# 10: left
# 11: up
walk:
    # a1: new x
    # a2: new y
    # a3: x
    # a4: y
    # a5: direction
    addi t0, x0, 1
    andi t2, a5, 1 # first direction bit (b0): change x: 0, change y: 1

    srli t1, a5, 1 # shift direction (a5) one to the right
    andi t1, t1, 1 # value of second direction bit (b1)
    addi t3, x0, -2
    mul t1, t1, t3 # multiply b1 with -2, if b1 == 0, -2*0+1 = 1,    if b1 == 1, -2*1+1 = -1
    addi t1, t1, 1

    # copy coordinates to function return registers
    mv a1, a3 # x
    mv a2, a4 # y

    beq t0, t2, updown

    leftrigth:
        add a1, a1, t1
        li t0, -1
        beq a1, t0, underflowX # if y == -1, set y = 131
        li t0, 132
        beq a1, t0, overflowX # if y == 132, set y = 0
        j return

        underflowX:
            li a1, 131
            j return

        overflowX:
            li a1, 0
            j return

    updown:
        add a2, a2, t1 # update y coordinate
        li t0, -1
        beq a2, t0, underflowY # if y == -1, set y = 63

        andi a2, a2, 0x3f # overflow loop, a1 = a1 mod 64
        j return

        underflowY:
            li a2, 63

    return:
        jalr x0, ra, 0


coord_equal:
    # a1: x1
    # a2: y1
    # a3: x2
    # a4: y2
    # a5: return value, 0 if equal, everything else if not equal
    xor a5, a1, a3
    xor t0, a2, a4
    or a5, a5, t0
    jalr x0, ra, 0

first_line:
    # a1: DONT CARE
    # a2: y1
    # a3: DONT CARE
    # a4: DONT CARE
    # a5: return value, 0 if in first line
    mv a5, a2
    #addi a5, x0, 1
    #addi a5, x0, 0
    jalr x0, ra, 0

to_array_addr:
    # a1: x
    # a2: y
    # a3: array_start_addr
    # a0: return
    srli t3, a2, 3 # y to page
    addi t4, x0, 132
    mul t3, t3, t4 # page * 132
    slli a1, a1, 2 # multiply x by 4
    add a0, t3, a1 # page * 132 + x
    add a0, a0, a3 # add array_start_addr
    jalr x0, ra, 0


    # function that writes the entire contents of an array to the display
# a0: base address of the array
# a1: size of the array (in addresses, not elements. elements*4 = addresses)
write_all:
    li t0, 7          # t0 holds current page, 0 to 7, test with e.g. 1
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
        addi t2, x0, 132 # test with e.g. 2
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
