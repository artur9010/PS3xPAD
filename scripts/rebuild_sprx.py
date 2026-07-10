#!/usr/bin/env python3
"""
Build a proper PS3 VSH SPRX by replacing the embedded ELF in the
original release xpad_vsh.sprx with our compiled code.

The original SPRX structure:
  0x000: SCE header (64 bytes)
  0x040: Extended header + segment info (~0x50 bytes)
  0x090: ELF header (64 bytes)
  0x0D0: ELF program headers (3 * 56 = 168 bytes)
  0x178: ELF data (text at 0xF0, data at 0x13F90, prx at 0x19620)

We replace the ELF data with our code, keeping the SCE header intact.
The SCE header contains the encryption keys/metadata, so we can't re-encrypt
without the original keys. But we CAN copy the SCE header as-is and just
swap the ELF content.

This won't work because the SCE header contains a hash/signature of the
ELF data. So we need a different approach.

Alternative: just use the original SPRX as-is (it works), and replace
the code section bytes directly in the SPRX file.
"""

import struct
import os
import sys

PROJECT_DIR = "/home/artur9010/dev/PS3xPAD"
RELEASE_SPRX = os.path.join(PROJECT_DIR, "src", "xpad_vsh.sprx")
OUR_ELF = os.path.join(PROJECT_DIR, "src", "xpad.linked.elf")
OUTPUT_SPRX = os.path.join(PROJECT_DIR, "src", "xpad_rebuilt.sprx")

def read_file(path):
    with open(path, "rb") as f:
        return f.read()

def write_file(path, data):
    with open(path, "wb") as f:
        f.write(data)

def main():
    if not os.path.exists(RELEASE_SPRX):
        print(f"ERROR: Release SPRX not found at {RELEASE_SPRX}")
        sys.exit(1)
    if not os.path.exists(OUR_ELF):
        print(f"ERROR: Our ELF not found at {OUR_ELF}")
        sys.exit(1)

    release_sprx = read_file(RELEASE_SPRX)
    our_elf = read_file(OUR_ELF)

    # Parse original SPRX SCE header
    s_elf_offset = struct.unpack_from(">Q", release_sprx, 0x28)[0]  # ELF offset
    s_shdr_offset = struct.unpack_from(">Q", release_sprx, 0x30)[0]  # Section headers
    s_data_len = struct.unpack_from(">Q", release_sprx, 0x18)[0]  # Data length

    print(f"Release SPRX: {len(release_sprx)} bytes")
    print(f"  ELF offset: 0x{s_elf_offset:X}")
    print(f"  SHDR offset: 0x{s_shdr_offset:X}")
    print(f"  Data length: 0x{s_data_len:X}")

    # ELF is at s_elf_offset
    # Parse ELF program headers to find text segment
    elf_offset = s_elf_offset
    e_phoff = struct.unpack_from(">Q", release_sprx, elf_offset + 32)[0]
    e_phentsize = struct.unpack_from(">H", release_sprx, elf_offset + 54)[0]
    e_phnum = struct.unpack_from(">H", release_sprx, elf_offset + 56)[0]

    print(f"  ELF phoff: 0x{e_phoff:X}, phentsize: {e_phentsize}, phnum: {e_phnum}")

    # Find text segment (first LOAD with filesz > 0)
    for i in range(e_phnum):
        phdr_off = elf_offset + e_phoff + i * e_phentsize
        p_type = struct.unpack_from(">I", release_sprx, phdr_off)[0]
        p_offset = struct.unpack_from(">Q", release_sprx, phdr_off + 8)[0]
        p_filesz = struct.unpack_from(">Q", release_sprx, phdr_off + 32)[0]
        print(f"  PHDR[{i}]: type=0x{p_type:X} offset=0x{p_offset:X} filesz=0x{p_filesz:X}")
        if p_type == 1 and p_filesz > 0:
            text_sprx_offset = elf_offset + p_offset
            text_size = p_filesz
            print(f"    -> Text segment at SPRX offset 0x{text_sprx_offset:X}, size 0x{text_size:X}")
            break

    # Our ELF: get first LOAD segment
    our_phoff = struct.unpack_from(">Q", our_elf, 32)[0]
    our_phentsize = struct.unpack_from(">H", our_elf, 54)[0]
    our_phnum = struct.unpack_from(">H", our_elf, 56)[0]
    for i in range(our_phnum):
        phdr_off = our_phoff + i * our_phentsize
        p_type = struct.unpack_from(">I", our_elf, phdr_off)[0]
        p_offset = struct.unpack_from(">Q", our_elf, phdr_off + 8)[0]
        p_filesz = struct.unpack_from(">Q", our_elf, phdr_off + 32)[0]
        if p_type == 1 and p_filesz > 0:
            our_text = our_elf[p_offset:p_offset + p_filesz]
            print(f"  Our text: 0x{p_filesz:X} bytes")
            break

    if len(our_text) > text_size:
        print(f"ERROR: Our text (0x{len(our_text):X}) > release text (0x{text_size:X})")
        sys.exit(1)

    # Rebuild SPRX: copy release, replace text segment
    new_sprx = bytearray(release_sprx)

    # Zero out original text
    new_sprx[text_sprx_offset:text_sprx_offset + text_size] = b'\x00' * text_size

    # Write our code
    new_sprx[text_sprx_offset:text_sprx_offset + len(our_text)] = our_text

    # Pad remaining with zeros (already zeroed)
    write_file(OUTPUT_SPRX, bytes(new_sprx))
    print(f"\nWrote {OUTPUT_SPRX} ({len(new_sprx)} bytes)")
    print("WARNING: This SPRX has the original SCE header but different code.")
    print("It will NOT load on PS3 because the SCE header signature is invalid.")

if __name__ == "__main__":
    main()
