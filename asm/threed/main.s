.section .text._start
.globl _start
# simpoint: changes for simulation
# program:
# base array address: s0
# hx: s6
# hy: s7
# tx: s8
# ty: s9
# fx: s10
# fy: s11

_start:
#-------------------initialization sequence-------------------

    #disable interrupts:
    #csrw 0x300, x0 # mstatus, set everything to 0 (shouldn't do that if other bits are in use...)
    csrw mstatus, x0  # also possible if you don't want to remember register address

    # load stack pointer address into sp
    li sp, 0x00ffffff
    #li sp, 0x00fffffc

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
        li t0, 4224  #simpoint 4224 # array start address offset = 1056 * 8  #test with e.g. 64
        add t0, t0, s0
        array_init_loop:
            addi t0, t0, -16 # 4224 is divisible by 16

            sw x0, 0(t0)
            sw x0, 4(t0)
            sw x0, 8(t0)
            sw x0, 12(t0)

            blt s0, t0, array_init_loop  # branch if s0 < t0. Prevent additional loop execution if x0 == t0
        # initialize threed
        li t0, 0x00000001  # least significant bit 1 with direction right (00)
        # initial size is three
        sw t0, 0(s0)
        sw t0, 4(s0)
        sw t0, 8(s0)
        
        # jump to function initializing the display (commands only, not display data)
        # doesn't need to store return address on the stack, as this is the topmost function
        #jal ra, init_display #simpoint
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
        addi s6, x0, 2  # initial size is three
        addi s7, x0, 0
        addi s8, x0, 0
        addi s9, x0, 0
        addi s10, x0, 0  # this is technically not necessary, as position will be randomized later on
        addi s11, x0, 0

        # initializes variables dir to 00 (right)
        # dir: s5
        addi s5, x0, 0

        # draw head-position to display
        #mv a1, s6
        #mv a2, s7
        #addi a3, x0, 1
        #jal ra, draw_from_coordinates

        # todo: fx/y
 
        # enable interrupts globally
        ori t0, x0, 8
        #csrw mstatus, t0 #temp_final: uncommend for final

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
        #-------------- load t pos from array. Remove t pos, store new value

        # calculate array address offset for tx, ty:
        mv a1, s8 # tx
        mv a2, s9 # ty
        mv a3, s0 # array_start_address

        jal ra, to_array_addr # return in a0

        lw t3, 0(a0) # t3 = t array element
        addi sp, sp, -4
        sw t3, 0(sp)   # I dont want to recalculate the array address, so store element on stack

        addi t4, x0, 1
        andi t0, s9, 0x7 # only interested in page-line for t, t0 = i
        sll t4, t4, t0 # 1 << i
        not t4, t4
        and t5, t3, t4 # remove t-bit from t array element
        sw t5, 0(a0)
        
        #-------------- draw to display
        mv a1, s8
        mv a2, s9
        andi a3, t5, 0xFF
        jal ra, draw_from_coordinates

        #-------------- walk t in t direction (got from array element)
        andi t0, s9, 0x7 # only interested in page-line for t, t0 = i
        addi t1, x0, 2
        mul t1, t1, t0 
        addi t2, t1, 16 # t2 = 16 + 2*i

        lw t3, 0(sp)    #retrieve array element from stack
        addi sp, sp, 4

        srl t3, t3, t2 # array_element >> 16 + 2 * i
        andi a5, t3, 0x3 # get next direction from old array element
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
    #simpoint
    #li t0, 43336
    #li t0, 21668
    #li t0, 2000
    #li t0, 1
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


    

