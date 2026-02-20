.section .text._start
.globl _start

# mtime[31:0] at 0x01000006 
# mtime[63:32] at 0x01000007
# uart at 0x01000002, write-only
_start:
    csrw mstatus, x0 # Disable interrupts

    li s3, 0x01000006 # mtime
    li s4, 0x01000002 # Load address of UART
    li sp, 0x00fffffc

    addi a1, x0, 8  # 
    addi a2, x0, 16
    addi a3, x0, 256
    jal ra, loop_start_1

    addi a1, x0, 8  
    addi a2, x0, 16
    addi a3, x0, 256
    jal ra, loop_start_2

    addi a1, x0, 8  # 
    addi a2, x0, 16
    addi a3, x0, 256
    jal ra, loop_start_1

    j end
    
# slow loop
loop_start_1:   
    sw ra, 0(sp)
    addi sp, sp, -4

    add s1, x0, a1  # i
    add s2, x0, a2  # j

    jal ra, reset_timer

    addi t0, x0, 0  # outer (0 to i)

    loop_1:
        addi t1, x0, 0  # inner (0 to j)
        inner_loop_1:
            mul t4, t1, a3   # t4 = i * 256
            add t4, t4, t0   # t4 = t4 + j
            nop              # included because offset is added in second run to access different set
            slli t4, t4, 2   # t4 * 4
            add x0, x0, x5   # Zihintntl NTL.ALL, do not cache next load
            lw t5, 0(t4)

            addi t1, t1, 1  # incr i
            bne t1, s2, inner_loop_1

        addi t0, t0, 1 # incr j
    bne t0, s1, loop_1

    # load current timer
    lw t5, 0(s3)
    lw t6, 1(s3)
    sw t5, 0(s4) # send via uart
    sw t6, 0(s4)

    lw ra, 4(sp)
    addi sp, sp, 4

    jalr x0, ra, 0

loop_start_2:   
    sw ra, 0(sp)
    addi sp, sp, -4

    add s1, x0, a1  # i
    add s2, x0, a2  # j

    jal ra, reset_timer

    addi t0, x0, 0  # outer (0 to i)

    loop_2:
        addi t1, x0, 0  # inner (0 to j)
        inner_loop_2:
            mul t4, t0, a3   # t4 = j * 256
            add t4, t4, t1   # t4 = t4 + 256
            addi t4, t4, 32  # set = 0
            slli t4, t4, 2   # t4 * 4
            //add x0, x0, x5   # Zihintntl NTL.ALL, do not cache next load
            lw t5, 0(t4)

            addi t1, t1, 1  # incr i
            bne t1, s2, inner_loop_2

        addi t0, t0, 1 # incr j
    bne t0, s1, loop_2

    # load current timer
    lw t5, 0(s3)
    lw t6, 1(s3)
    sw t5, 0(s4) # send via uart
    sw t6, 0(s4)

    lw ra, 4(sp)
    addi sp, sp, 4

    jalr x0, ra, 0

reset_timer:
    sw x0, 0(s3)  # Set mtime  0
    sw x0, 1(s3)  # Set mtimeh 0
    jalr x0, ra, 0


end:
    j end


