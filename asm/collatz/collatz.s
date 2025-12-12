.section .text._start
.globl _start

_start: 
    #start number
    addi x10, x0, 5     

    #constant 1
    addi x11, x0, 1   

    #counter 
    addi x12, x0, 0   

    #constant 3
    addi x13, x0, 3  

    #base address   
    li x14, 164

    sw x10, -4(x14)       

loop:
    beq x10, x11, end
    addi x12, x12, 1    #incr counter
    andi x5, x10, 1
    beq x5, x11, uneven

even:
    srli x10, x10, 1
    j store

uneven:
    mul x10, x10, x13
    addi x10, x10, 1

store:
    sw x10, 0(x14)
    addi x14, x14, 4
    j loop

end:
    addi x5, x12, 0  #save counter to x5
    beq x0, x0, end  #loop infinitely
