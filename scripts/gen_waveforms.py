#! /usr/bin/env python3

import argparse
import math
import random
import struct
import sys

def two_comp(val, size):
    if val >= 0:
        return val

    return 2**size + val

argparser = argparse.ArgumentParser()
argparser.add_argument("depth", type=int, help="sample depth")
argparser.add_argument("size", type=int, help="number of samples per waveform")

args = argparser.parse_args()

# Use one bit lower than max val (need last bit for negative)
max_val = 2**(args.depth - 1) - 1

for wave in ("sine", "square", "tri", "saw", "noise", "custom"):
    for size_idx in range(args.size):
        if wave == "sine":
            val = math.sin((size_idx / args.size) * math.tau) * max_val 

        if wave == "square":
            val = max_val if size_idx < (args.size / 2) else -max_val

        if wave == "tri":
            val = (size_idx / args.size * 2) * max_val * 2 - max_val
            if size_idx > (args.size / 2):
                val = max_val * 2 - val 

        if wave == "saw":
            val = (size_idx / args.size) * max_val * 2 - max_val

        if wave == "noise":
            val = random.randint(-max_val, max_val)

        byte_val = two_comp(int(val), args.depth)            
        #print(two_comp(int(val), args.depth))
        sys.stdout.buffer.write(struct.pack(">H", byte_val))
    #print()
