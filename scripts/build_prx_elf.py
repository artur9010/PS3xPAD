#!/usr/bin/env python3
"""
Build a proper PS3 VSH PRX SPRX using the original release xpad_vsh.elf
as a template. We replace just the text section with our compiled code,
keeping the original's PRX parameter segment (import table).

This is the minimal viable approach: use a known-good PRX ELF template
and inject our code into it.
"""

import struct
import os
import sys

PROJECT_DIR = "/home/artur9010/dev/PS3xPAD"
RELEASE_ELF = "/tmp/nix-shell-49ylvsqbiy1m8kly0wd9mbxspw/build-top/opencode/ps3xpad-elfs/xpad_vsh.elf"
OUR_ELF = os.path.join(PROJECT_DIR, "src", "xpad.linked.elf")
OUTPUT_ELF = os.path.join(PROJECT_DIR, "src", "xpad_prx.elf")

def read_file(path):
    with open(path, "rb") as f:
        return f.read()

def write_file(path, data):
    with open(path, "wb") as f:
        f.write(data)

def parse_phdr(elf, idx, phoff, phentsize):
    off = phoff + idx * phentsize
    p_type, p_flags = struct.unpack(">IB", elf[off:off+5])
    p_offset, p_vaddr, p_paddr, p_filesz, p_memsz = struct.unpack_from(">QQQQQ", elf, off+8)
    p_align = struct.unpack_from(">Q", elf, off+48)[0]
    return {
        'type': p_type, 'flags': p_flags,
        'offset': p_offset, 'vaddr': p_vaddr, 'paddr': p_paddr,
        'filesz': p_filesz, 'memsz': p_memsz, 'align': p_align
    }

def main():
    if not os.path.exists(RELEASE_ELF):
        print(f"ERROR: Release ELF not found at {RELEASE_ELF}")
        print("Extract it first with: dd if=xpad_vsh.sprx of=xpad_vsh.elf bs=1 skip=144")
        sys.exit(1)
    if not os.path.exists(OUR_ELF):
        print(f"ERROR: Our ELF not found at {OUR_ELF}")
        sys.exit(1)

    release_elf = read_file(RELEASE_ELF)
    our_elf = read_file(OUR_ELF)

    # Parse original ELF header
    rel_phoff = struct.unpack_from(">Q", release_elf, 32)[0]
    rel_phentsize = struct.unpack_from(">H", release_elf, 54)[0]
    rel_phnum = struct.unpack_from(">H", release_elf, 56)[0]

    # Get release segments
    rel_segs = [parse_phdr(release_elf, i, rel_phoff, rel_phentsize) for i in range(rel_phnum)]
    rel_text = rel_segs[0]
    rel_data = rel_segs[1]
    rel_prx = rel_segs[2]

    # Our ELF: extract text from first LOAD segment
    our_phoff = struct.unpack_from(">Q", our_elf, 32)[0]
    our_phentsize = struct.unpack_from(">H", our_elf, 54)[0]
    our_phnum = struct.unpack_from(">H", our_elf, 56)[0]
    our_segs = [parse_phdr(our_elf, i, our_phoff, our_phentsize) for i in range(our_phnum)]

    # Find our first LOAD segment (text + data combined in PSL1GHT)
    our_load = None
    for s in our_segs:
        if s['type'] == 1:
            our_load = s
            break

    if not our_load:
        print("ERROR: No LOAD segment in our ELF")
        sys.exit(1)

    print(f"Release text: 0x{rel_text['filesz']:X} bytes at offset 0x{rel_text['offset']:X}")
    print(f"Release data: 0x{rel_data['filesz']:X} bytes at offset 0x{rel_data['offset']:X}")
    print(f"Release prx:  0x{rel_prx['filesz']:X} bytes at offset 0x{rel_prx['offset']:X}")
    print(f"Our load:     0x{our_load['filesz']:X} bytes at offset 0x{our_load['offset']:X}")

    if our_load['filesz'] > rel_text['filesz']:
        print(f"ERROR: Our load (0x{our_load['filesz']:X}) > release text (0x{rel_text['filesz']:X})")
        sys.exit(1)

    # Build new ELF: copy release, replace text segment with our code
    new_elf = bytearray(release_elf)

    # Copy our entire LOAD segment into release's text segment
    our_data = our_elf[our_load['offset']:our_load['offset'] + our_load['filesz']]

    # Zero out release's text segment first
    new_elf[rel_text['offset']:rel_text['offset'] + rel_text['filesz']] = b'\x00' * rel_text['filesz']

    # Write our code
    new_elf[rel_text['offset']:rel_text['offset'] + our_load['filesz']] = our_data

    # Zero out section headers (release has 0 anyway, but make sure)
    # Set e_shoff to 0 and e_shnum to 0
    struct.pack_into(">Q", new_elf, 40, 0)  # e_shoff
    struct.pack_into(">H", new_elf, 58, 0)  # e_shnum
    struct.pack_into(">H", new_elf, 60, 0)  # e_shstrndx

    write_file(OUTPUT_ELF, bytes(new_elf))
    print(f"\nWrote {OUTPUT_ELF} ({len(new_elf)} bytes)")

if __name__ == "__main__":
    main()
