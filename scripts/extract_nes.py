#! /usr/bin/env python3

import argparse
import sys

def parse_header(nes_buf):
    """ Parse NES header """
    header = {"flags": {}}

    # Check for valid header
    if nes_buf[:3] != b"NES":
        return None

    header["prg_size"] = 16 * 1024 * nes_buf[4]
    header["chr_size"] = 8 * 1024 * nes_buf[5]
    
    # Read flags
    for flag in range(6, 11):
        header["flags"][flag] = nes_buf[flag]

    return header


argparser = argparse.ArgumentParser()
argparser.add_argument("nes", help="nes input")
argparser.add_argument("output", help="output base")

args = argparser.parse_args()

with open(args.nes, "rb") as handle:
    nes_buf = handle.read()

header = parse_header(nes_buf)

if header is None:
    print("Invalid header!")
    sys.exit(1)

write_pos = 16

# Check for trainer
if header["flags"][6] & 0x02 > 0:
    with open("{}.trainer".format(args.output), "wb") as handle:
        handle.write(nes_buf[write_pos:write_pos + 512])
        write_pos += 512

# Write PRG ROM
with open("{}.prg".format(args.output), "wb") as handle:
    handle.write(nes_buf[write_pos:write_pos + header["prg_size"]])
    write_pos += header["prg_size"]

# Write CHR ROM
with open("{}.chr".format(args.output), "wb") as handle:
    handle.write(nes_buf[write_pos:write_pos + header["chr_size"]])
    write_pos += header["chr_size"]
