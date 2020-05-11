#! /usr/bin/env python3

import random
import sys

for row in range(8):
        # blue background
        sys.stdout.buffer.write(bytes([0x21]))

        if row == 0:
            sys.stdout.buffer.write(bytes([0x20]))
            sys.stdout.buffer.write(bytes([0x0d]))
            sys.stdout.buffer.write(bytes([0x0d]))
        elif row == 4:
            sys.stdout.buffer.write(bytes([0x15]))
            sys.stdout.buffer.write(bytes([0x35]))
            sys.stdout.buffer.write(bytes([0x17]))
        else:
            for idx in range(3):
                while True:
                    val = random.randint(1, 60)
                    check = (val % 16)
                    if check > 0 and check < 13: break
        
                sys.stdout.buffer.write(bytes([val]))
