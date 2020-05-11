#! /usr/bin/env python3

import random
import sys

# Generate 2 nametables of happy clouds  (176 178 top, 177 179 bottom, 36 is empty)
for _ in range(2):
    for row in range(30):
        if row % 3 == 0:
            for col in range(32):
                sys.stdout.buffer.write(bytes([36]))
        
        if row % 3 == 1:
            for col in range(32):
                if col % 8 > 3:
                    sys.stdout.buffer.write(bytes([36]))
                else:
                    sys.stdout.buffer.write(bytes([176 + 2 * (col % 2)]))
        if row % 3 == 2:
            for col in range(32):
                if col % 8 > 3:
                    sys.stdout.buffer.write(bytes([36]))
                else:
                    sys.stdout.buffer.write(bytes([177 + 2 * (col % 2)]))

    # Generate attribute table of random palettes
    for idx in range(64):
        top = random.randint(0, 3)
        bottom = random.randint(0, 3)
        # val = (bottom << 6) + (bottom << 4) + (top << 2) + top
        val = (0 << 6) + (0 << 4) + (0 << 2) + 0
        sys.stdout.buffer.write(bytes([val]))

sys.exit(0)

# Generate nametable of goombas (112, 113, 114, 115)
for row in range(30):
    for col in range(32):
        if row % 2 == 0:
            sys.stdout.buffer.write(bytes([112 + (col % 2)]))
        else:
            sys.stdout.buffer.write(bytes([114 + (col % 2)]))


# Generate attribute table of random palettes
for idx in range(64):
    top = random.randint(0, 3)
    bottom = random.randint(0, 3)
    # val = (bottom << 6) + (bottom << 4) + (top << 2) + top
    val = (1 << 6) + (1 << 4) + (1 << 2) + 1
    sys.stdout.buffer.write(bytes([val]))

# Generate nametable of cheep-cheeps (178, 179, 180, 181)
for row in range(30):
    for col in range(32):
        if row % 2 == 0:
            sys.stdout.buffer.write(bytes([178 + (col % 2)]))
        else:
            sys.stdout.buffer.write(bytes([180 + (col % 2)]))

# Generate attribute table of random palettes
for idx in range(64):
    top = random.randint(0, 3)
    bottom = random.randint(0, 3)
    #val = (bottom << 6) + (bottom << 4) + (top << 2) + top
    val = (2 << 6) + (2 << 4) + (2 << 2) + 2
    sys.stdout.buffer.write(bytes([val]))
