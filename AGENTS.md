# Agent guide

This file will help you better understand this project.

## Real PS3 used to test it

PS3 Slim
CFW EvilNat 4.90
WebMAN UI hosted at http://192.168.1.128 - you're free to access it.

## Other

1. SDK will be provided by user in form of .7z file
2. You're free to run any commands, as long as those stay inside docker
3. Feel free to push plugin update to ps3 via webman ui and restart console
4. You have access to those git repositories:
```
b87450eb1c4ba8d74948f13b43d4c1eaa8ffa4f5 ext_sources/dualsense (heads/main) <-- this contains dualsense controller spec
```
5. Note all new findings in AGENTS.md
6. Treat this file as knowledgebase, you learnt something new = you add it there. You found that something is wrong = you fix it.
7. You're supposed to use opencode built-in todo list.
8. Make sure you put knowledge dump at the end of list.

## Project context: PS3xPAD

This is a PS3 VSH plugin that adds support for Xbox controllers (360, 360 Wireless, DualSense) to the PS3 via USB. The original was built with the leaked Sony SDK. The repo has a PSL1GHT port attempt and a Docker build system for the Sony SDK.

## Key findings from research

### PS3 VSH plugin build ecosystem (as of 2026-07)

**The community consensus is that VSH plugins require the leaked Sony SDK.** No fully open-source toolchain can produce a loadable VSH SPRX:

1. **PSL1GHT** - cannot produce PRX-format ELFs. Missing `-mprx` GCC flag, missing VSH export stubs (these are in webMAN-MOD's `lib/`), missing scetool. Even with `sprxlinker` and manual ELF header patches (`e_type=0xFFA4`, zero section headers), the output is rejected by Cobra/webMAN before `module_start` runs.

2. **scetool / OpenSCETool / oscetool** - all open-source clones segfault on PRX-format ELFs. The 3-segment PRX format produced by Sony SDK's `ppu-lv2-gcc -mprx` is fundamentally incompatible with these reverse-engineered tools which only handle standard ELF executables.

3. **webMAN-MOD** (the reference VSH plugin implementation) explicitly requires "Official PS3 SDK v400.001 leaked version" + "A compiled Scetool binary" + "ps3 keys". README explicitly says: "Psl1ght can't compile SPRX if I'm not mistaken" and "the Psl1ght project lacks one major feature: prx compilation. Without it, we will never completely get rid of the outdated official licensed toolchain & sdk".

4. **VSH export stubs** (`libvsh_export_stub.a`, `libstdc_export_stub.a`, `libpaf_export_stub.a`, etc.) are reverse-engineered by `3141card` and live in webMAN-MOD at `aldostools/webMAN-MOD/lib/`. These are the only open-source piece that can be used without the Sony SDK.

### Available SDK sources (as of 2026-07)

- **SDK 3.40** (PS3-DUPLEX): PS3.Full.3.40.SDK.PS3-DUPLEX.rar on psdevwiki - has Linux host tools including `ppu-lv2-gcc -mprx`
- **SDK 4.00** (YLoD leak): `/home/artur9010/ps3_sdk_400-PS3_4.00_SDK-YLoD.7z` (2.1GB) - has Windows host tools (`ppu-lv2-gcc.exe`, `ppu-lv2-prx-strip.exe`, `make_fself.exe`)
- **SDK 1.92** (FuxSony): `/home/artur9010/PS3_SDK_v1.92-FuxSony.7z` (629MB) - multi-part RAR inside 7z, likely old enough to include Linux host tools; copy into project `sdk/` before extraction/testing.
- **SDK 2.70**: `/home/artur9010/ps3_sdk_270.7z` (867MB) - contains `PS3_Toolchain_411-Win_270_001.zip`, Windows tools only; no native Linux toolchain found.
- **SDK 4.75** (Mizdx): `/home/artur9010/PS3 4.75 SDK Offline Installer-By Mizdx.rar` (7.2GB) - **Windows-only** for host tools, no Linux support
- **SDK 3.70** (TrueBlueGary): `/home/artur9010/PS3.3.70.SDK.By.TrueBlueGaryOPA.rar` (2GB) - has Windows host tools
- **SN Systems 2005**: `/home/artur9010/snsystems20050228.zip` - too old, predates `-mprx`

**Key insight: SDK ≤ 210.001 has Linux host tools. SDK > 210.001 is Windows-only.** Per psdevwiki: "Operating Systems Supported: Linux (until version 210.001)".

### Available keys sources (as of 2026-07)

- **codyps/ps3keys** (https://github.com/codyps/ps3keys): up to revision 3.56, converted to scetool format via `scripts/build_scetool_keys.py`
- **archive.midnightchannel.net**: `/SonyPS/PS3/Source Code/gitorious.ps3dev.net/4.55 Keys/4-55-keys-4-55-keys-master.tar.gz` - complete 4.55 key set including `appldr` with revision 001C (for `-2 04`) and 001D (for `-2 0A`), plus `curves`, `idps`, and all DRM keys. This is the proper scetool keyfile format.
- archive.midnightchannel.net also has: ps3tools (fail0verflow), Gitbrew source code, PS3 firmware PUPs, Gitorious archives, 4.40-4.50 keys, 4.55 keys, 4.60 keys, 4.65 keys, ps3keys repo, PSL1GHT SDK source, webMAN-MOD source, all VSH plugin source code (webftp_server, Cobra payload, multiman, IrisManager, etc.)

### Original PS3xPAD Makefile analysis (src/Makefile)

The original `src/Makefile` uses Sony SDK 4.00 with:
- `PPU_PRX_FLAGS = -mprx -mno-sn-ld -Os -ffunction-sections -fdata-sections -fno-builtin-printf -nodefaultlibs -std=gnu99`
- `PPU_PRX_STRIPFLAGS += --strip-debug --strip-section-header`
- `PPU_PRX_LDLIBS = -lusbd_stub -lio_stub -lfs_stub`
- `scetool -0 SELF -1 TRUE -s FALSE -2 04 -3 1070000052000001 -4 01000002 -5 APP -6 0003004000000000 -A 0001000000000000 -e xpad.prx xpad.sprx`

## Build system files

### Files created
- `Dockerfile` - open-source PSL1GHT build (doesn't produce valid VSH plugins)
- `Dockerfile.sony` - Sony SDK 4.00 build with Wine plus container-built `oscetool`; produces `src/xpad.sprx`
- `docker-compose.yml` - mounts SDK directory
- `scripts/build_scetool_keys.py` - converts codyps keys to scetool format
- `scripts/build_sony_docker.sh` - builds with Sony SDK via wine in Docker
- `scripts/build_prx_elf.py` - (dead end) tries to inject code into original ELF
- `scripts/rebuild_sprx.py` - (dead end) byte-patches original SPRX
- `ext_sources/ps3keys/` - codyps/ps3keys submodule (up to 3.56)
- `ext_sources/oscetool/` - spacemanspiff/OpenSCETool source, cloned for container-only debugging/builds
- `ext_sources/webman_lib/` - VSH export stubs from webMAN-MOD
- `Dockerfile.oscetool` - builds oscetool with debug symbols inside Ubuntu 24.04; do not build oscetool on host/NixOS
- `src/psl1ght_compat.h` - PSL1GHT compat layer (doesn't work for VSH)
- `src/Makefile.psl1ght` - PSL1GHT build (doesn't produce valid VSH plugins)
- `src/prx.ld` - custom linker script for PRX segments (doesn't work with PSL1GHT)

### Gitignore (excludes copyrighted content)
- `sdk/` - Sony SDK (leaked, copyrighted)
- `*.tar.gz`, `*.iso`, `*.pkg`, `*.rar` - SDK distributions
- `src/*.o`, `src/*.elf`, `src/*.sprx` - build artifacts
- `ext_sources/dualsense/.git` - submodule git internals
- `ext_sources/oscetool/.git` - cloned external repo internals

## Current state of the build

### What's working
- Use **podman**, not docker. User explicitly said not to run Wine on host.
- `ubuntu:26.04` base image with `dpkg --add-architecture i386` and `wine32:i386 wine64 wine` fixes the old Debian Bookworm Wine issue. Debian Bookworm Wine 8.0 created a prefix but `ppu-lv2-gcc.exe` silently produced no object files because the prefix had missing/empty `syswow64` support (`failed to open C:\windows\syswow64\rundll32.exe: c0000135`).
- With Ubuntu 26.04 Wine 10.0, Sony SDK 4.00 `ppu-lv2-gcc.exe` compiles `libc.c` and `main.c` successfully inside the container.
- `ubuntu:20.04` also works for the Wine compiler path and is a better base for old SDK tools. `ubuntu:18.04` is useful for SDK 1.92 `make_fself` because it still has `libstdc++5:i386`.
- `scripts/build_sony_docker.sh` was corrected to use SDK stub libraries from `$CELL_SDK/target/ppu/lib`, not `$CELL_SDK/host-win32/ppu/lib`. `libusbd_stub.a`, `libio_stub.a`, `libfs_stub.a`, `liblv2_stub.a`, `libc.a`, `crt1.o`, `prx_crt.o`, `prx32.xr`, and `elf64_lv2_prx.x` live there.
- A valid PRX now builds at `src/xpad.prx` (about 23K stripped) using Sony SDK 4.00 Windows GCC via Wine, SDK 4.00 headers/libs, and SDK 1.92 `samples/mk` makefile rules. Key trick: avoid Sony `libc.a` entirely and provide a tiny local `snprintf` in `src/libc.c`; linking full `libc.a` pulls CRT objects that trigger `.sys_proc_prx_param` fixup errors.
- `src/xpad.sprx` can be produced with SDK 1.92 Linux `make_fself` under `ubuntu:18.04` with `libstdc++5:i386`, but this is fake-signed and may not load as a VSH plugin.
- `oscetool` from `spacemanspiff/oscetool` builds in `Dockerfile.oscetool` and can sign/re-read `src/xpad.prx` when run with `-2 1C` and a data dir containing `keys` plus `ldr_curves` copied from `ext_sources/ps3keys/curves`. The earlier segfault was a missing `ldr_curves` file, not PRX parsing: `ec.c` indexed `loader_curves[0x09]` while `loader_curves` was NULL.
- `Dockerfile.sony` now builds `oscetool`, copies `ext_sources/ps3keys/curves` to `/data/ldr_curves`, builds `xpad.prx` through SDK 1.92 make fragments with SDK 4.00 Wine tools, strips it, then signs `xpad.sprx` with `oscetool -2 1C`. Verified by running `podman run --rm -v "$PWD:/work" ps3xpad-sony` and reading the output with `oscetool -i`: key revision `0x001C`, SELF type APP, ELF type SPRX, 3 program headers.
- Sony SDK PRX link flow is documented in `$CELL_SDK/target/ppu/lib/prxspec.4.1.1`: start files are `ecrti.o prx_crt.o crtbegin.o`, end files are `crtend.o ecrtn.o`, PRX prelink uses `prx32.xr`, and fixup uses `ppu-lv2-prx-fixup`.

### Current blocker
- Need PS3 validation of the `oscetool`-signed SPRX. OpenSCETool uses actual appldr revision `-2 1C`; original scetool shorthand `-2 04` still fails with `Could not find keyset for SELF`.
- Original scetool command metadata for comparison: `scetool -0 SELF -1 TRUE -s FALSE -2 04 -3 1070000052000001 -4 01000002 -5 APP -6 0003004000000000 -A 0001000000000000 -e src/xpad.prx src/xpad.sprx`.

### Next best build path
1. Keep the current no-`libc.a` PRX build path; it produces `src/xpad.prx` successfully.
2. Generate an `oscetool` SPRX in a container using `-2 1C` and `ldr_curves`, then test it on PS3/WebMAN.
3. If `oscetool` output fails on PS3, compare against original `scetool` output or find the original signer.

## How to test on PS3

1. Build `src/xpad.sprx` (currently failing, need to fix wine issue)
2. Copy to PS3: `curl -T src/xpad.sprx ftp://192.168.1.128/dev_hdd0/plugins/xpad.sprx`
3. Verify it's not loaded: `curl http://192.168.1.128/vshplugin.ps3mapi` (slot 2 should be NULL)
4. Load manually: `curl "http://192.168.1.128/loadprx.ps3?slot=2&prx=/dev_hdd0/plugins/xpad.sprx"`
5. Check it loaded: `curl http://192.168.1.128/vshplugin.ps3mapi` (slot 2 should show "XPADD" if it worked)
6. Add to boot plugins: `curl -T boot_plugins.txt ftp://192.168.1.128/dev_hdd0/boot_plugins.txt`
7. Or use webMAN UI to load it

## Important URLs

- WebMAN UI: http://192.168.1.128/
- VSH plugin slots: http://192.168.1.128/vshplugin.ps3mapi
- Manual plugin load: http://192.168.1.128/loadprx.ps3?slot=2&prx=/dev_hdd0/plugins/xpad.sprx
- Original release: /releases/ps3xpad_0.8.zip contains `xpad_vsh.sprx` (works on this PS3, proven)

## PS3 validation log

- 2026-07-10: `src/xpad.sprx` built by `Dockerfile.sony` with SDK 4.00 Wine tools + `oscetool -2 1C` was uploaded to `/dev_hdd0/plugins/xpad.sprx` and loaded via `http://192.168.1.128/loadprx.ps3?slot=2&prx=/dev_hdd0/plugins/xpad.sprx`. WebMAN VSH plugin page showed slot 2 loaded as `XPADD`, confirming Cobra/WebMAN accepts this signed SPRX.

## Files in /home/artur9010/ (SDK sources)

- `ps3_sdk_400-PS3_4.00_SDK-YLoD.7z` (2.1GB) - SDK 4.00 with PS3_Toolchain_411-Win_400_001.zip (Windows tools)
- `PS3_SDK_v1.92-FuxSony.7z` (629MB) - newly available SDK 1.92 archive; contains multi-part RAR files inside the 7z.
- `ps3_sdk_270.7z` (867MB) - SDK 2.70 archive; checked and contains Windows toolchain zip, not useful as a native Linux fallback.
- `PS3 4.75 SDK Offline Installer-By Mizdx.rar` (7.2GB) - SDK 4.75, Windows-only host tools
- `PS3.3.70.SDK.By.TrueBlueGaryOPA.rar` (2GB) - SDK 3.70, Windows host tools
- `snsystems20050228.zip` (49MB) - SN Systems 2005, too old

## Original release (working on PS3)

The original `xpad_vsh.sprx` from `/releases/ps3xpad_0.8.zip` works on this PS3 4.90 EvilNat CFW. It was built with:
- Sony SDK 4.00 (ppu-lv2-gcc -mprx, ppu-lv2-prx-strip --strip-section-header)
- Original scetool (Windows binary)
- Key revision 04 (appldr revision 001C)
- Auth ID 1070000052000001
- Vendor ID 01000002
- SELF type APP
- FW version 0003004000000000
- App version 0001000000000000

## Build approaches tried (all failed for full VSH signing)

1. **PSL1GHT only** - produces 8-segment ELF, rejected by Cobra/webMAN
2. **PSL1GHT + manual header patches + oscetool** - rejected by Cobra/webMAN; unrelated to current official-SDK PRX path
3. **PSL1GHT + manual header patches + make_fself** - make_fself doesn't do proper PRX signing
4. **OpenSCETool** - initial segfault was caused by missing `ldr_curves`; with `ext_sources/ps3keys/curves` supplied as `ldr_curves`, it signs and re-reads the official-SDK PRX using `-2 1C`
5. **Wine + Sony SDK 4.00 ppu-lv2-gcc.exe on Debian Bookworm** - failed because Wine 8.0 lacked working 32-bit/syswow64 support in the container; `ppu-lv2-gcc.exe` exited 0 but produced no `.o`.
6. **Wine + Sony SDK 4.00 on Ubuntu 26.04** - compile works with `wine32:i386`; current blocker is reproducing Sony SDK PRX linker/fixup flow correctly.

## Recommendation for the next agent

The most pragmatic next step is to produce `src/xpad.sprx` with container-built `oscetool` using actual key revision `-2 1C`, deploy it to PS3, and verify whether Cobra/webMAN loads it.
