#!/usr/bin/env python3
"""
Build a scetool-compatible data/keys file from codyps/ps3keys raw key files.

scetool expects /data/keys as an INI file with sections per keyset:
  [keyname]
  type={SELF, RVK, PKG, SPP, OTHER}
  revision={00, ..., 18, 8000}
  version={...}
  self_type={LV0, LV1, LV2, APP, ISO, LDR, UNK_7, NPDRM}
  key=...   (32 bytes hex)
  erk=...   (32 bytes hex)
  riv=...   (16 bytes hex)
  pub=...   (40 bytes hex)
  priv=...  (21 bytes hex)
  ctype=... (1 byte hex)
"""

import os
import sys

KEYS_DIR = os.environ.get("PS3KEYS_DIR", "/home/artur9010/dev/PS3xPAD/ext_sources/ps3keys")
OUTPUT_KEYS = os.path.join(KEYS_DIR, "keys")

# Map key types to (self_type, version, section_name)
# The codyps keys have: key, iv, pub, priv, ctype per keyset
# scetool needs: key, erk, riv, pub, priv, ctype
# For SELF types, key=key, erk=key, riv=iv

KEYSETS = [
    # (section_name, self_type, version, revision, prefix, fw_suffix)
    # Only SELF-type keys are needed for signing ELF->SELF
    ("app",       "APP",   "0001000000000000", "00", "app",       "355"),
    ("iso",       "ISO",   "0001000000000000", "00", "iso",       "355"),
    ("lv1",       "LV1",   "0001000000000000", "00", "lv1",       "355"),
    ("lv2",       "LV2",   "0001000000000000", "00", "lv2",       "355"),
    ("ldr",       "LDR",   "0001000000000000", "00", "ldr",       "retail"),
]

def read_binary(path):
    with open(path, "rb") as f:
        return f.read().hex()

def build_keyfile():
    out = []
    out.append("# scetool keys file")
    out.append("# Generated from codyps/ps3keys")
    out.append("")

    for section, self_type, version, revision, prefix, fw_suffix in KEYSETS:
        key_path = f"{KEYS_DIR}/{prefix}-key-{fw_suffix}"
        iv_path = f"{KEYS_DIR}/{prefix}-iv-{fw_suffix}"
        pub_path = f"{KEYS_DIR}/{prefix}-pub-{fw_suffix}"
        priv_path = f"{KEYS_DIR}/{prefix}-priv-{fw_suffix}"
        ctype_path = f"{KEYS_DIR}/{prefix}-ctype-{fw_suffix}"

        if not all(os.path.exists(p) for p in [key_path, iv_path, pub_path, priv_path, ctype_path]):
            print(f"Skipping {section}: missing files")
            continue

        # ctype is u8 in scetool, so take only first byte
        ctype_hex = read_binary(ctype_path)[:2]

        out.append(f"[{section}]")
        out.append(f"type=SELF")
        out.append(f"revision={revision}")
        out.append(f"version={version}")
        out.append(f"self_type={self_type}")
        out.append(f"key={read_binary(key_path)}")
        out.append(f"erk={read_binary(key_path)}")
        out.append(f"riv={read_binary(iv_path)}")
        out.append(f"pub={read_binary(pub_path)}")
        out.append(f"priv={read_binary(priv_path)}")
        out.append(f"ctype={ctype_hex}")
        out.append("")

    return "\n".join(out)

if __name__ == "__main__":
    content = build_keyfile()
    with open(OUTPUT_KEYS, "w") as f:
        f.write(content)
    print(f"Wrote {OUTPUT_KEYS}")
