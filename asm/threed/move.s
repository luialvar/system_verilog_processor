.section .text
.global walk
.global coord_equal
.global to_array_addr
.global first_line

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
    #mv a5, a2      # y==0
    addi a5, x0, 1  # false
    #addi a5, x0, 0  # true
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