.section .text._start
.globl _start

_start: 
    addi x10, x0, 5     #number
    addi x11, x0, 1     #1
    addi x12, x0, 0     #counter
    addi x13, x0, 3     #3

loop:
    beq x10, x11, end
    addi x12, x12, 1    #incr counter
    andi x5, x10, 1
    beq x5, x11, uneven

even:
    srli x10, x10, 1
    beq x0, x0, loop

uneven:
    mul x10, x10, x13
    addi x10, x10, 1
    beq x0, x0, loop

end:
    addi x5, x12, 0  #save counter to x5
    beq x0, x0, end  #loop infinitely
