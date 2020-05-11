#! /usr/bin/env python3

import sys

colors = [];

with open("colors-24.txt", "r") as handle:
    data = [int(x) for x in handle.read().split()]

for idx in range(64):
    colors.append((data[idx * 3], data[idx * 3 + 1], data[idx * 3 + 2]))

for color in colors:
    red = color[0] >> 5
    green = color[1] >> 5
    blue = color[2] >> 6
    val = (red << 5) + (green << 2) + blue
    sys.stdout.buffer.write(bytes([val]))    
