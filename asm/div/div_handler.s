.section .text
.global div

#x29: mepc
#x30: iword
handle_div_instr:
    sw x31, 0(sp)
    sw x30, 4(sp)
    sw x29, 8(sp)
    sw x28, 12(sp)
    addi sp, sp, 16
    csrr x30, 0x342         #load mcause
    li x31, 2
    bne x30, x31, exception #jump elsewhere if no illegal instruction caused exception

    csrr x29, 0x341         #load mepc into x29
    lw x30, 0(x29)          #retrieve iword that caused the exception
    andi x31, x30, 3
    li x28, divcode         #opcode+func3 of div
    bne x31, x28, exception #jump elsewhere if not div-instruction

    sw x27, 0(sp)
    sw x26, 4(sp)
    sw x25, 8(sp)
    sw x24, 12(sp)
    sw x23, 16(sp)
    sw x22, 20(sp)
    sw x21, 24(sp)
    sw x20, 28(sp)
    sw x19, 32(sp)
    sw x18, 36(sp)
    sw x17, 40(sp)
    sw x16, 44(sp)
    sw x15, 48(sp)
    sw x14, 52(sp)
    sw x13, 56(sp)
    sw x12, 60(sp)
    sw x11, 64(sp)
    sw x10, 68(sp)
    sw x9, 72(sp)
    sw x8, 76(sp)
    sw x7, 80(sp)
    sw x6, 84(sp)
    sw x5, 88(sp)
    sw x4, 92(sp)
    sw x3, 96(sp)

    addi sp, sp, 96

    andi x27, x30, r1mask
    srli x27, x27, 15       #x27 holds r1
    add x27, sp, x27
    lw x27, 0(x27)          #x27 holds contents of r1

    andi x26, x30, r2mask
    srli x26, x26, 20       #x26 holds r2
    add x26, sp, x26
    lw x26, 0(x26)          #x26 holds contents of r2

    andi x25, x30, rdmask
    srli x25, x25, 7        #x25 holds rd

    addi x31, x0, 0     #0, counter
    addi x30, x0, 1     #1, for comparison

div:
    blt x27, x30, finish   #x27 less than 1
    sub x27, x27, x26
    addi x31, x31, 1
    j div

finish:
    sub x28, sp, s25
    sw x31, 0(x28)      #store result
