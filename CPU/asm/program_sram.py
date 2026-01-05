#!/usr/bin/env python3

import sys
import serial
import time
from tqdm import tqdm

if __name__ == "__main__":
    port = sys.argv[1]
    END = b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"

    program = []
    with open(sys.argv[2], "rb") as f:
        instruction = f.read(4)

        while instruction:
            program.append(instruction)
            instruction = f.read(4)

    address = 0
    with serial.Serial(port, baudrate = 9600) as ser:
        print("Programming SRAM...")

        # Start programming mode with 0x02
        ser.write(b"\x02")
        for line in tqdm(program):
            ser.write(address.to_bytes(4))
            ser.write(line)
            address += 4
            time.sleep(0.01)

        # Send ending sequence
        ser.write(END)

        print("Finished programming!")
