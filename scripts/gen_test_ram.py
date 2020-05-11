#! /usr/bin/env python3

import random
import sys

# Generate 0x0500 bytes of something
for x in range(0x0500):
    sys.stdout.buffer.write(bytes([41]));

# Generate 256 bytes of 0x05
for x in range(256):
    sys.stdout.buffer.write(bytes([5]));

