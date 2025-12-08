.section .text._start
.globl _start
_start:
    csrw mstatus, x0 # Disable interrupts
    la x5, isr_jt # Load base address
    ori x5, x5, 0b01 # Set mode to vectored
    csrw mtvec, x5

    li x13, 0x01000002 # Load address of UART
    li x1, 0x01000000 # Load address of GPIO out

    # Uncomment below to try out different exceptions
    # The exception_handler does not return

    # lw x0, 0(x13) # Load from UART -> load access fault

    # li x14, 0x12345678
    # lw x0, 0(x14) # Load address too big -> load access fault

    # li x1, 3
    # jalr x0, x1, 0 # PC misaligned

    li x1, 1000
    jalr x0, x1, 0 # illegal instruction

loop:
    j loop

exception_handler:
    csrr x12, mcause # Load mcause
    addi x12, x12, 48 # Shift in ascii table
    sw x12, 0(x13) # Show on UART

    # mret

    endless: # Trap forever
      j endless


isr_jt:
    j exception_handler # cause 0
    nop # cause 1
    nop # cause 2
    nop # cause 3 (software interrupt)
    nop # cause 4
    nop # cause 5
    nop # cause 6
    nop # cause 7 (timer interrupt)
    nop # cause 8
    nop # cause 9
    nop # cause 10
    nop # cause 11 (external interrupt)
    nop # cause 12
    nop # cause 13
    nop # cause 14
    nop # cause 15
