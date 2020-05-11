#! /usr/bin/env python3

import random
import sys

# Generate 64 sprites
for sprite in range(64):
    # Draw first 8 on same line, overlapping
    if sprite < 8:
        x = 20 + sprite * 6
        y = 255 #25
        tile = 179 + sprite
        attributes = 0xC1

    # Draw next 6 on diagonal line, overlapping
    elif sprite < 14:
        x = sprite * 7 + 20
        y = 255 #40 + sprite * 5 
        tile = 112 + sprite
        attributes = 2

    elif sprite == 14:
        x = 254
        y = 255 #100
        tile = 112
        attributes = 3

    else:
        x = 100 + sprite
        y = 255
        tile = 1 + sprite
        attributes = 0

    sys.stdout.buffer.write(bytes([y, tile, attributes, x]))
