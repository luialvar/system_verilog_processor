.section .text._start
.globl _start

# mtime[31:0] at 0x01000006 
# mtime[63:32] at 0x01000007
# uart at 0x01000002, write-only
_start:
    csrw mstatus, x0 # Disable interrupts

    li x14, 0x01000006 # mtime
    jal ra, reset_timer


loop:
    
    inner_loop:


    j loop


reset_timer:
    sw x0, 0(x14)  # Set mtime  0
    sw x0, 1(x14)  # Set mtimeh 0
    jalr x0, ra, 0















isr_jt:
    nop # cause 0
    nop # cause 1
    nop # cause 2
    nop # cause 3
    nop # cause 4
    nop # cause 5
    nop # cause 6
    j intr_timer_handle # cause 7 (timer interrupt)
    nop # cause 8
    nop # cause 9
    nop # cause 10
    nop # cause 11 (external interrupt)
    nop # cause 12
    nop # cause 13
    nop # cause 14
    nop # cause 15
