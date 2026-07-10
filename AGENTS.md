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
- `ext_sources/webman_lib/libvshtask_export_stub.a` provides Sony SDK-compatible export stub for VSH notification (`vshtask_A02D46E7`). Linking this at build time is more reliable than the runtime `getNIDfunc` table scan, which depends on hardcoded VSH table addresses that differ across firmware versions.
- `Dockerfile.sony` now builds `oscetool`, copies `ext_sources/ps3keys/curves` to `/data/ldr_curves`, builds `xpad.prx` through SDK 1.92 make fragments with SDK 4.00 Wine tools, strips it, then signs `xpad.sprx` with `oscetool -2 1C`. Verified by running `podman run --rm -v "$PWD:/work" ps3xpad-sony` and reading the output with `oscetool -i`: key revision `0x001C`, SELF type APP, ELF type SPRX, 3 program headers.
- Sony SDK PRX link flow is documented in `$CELL_SDK/target/ppu/lib/prxspec.4.1.1`: start files are `ecrti.o prx_crt.o crtbegin.o`, end files are `crtend.o ecrtn.o`, PRX prelink uses `prx32.xr`, and fixup uses `ppu-lv2-prx-fixup`.

### Current blockers
- **PS3 crashed (boot failure)** — wrong LV2_OFFSET_ON_LV1 (0x8000000) passed to syscall 8 caused hypervisor fault. Console power-cycles at boot animation. Needs safe mode recovery.
- GTA V / Soul Calibur 5 don't receive input despite working on XMB and most games (Minecraft confirmed). Game detects controller (shows "controller disconnected" notification) but ignores button data. Root cause: `cellPadGetInfo2` returns `device_type[port] = 5` (LDD) instead of 0 (STANDARD), and GTA V explicitly checks this and skips input for non-standard controllers.

### What's working (DualSense-specific)
- DualSense controller works on PS3 4.90 EvilNat CFW via USB — XMB navigation, PS button, and all game buttons (cross, circle, square, triangle, D-pad, L1/R1/L2/R2, L3/R3, options, create, analog sticks, touchpad click).
- PS button works on XMB (via LDD `cellPadLddDataInsert` — XMB polls the LDD inserted data and routes PS button to the system menu).
- Key fix: added `cellUsbdControlTransfer` with SET_IDLE (bmRequestType=0x21, bRequest=0x0A, wValue=0) in `dualsense_set_config_done` before starting data transfers. Without this, the DualSense never sends interrupt IN data.
- VSH notifications now work via Sony SDK import stub (`libvshtask_export_stub.a` from webMAN-MOD): `show_msg` calls `vshtask_A02D46E7` directly, resolved at PRX load time instead of the runtime `getNIDfunc` table scan.
- Messages from USB callback context (attach/detach notifications) are queued in a ring buffer and flushed from the polling thread (`xpadd_thread`) where `vshtask_A02D46E7` context is valid.
- **HID interface scan fix:** `dualsense_attach` now scans for `bInterfaceClass == 0x03` (HID) instead of always using the first interface. The DualSense has 4 interfaces (0-2 audio, 3 HID); previously the endpoint scan picked the isochronous IN endpoint (0x82, 196 bytes) from the audio interface instead of the HID interrupt IN endpoint (0x84, 64 bytes).
- **Interrupt endpoint filter:** endpoint scan also checks `bmAttributes == 0x03` (interrupt type) to avoid matching isochronous endpoints.
- **Multi-interface dedup:** `dualsense_attach` checks for an existing `XTYPE_DUALSENSE` unit in `XPAD.con_unit` before registering — prevents duplicate LDD registration when USB stack calls attach for multiple interfaces of the same device.

### Known issues
- Oscetool outputs benign warnings `[*] Error: unknown SELF type 'SEVEN'` and `[*] Warning: Could not load loader curves` during signing; the SPRX still loads fine on PS3.
- DualSense output reports (rumble) are not yet implemented — `dualsense_set_rumble` is a stub returning CELL_OK.
- DualSense LED is now implemented (green on connect via interrupt OUT pipe).

## How to test on PS3

1. Build `src/xpad.sprx` via `podman run --rm -v "$PWD:/work" ps3xpad-sony` (or `Dockerfile.sony`)
2. Copy to PS3: `curl -T src/xpad.sprx ftp://192.168.1.128/dev_hdd0/plugins/xpad.sprx`
3. Reboot PS3 via `curl http://192.168.1.128/restart.ps3` (plugin reload via webMAN doesn't fully reinitialize — reboot required)
4. After reboot, verify it loaded: `curl http://192.168.1.128/vshplugin.ps3mapi` (slot 2 should show "XPADD")
5. Add to boot plugins: `curl -T boot_plugins.txt ftp://192.168.1.128/dev_hdd0/boot_plugins.txt`

## Important URLs

- WebMAN UI: http://192.168.1.128/
- VSH plugin slots: http://192.168.1.128/vshplugin.ps3mapi
- Manual plugin load: http://192.168.1.128/loadprx.ps3?slot=2&prx=/dev_hdd0/plugins/xpad.sprx
- Original release: /releases/ps3xpad_0.8.zip contains `xpad_vsh.sprx` (works on this PS3, proven)

## PS3 validation log

- 2026-07-10: `src/xpad.sprx` built by `Dockerfile.sony` with SDK 4.00 Wine tools + `oscetool -2 1C` was uploaded to `/dev_hdd0/plugins/xpad.sprx` and loaded via `http://192.168.1.128/loadprx.ps3?slot=2&prx=/dev_hdd0/plugins/xpad.sprx`. WebMAN VSH plugin page showed slot 2 loaded as `XPADD`, confirming Cobra/WebMAN accepts this signed SPRX.
- 2026-07-10: **DualSense input confirmed working** after SET_IDLE fix. Added `cellUsbdControlTransfer` with HID request 0x0A (SET_IDLE) in init chain to wake up DualSense HID data streaming. Without SET_IDLE, the DualSense never sends interrupt IN data. Root cause: PS3 USB stack doesn't send HID class requests when an LDD replaces the HID driver.
- 2026-07-10: **DualSense XMB navigation and PS button working** after HID interface scan fix. Root cause: `dualsense_attach` always scanned the first USB interface (audio, class 0x01) instead of the HID interface (class 0x03), picking the isochronous IN endpoint (0x82, 196 bytes) from the audio streaming interface instead of the HID interrupt IN endpoint (0x84, 64 bytes). Fix: scan for `bInterfaceClass == 0x03`, also filter `bmAttributes == 0x03` to ensure interrupt-type endpoints. Also fixed: notification ring buffer for USB callback context messages, duplicate LDD registration guard via `XTYPE_DUALSENSE` check.
- 2026-07-10: **Notifications from USB attach/detach callbacks working** via ring buffer queued in callback context and flushed from polling thread.

- 2026-07-10: **Game module built and PS3MAPI auto-loading implemented**. `xpad_game.sprx` (2263 bytes) registers LDD from game context via syscall 574. VSH module scans all processes every ~2.5s, loads game module into any non-system process. Uploaded and rebooted PS3 — `XPADD` loaded in slot 2.
- 2026-07-10: **PS3MAPI causes kernel panic on EvilNat 4.90** — calling syscall 8 with opcode 0x7777 (any PS3MAPI sub-opcode) freezes console. Hard reset required. Game module reduced to no-op. `addr=0` in syscall 574 also breaks LDD registration (needs `5`).
- 2026-07-10: **GTA V diagnosis completed**. LDD controller confirmed on port 0. GTA V detects controller (disconnect notification works) but ignores button data. `data.len=64` and `button[1]=0xFF` tested — no effect. Root cause: `device_type = 5` (LDD) in `cellPadGetInfo2`. Game need compatibility hooks installed in its process.

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

Key finding: DualSense requires SET_IDLE control transfer (HID bmRequestType=0x21, bRequest=0x0A) before interrupt IN transfers will stream data. The PS3 USB stack (unlike Linux/macOS) does not automatically send HID class requests when an LDD replaces the built-in driver — the LDD must explicitly send SET_IDLE to wake up the DualSense HID endpoint.

Key finding: DualSense has 4 USB interfaces (0-2 audio, 3 HID). The LDD `attach` callback is called for each interface the LDD claims (per-device VID/PID match). The original `cellUsbdScanStaticDescriptor` pattern of "start from first interface" only works for single-interface devices. For multi-interface devices, you must scan for the correct interface class (`bInterfaceClass == 0x03` for HID) and filter endpoint type (`bmAttributes == 0x03` for interrupt). Also guard duplicate LDD registrations by checking for existing `XTYPE_DUALSENSE` in `XPAD.con_unit`.

## Game compatibility research (2026-07-10)

### Why GTA V and Soul Calibur 5 don't get DualSense input

**Bottom line:** LDD data IS visible to game processes (confirmed: GTA V shows "controller disconnected" notification when unplugging DualSense). The LDD controller is on port 0 (confirmed via notification "XPAD ldd port unit:0 port:0"). Input data is inserted correctly (len=64, button[1]=0xFF, all appropriate flags set). GTA V **explicitly checks `device_type[port]`** in `cellPadGetInfo2` — LDD controllers report `device_type = 5` (CELL_PAD_DEV_TYPE_LDD) instead of `0` (STANDARD). GTA V skips input for non-standard controllers.

**Confirmed facts (2026-07-10 session):**

1. **LDD port is port 0** — `cellPadLddGetPortNo` returns 0. "unit:0 port:0" from notification.
2. **GTA V detects controller** — unplugging DualSense shows "controller disconnected" overlay in GTA V. This means `cellPadGetInfo2.port_status[0]` correctly reports CONNECTED, and game monitors port status.
3. **GTA V ignores button data** — no response to any button presses or analog stick movement.
4. **addr=5 is REQUIRED in syscall 574** — `addr=0` breaks LDD registration entirely (no "ldd registered" notification, no controller on XMB). `addr=5` is a type flag, not a port number.
5. **Capability flags (0xFFFF→0x1F) didn't fix GTA V** — tested, no effect.
6. **data.len=24 vs data.len=64, button[1]=0xFF didn't fix GTA V** — tested together, no effect.
7. **PS3MAPI syscall 8 with 0x7777 causes kernel panic** — even though Cobra menu says "syscall 8 is enabled", calling PS3MAPI opcodes (GET_ALL_PROC_PID, LOAD_PROC_MODULE) locks up the PS3 (power button unresponsive, requires hard reset).

**Root cause hypothesis:**
`cellPadGetInfo2` returns:
```c
device_type[port] = CELL_PAD_DEV_TYPE_LDD  // = 5
```
GTA V's input processing code checks `device_type[port]` and rejects non-STANDARD (type != 0) controllers. The game sees the controller as connected (port_status) but skips input processing because it's not a standard DS3.

**Fix requirements:**
Either:
- **PS3MAPI**: inject game module into game process via Cobra syscall 8 → blocked by kernel panic
- **LV2 kernel patching**: modify kernel's `device_type` for LDD controllers → needs lv2_poke
- **EBOOT patching**: patch game's `cellPadGetInfo2` call to accept type 5 → last resort, requires user action

**How PS3MAPI crash manifests:**
Starting GTA V triggers `check_and_load_game_module()` after ~2.5s. The PS3MAPI calls cause immediate LV2 kernel panic: black screen, unresponsive power button, hard reset required. This happens even though "Cobra syscall 8" is reported as enabled. PS3MAPI sub-opcodes (0x7777 namespace) may be separately blocked or require an access key (`ps3mapi_enable_access_syscall8`). "Check Syscall 8" in Cobra menu only validates that the syscall 8 handler exists, not that PS3MAPI opcodes within it work.

**Alternative write mechanisms to investigate (UPDATED — see session log part 2):**
EVILNAT 4.90 syscall 6/7 are PS3HEN-only (NOT for CFW). syscall 8 = LV1 peek (CFW), syscall 9 = LV1 poke (CFW). Both require correct LV2_OFFSET_ON_LV1. **Do NOT test syscall 8/9 from VSH plugin — hypervisor fault crashes whole system.** syscall 15/35 unknown.

**CellPadInfo2 structure** (from Sony SDK pad_codes.h):
```c
typedef struct CellPadInfo2 {
    uint32_t max_connect;                     // 7
    uint32_t now_connect;                     // current connected count
    uint32_t system_info;
    uint32_t port_status[CELL_PAD_MAX_PORT_NUM];  // 7 ports
    uint32_t port_setting[CELL_PAD_MAX_PORT_NUM];
    uint32_t device_capability[CELL_PAD_MAX_PORT_NUM];
    uint32_t device_type[CELL_PAD_MAX_PORT_NUM];  // 0=STANDARD, 5=LDD
} CellPadInfo2;
```

**CellPadData format verification** (from Sony SDK):
```c
typedef struct CellPadData {
    int32_t len;            // Correct: 24 or 64
    uint16_t button[64];
} CellPadData;
// button[0] = PS button flag (CELL_PAD_CTRL_LDD_PS = 1<<0)
// button[2] = DIGITAL1: D-pad + Start/Select/L3/R3
// button[3] = DIGITAL2: Face + L1/R1/L2/R2
// button[4-7] = Analog sticks (8-bit, center 0x80)
// button[8-19] = Pressure values (0x00-0xFF)
// button[20-23] = Motion sensors (0x0200 default)
```

**Key research findings:**

1. **LDD data IS visible to game processes** — GTA V detects controller connect/disconnect via `cellPadGetInfo2.port_status`. Data format is correct. The block is at the application level.

2. **Original v0.8 two-module architecture:** `xpad_vsh.sprx` (VSH process) + `xpad_game.sprx` (loaded into game process via PS3MAPI). The game module was loaded manually by pressing START+SELECT+R3 in-game, or automatically via auto-detect. Without it, GTA V and Soul Calibur IV/V had no input.

3. **Compatibility mode** (START+SELECT+DPAD_UP) installs hooks in the game process — requires DEX kernel + debug EBOOT. Fixes GTA V, RDR, SC4, SC5 specifically. The hooks patch `cellPadGetData`/`cellPadGetInfo2` in the game process to accept LDD controllers.

4. **Memory constraint:** RouLetteVshMenu research states AAA games (GTA V, RDR) have no free memory for injected SPRX — `GamePatching::StartSprx` will not work. The workaround is patching the EBOOT directly.

5. **PS3MAPI crash confirmed** — calling syscall 8 with opcode 0x7777 and any PS3MAPI sub-opcode causes LV2 kernel panic on this EvilNat 4.90 setup, even with "Cobra syscall 8" enabled.

### SDK capability defines

From `PS3DK/sdk/include/cell/pad.h`:
```c
#define CELL_PAD_CAPABILITY_PS3_CONFORMITY   (1 << 0)  // 0x01
#define CELL_PAD_CAPABILITY_PRESS_MODE       (1 << 1)  // 0x02
#define CELL_PAD_CAPABILITY_SENSOR_MODE      (1 << 2)  // 0x04
#define CELL_PAD_CAPABILITY_HP_ANALOG_STICK  (1 << 3)  // 0x08
#define CELL_PAD_CAPABILITY_ACTUATOR         (1 << 4)  // 0x10
#define CELL_PAD_DEV_TYPE_STANDARD           0
#define CELL_PAD_DEV_TYPE_LDD                5
```

### Syscall signatures (from PSDevWiki)

- Syscall 572: `sys_pad_ldd_data_insert(int32_t handle, cellpaddata* data)` — non-debug version
- Syscall 573: `sys_pad_dbg_ldd_set_data_insert_mode(int32_t handle, 0x100, uint32_t* mode, 4)` — addr=0x100 always
- Syscall 574: `sys_pad_ldd_register_controller/sys_pad_dbg_ldd_register_controller(uint8_t[0x114], int32_t* out, 5, uint32_t device_capability<<1)`
- Syscall 575: `sys_pad_ldd_get_port_no(int32_t handle)`

All available on DECR/DEX/CEX.

### PS3MAPI calling convention (syscall 8, opcode 0x7777)

```c
// Get all process PIDs: pid_list is uint32_t[16] output array
system_call_3(8, 0x7777, PS3MAPI_OPCODE_GET_ALL_PROC_PID, (uint64_t)(uint32_t)pid_list);

// Get process name by PID: name is char[32] output buffer
system_call_4(8, 0x7777, PS3MAPI_OPCODE_GET_PROC_NAME_BY_PID, (uint64_t)pid, (uint64_t)(uint32_t)name);

// Load module into process: path is string in calling process memory
system_call_6(8, 0x7777, PS3MAPI_OPCODE_LOAD_PROC_MODULE, (uint64_t)pid, (uint64_t)(uint32_t)path, (uint64_t)(uint32_t)arg, (uint64_t)arg_size);
```

PS3MAPI opcodes:
- `PS3MAPI_OPCODE_GET_ALL_PROC_PID` = 0x0021
- `PS3MAPI_OPCODE_GET_PROC_NAME_BY_PID` = 0x0022
- `PS3MAPI_OPCODE_LOAD_PROC_MODULE` = 0x0044

### Approach priority for fixing game input

1. ~~Fix capability flags (0xFFFF → 0x1F)~~ — tested, no effect on GTA V
2. ~~Fix addr=5 parameter in syscall 574~~ — tested addr=0, breaks LDD entirely. addr=5 is required.
3. ~~Fix data.len and button[1] default~~ — tested len=64 and button[1]=0xFF, no effect on GTA V
4. **Build xpad_game.sprx** — second SPRX loaded into game process via PS3MAPI Cobra syscall 8. Implemented 2026-07-10: VSH module auto-detects game processes every ~2.5s and loads xpad_game.sprx into them. Game module registers LDD from game context via `cellPadDbgLddRegisterController` syscall 574. **BLOCKED**: PS3MAPI syscall 8 with opcode 0x7777 causes kernel panic on this CFW.
5. **LV2 kernel write** — find alternative lv2_poke mechanism (syscall 6, 9, 10, 15) not going through PS3MAPI. Use to modify kernel's `device_type` from 5→0 for LDD controllers.
6. **Compatibility mode** — hooks in game process, requires DEX + debug EBOOT (last resort)

### PS3MAPI auto-loading implementation (2026-07-10)

The VSH module (`main.c`) now includes `check_and_load_game_module()` which:
1. Gets all process PIDs via `sys8_ps3mapi(PS3MAPI_OPCODE_GET_ALL_PROC_PID, ...)`
2. For each PID, gets its name via `sys8_ps3mapi(PS3MAPI_OPCODE_GET_PROC_NAME_BY_PID, ...)`
3. Skips system processes (`vsh`, `VSH`, `sys_` prefixes)
4. Loads `xpad_game.sprx` via `sys8_ps3mapi(PS3MAPI_OPCODE_LOAD_PROC_MODULE, ...)`
5. Tracks loaded PIDs in `loaded_pids[]` array to avoid re-loading
6. Called from `xpadd_thread` every 256 iterations (~2.5s)

PS3MAPI syscall requires Cobra/CFW with syscall 8 enabled. EvilNat 4.90 has this.

**CRASH CONFIRMED (2026-07-10):** Any PS3MAPI sub-opcode (0x0021, 0x0022, 0x0044) via syscall 8 with 0x7777 causes LV2 kernel panic on this EvilNat 4.90 setup. "Cobra syscall 8 enabled" only means the syscall 8 handler exists — PS3MAPI within it may be separately blocked or need `ps3mapi_enable_access_syscall8(key)`. The key is unknown. DO NOT attempt PS3MAPI calls from VSH without a working access mechanism.

**Alternative:** EvilNat 4.90 has "Opcode to create CFW Syscalls (6, 7, 8, 9, 10, 11, 15, 35)". On old PL3-based CFWs, syscall 16 = peek, syscall 20 = poke. On this setup, syscall 7 = lv2_peek (works). Need to find working lv2_poke (try syscall 6, 9, 10, 15, or 20).

Keywords: xpad_game.sprx built with `-zgenprx -zgenstub` (auto-generates import stubs), linked with `libio_stub.a` and `libc.ppu.o` (for memset).

## Session log: 2026-07-10 (part 2 — after GTA V diagnosis)

### CFW syscall map discovery (from webMAN-MOD `peek_poke.h` source)

```c
// System call 6 - peek (PS3HEN only)
// System call 7 - poke (PS3HEN only)
// System call 8 - lv1 peek (CFW: peek LV1/LV2 memory via LV1 hypervisor)
// System call 9 - lv1 poke (CFW: write LV1/LV2 memory via LV1 hypervisor)
// System call 11 - lv1 peek (Cobra alternate, same as syscall 8)
```

Key insight from `peek_poke.c` in webMAN-MOD:
- LV2 access on CFW goes through **LV1 hypervisor**, not directly
- `lv1_peekd(addr + 0x8000000ULL)` — LV1 offset for LV2 memory
- Cobra syscall 8 wraps: `syscall 8(addr)` → hypervisor call
- Cobra syscall 9 wraps: `syscall 9(addr, value)` → hypervisor call
- **Syscall 6/7 are NOT for CFW** — they're PS3HEN-only (different HW)

### LV2_OFFSET_ON_LV1 crash (2026-07-10)

- On 4.76+ CFW, `LV2_OFFSET_ON_LV1 = 0x8000000` (from webMAN-MOD `peek_poke.h`)
- **This offset is WRONG for 4.90 EvilNat** (kernel ported from 4.84 DEX)
- Passing wrong LV2 offset to syscall 8 causes hypervisor to map invalid memory → **hypervisor fault**
- Hypervisor fault = unrecoverable: PS3 hangs at boot animation, power button unresponsive
- PS3 currently crashed, requires safe mode recovery (hold power → second beep → Restore PS3 System / Rebuild File System)
- **Do NOT test syscall 8/9 from VSH plugin without confirmed correct LV2_OFFSET_ON_LV1 for 4.90 EvilNat**

### PS3MAPI crash root cause (from Cobra 8.4 stage2 source analysis)

Cobra 8.4 stage2 (`src/sys8.c`):
```c
static int ps3mapi_partial_disable_syscall8 = 0;
// 0 = normal operation
// 1 = disable code injection / process ops
// 2 = disable all except enable/disable access
// 3+ = all PS3MAPI ops return ENOSYS (disabled)

int sys8_ps3mapi_handler(...) {
    if (ps3mapi_partial_disable_syscall8 >= 3) return ENOSYS;
    // ... process PS3MAPI opcodes
}
```

**webMAN-MOD defaults to DISABLED (`ps3mapi_partial_disable_syscall8 >= 3`)** for PSN safety. The webMAN setup thread sets this:

```c
// webMAN-MOD: sys8.c or similar setup code
void setup_ps3mapi_security() {
    // Default: disable PS3MAPI for PSN safety
    ps3mapi_partial_disable_syscall8 = 3;  // All ops blocked
}
```

When PS3MAPI opcodes return `ENOSYS`, the Cobra payload's path may not clean up properly → **kernel panic**. This explains why:
- "Cobra syscall 8 enabled" shows as true (syscall 8 handler exists)
- Our `0x7777` dispatched calls hit the ENOSYS path
- The Cobra stage2 ENOSYS return path has a bug/uninitialized state → kernel panic
- Fix: call `ps3mapi_enable_access_syscall8(key)` first, but `ps3mapi_key` is set at compile time in Cobra payload and unknown to us

**`ps3mapi_key` default = 0**, `ps3mapi_access_granted = 1` (from Cobra 8.4 source). Access is granted by default when key is 0. Not the cause of crash.

**webMAN-MOD `peek_poke.h`** also reveals: `DEBUG_MEM` conditional enables HTTP peek/poke LV2 commands via webMAN (`/peek.ps3` and `/poke.ps3`). These require `Debug Settings` → `Memory Access` enabled on CFW. May or may not be available on EvilNat 4.90.

### Updated: Alternative write mechanisms

Corrected CFW syscall map:
- **syscall 6** = PS3HEN-only LV2 peek (NOT for CFW)
- **syscall 7** = PS3HEN-only LV2 poke (NOT for CFW)
- **syscall 8** = LV1 peek (CFW: read LV1/LV2 via hypervisor, addr + LV2_OFFSET_ON_LV1)
- **syscall 9** = LV1 poke (CFW: write to LV1/LV2 via hypervisor, addr + LV2_OFFSET_ON_LV1, value)
- **syscall 11** = LV1 peek (Cobra alternate, same as syscall 8)
- **syscall 15/35** = unknown, possibly PSP emu/other

LV2 memory access formula:
```c
// Read 64-bit from LV2 address
uint64_t lv2_read64(uint64_t lv2_addr) {
    return syscall_1(8, lv2_addr + LV2_OFFSET_ON_LV1);
}

// Write 64-bit to LV2 address
void lv2_write64(uint64_t lv2_addr, uint64_t value) {
    syscall_2(9, lv2_addr + LV2_OFFSET_ON_LV1, value);
}
```

**CRITICAL: LV2_OFFSET_ON_LV1 must be correct for the specific CFW version, or hypervisor fault = unrecoverable crash.** Known values:
- 4.76+: `0x8000000`
- 4.84 DEX (EvilNat 4.90 base): **UNKNOWN** — likely different, possibly `0x10000000` or region-specific
- Finding correct offset: dump a known LV2 value (e.g., syscall table entry) via USB ICD or read LV1 mapping table

### Updated: Current blocker

PS3 is currently **crashed** — powered off after hypervisor fault from wrong LV2 offset test. Will not boot past animation. Needs safe mode recovery via console front panel.

### Safe mode recovery procedure

1. Turn PS3 off completely (hold power button until beep → power off)
2. Hold power button until second beep (~5 seconds) → Safe Mode menu
3. Options:
   - Option 3: Restore File System (non-destructive, fixes file system errors)
   - Option 4: Rebuild Database (non-destructive, may remove webMAN plugin cache)
   - Option 6: Restore PS3 System (factory reset — DESTRUCTIVE, last resort)
4. Try Options 3 and 4 first before Option 6
5. After recovery, clear plugin cache: `rm /dev_hdd0/tmp/*.sprx` via FTP
6. Check `boot_plugins.txt` for safe boot entries

### What would have caused the crash

The hypervisor (LV1) maps LV2 memory at an offset that differs per CFW version. `0x8000000` is the offset for 4.76+ retail CFW. EvilNat 4.90 uses a kernel ported from 4.84 DEX, which likely has a different LV2→LV1 mapping. Passing an unmapped address to `lv1_peekd` raises an exception in the hypervisor that CFW syscall 8 cannot handle → system lockup.

### Key learning: no syscall 8/9 test from VSH plugin

Never test syscall 8/9 from within a VSH plugin running on the target PS3. A wrong LV2 offset = hypervisor fault = permanently frozen console requiring hard power cycle + safe mode recovery. Test LV1/LV2 access from a minimal standalone self-contained test payload first (loaded fresh each boot, no persistence).

## Session: 2026-07-10 (part 3 — device_type patch research)

### PS3 state update

- PS3 recovered from previous crash
- Now running **4.93 CEX EvilNat Cobra 8.5** on clean disk
- DualShock 3 and SATA adapter available for restoration if needed
- webMAN MOD 1.47.48 [Rebug-PS3MAPI] running, supports `/peek.lv2` and `/poke.lv2`

### LV2_OFFSET_ON_LV1 for 4.93 EvilNat — CONFIRMED CORRECT

**Key finding from webMAN-MOD issue #1338:**
> "LV1 and LV2 offsets are the same from 4.75 to 4.93, except 4.80 & 4.90 which both use the same offsets."

So for 4.93 EvilNat CEX: `LV2_OFFSET_ON_LV1 = 0x8000000` is correct.

The previous crash on 4.90 EvilNat was specific to that version (kernel ported from 4.84 DEX with different mapping). 4.93 uses the standard mapping.

**Proof — LV2 peek test:**
- `curl http://192.168.1.128/peek.lv2?0x2ED818` returned `43 45 58 00 00 00 00 00` ("CEX\0\0\0\0\0") — exact value expected from webMAN-MOD's `detect_firmware` function
- `curl http://192.168.1.128/peek.lv2?0x2FCB68` returned firmware build date `2026/01/08 15:07:17` — confirms 4.93
- This proves syscall 8 (LV1 peek) with `LV2_OFFSET_ON_LV1 = 0x8000000` works correctly on this setup

### webMAN MOD peek/poke endpoints

From `webMAN-MOD/include/ps3mapi/peek_poke.h`:

```c
#define SC_PEEK_LV2 (6)
#define SC_POKE_LV2 (7)
#define SC_PEEK_LV1 (8)    // CFW: reads LV2 when addr + LV2_OFFSET_ON_LV1
#define SC_POKE_LV1 (9)    // CFW: writes LV2 when addr + LV2_OFFSET_ON_LV1
#define SC_PEEK_LV1_COBRA (11)

#define PS3MAPI_OPCODE_LV2_PEEK 0x1006
#define PS3MAPI_OPCODE_LV2_POKE 0x1007
#define PS3MAPI_OPCODE_LV1_PEEK 0x1008
#define PS3MAPI_OPCODE_LV1_POKE 0x1009
#define SYSCALL8_OPCODE_PS3MAPI 0x7777

// LV2 peek via CFW syscall (safe, no PS3MAPI):
static u64 lv2_peek_cfw(u64 addr) {
    system_call_1(SC_PEEK_LV1, addr + LV2_OFFSET_ON_LV1);
    return (u64) p1;
}

// LV2 poke via CFW syscall (safe, no PS3MAPI):
static void lv2_poke_cfw(u64 addr, u64 value) {
    system_call_2(SC_POKE_LV1, addr + LV2_OFFSET_ON_LV1, value);
}
```

**Key insight:** Use CFW syscalls 8/9 directly (not PS3MAPI opcodes) to avoid the kernel panic issue. PS3MAPI goes through syscall 8 with opcode 0x7777 which can return ENOSYS → kernel panic. Direct syscall 8/9 with LV2_OFFSET_ON_LV1 works reliably.

### PUP file available

- Path: `/home/artur9010/Desktop/PS3UPDAT.PUP` (216069372 bytes = 216MB)
- Firmware: 4.93

### Available tools

- **scetool** binary exists at `/home/artur9010/.local/share/containers/storage/overlay/6a297cc9cf78d448f2345feacb41239e9a17dea4e60a9903c43ac544aa87af70/diff/opt/scetool/scetool` — but won't run on NixOS host (dynamic linking issue)
- **oscetool** source at `ext_sources/oscetool/` — buildable via `Dockerfile.oscetool` with podman
- **ps3keys** at `ext_sources/ps3keys/` — only up to revision 3.56
- **podman 5.8.2** available for container builds
- **scetool keys** (ps3keys format): only up to 3.56 — for 4.93 decryption, need 4.55+ keys from archive.midnightchannel.net

### Why PUP decryption may not be needed

The `device_type[]` array is a runtime variable in LV2 memory. We can find it directly by searching live LV2 memory without decrypting lv2_kernel.self:

1. When DualSense is connected and plugin is loaded:
   - `device_type[0]` = 5 (our LDD controller)
   - `device_type[1..6]` = 0 (no other controllers)

2. Search LV2 for the byte pattern `05 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00` (7 × u32 = 28 bytes)

3. Use webMAN MOD's `/find.lv2` to locate the array

4. Verify by reading nearby fields (port_status, device_capability should be adjacent)

### Plan: Patch device_type=5→0 via LV2 poke

**Goal:** Make GTA V and other games accept DualSense as standard controller (device_type=0 instead of 5)

**Steps:**
1. Connect DualSense, load current `src/xpad.sprx` (registers LDD, sets device_type[0]=5)
2. Use `/find.lv2` to locate `device_type[7]` array in LV2 memory
3. Verify address by reading surrounding data (should be pad manager struct)
4. Test poke: `/poke.lv2?<addr>=0` then `/peek.lv2?<addr>` to verify
5. Load GTA V, test if controller input works
6. If yes, automate in plugin: add LV2 poke after LDD registration

**Plugin automation code (to add to `register_ldd_controller` in src/main.c):**
```c
// Patch device_type from 5 to 0 so games accept our controller
// Address determined at runtime via /find.lv2, hardcoded here
// LV2_OFFSET_ON_LV1 = 0x8000000 for 4.93 EvilNat CEX
#define DEVICE_TYPE_ARRAY_ADDR 0x????  // TODO: find via /find.lv2
system_call_2(9, DEVICE_TYPE_ARRAY_ADDR + 0x8000000ULL, 0);
```

**Risks:**
- Wrong address → crash or no effect (mitigated: read before write, verify change)
- device_type gets reset by kernel after poke (needs test)
- GTA V may check other fields beyond device_type (vendor_id, product_id, capability)

**Fallback if device_type patch doesn't fix GTA V:**
- Also patch `vendor_id` and `product_id` to match DualShock 3 (0x054c/0x0268)
- Patch `device_capability` to match standard DS3

### Approach rejected: "Native HID + only add what's missing"

User suggested: let native HID driver handle basic controls, only add PS button/rumble/gyro via LDD.

**Why impossible:**
- PS3 USB stack is winner-takes-all: LDD replaces native driver for the device
- `sys_usbd_open_pipe` (RPCS3 source) only works on devices in `handled_devices` map (LDD-owned)
- `cellUsbdGetDeviceList` only returns LDD-owned devices
- No documented path from VSH plugin to open pipes on a native-driver-owned device
- PL3 kernel module uses kernel-level USB functions not available to user-space plugins

**Conclusion:** Must use LDD to access USB. Cannot coexist with native HID driver.

### webMAN MOD endpoints available

- `http://192.168.1.128/peek.lv2?<addr>` — read 256 bytes at LV2 address
- `http://192.168.1.128/poke.lv2?<addr>=<value>` — write 64-bit value at LV2 address
- `http://192.168.1.128/find.lv2?<pattern>` — search LV2 memory for pattern
- `http://192.168.1.128/peek.lv1?<addr>` — read LV1 memory
- `http://192.168.1.128/poke.lv1?<addr>=<value>` — write LV1 memory
- `http://192.168.1.128/cpursx.ps3` — system info (firmware, temp, etc.)
- `http://192.168.1.128/vshplugin.ps3mapi` — VSH plugin slots
- `http://192.168.1.128/loadprx.ps3?slot=<n>&prx=<path>` — manually load PRX

### Session 2026-07-10 (part 3) — DualShock 3 verification

- Tested with DualShock 3 plugged in — works natively without plugin (basic controls)
- Confirms native HID driver handles DS3 correctly
- DualSense also handled by native HID driver for basic controls (buttons, sticks)
- Only missing: PS button, rumble, gyroscope (vendor-specific HID usages)

### Current status

- Waiting for user to download GTA V before testing device_type patch
- User has DualShock 3 and SATA adapter as fallback if PS3 crashes
- webMAN MOD endpoints sometimes timeout under load — may need retries

### Plugin loading policy (2026-07-10)

- **DO NOT add xpad.sprx to boot_plugins.txt** — plugin is loaded manually only
- Manual load via `curl http://192.168.1.128/loadprx.ps3?slot=2&prx=/dev_hdd0/plugins/xpad.sprx`
- Reason: allows quick unload/load cycle during testing without reboot, avoids persistent state issues

## Session: 2026-07-11 — Device type patch, runtime scanner

### webMAN build: 1.47.48q MOD [Rebug-PS3MAPI]

- Standard build, **NO `DEBUG_MEM`** support
- Available endpoints: `/peek.lv2`, `/poke.lv2`, `/find.lv2`, `/cpursx.ps3`, `/vshplugin.ps3mapi`
- **NOT available**: `/dump.ps3?lv2` (returns 404 — needs `DEBUG_MEM`)
- PS3MAPI (syscall 8) **works fine** on 4.93 EvilNat 4.93 (was a previous 4.90 issue)
- Cobra 8.5 + EvilNat 4.93 confirmed

### CRITICAL LESSON: Don't hammer webMAN with HTTP scans

- **Heavy `/peek.lv2` loops or `/find.lv2` over LV2 (8MB) wedges webMAN**
- Symptom: PS3 itself is fine, but webMAN stops responding (ping OK, HTTP times out)
- console "died" / power-cycled twice during this session — actually webMAN wedged, not console death
- Recovery: just power-cycle (webMAN restarts), no need for safe mode
- **Solution for any LV2 scanning**: do it INSIDE a VSH plugin via direct `system_call_1(8, addr + 0x8000000)` calls — no HTTP overhead, fast, doesn't wedge webMAN

### Plugin LV2 scanner (2026-07-11)

Added runtime LV2 scanner to `src/main.c`. After LDD registration succeeds, scans `0x100000 - 0x1000000` (16MB) looking for `device_type[7]` array pattern: `[05 00 00 00] [00 00 00 00] ×6`. Verifies by reading `addr - 96` for `max_connect = 7` and `now_connect >= 1`.

**Result: "XPAD device_type[] NOT FOUND"** — no candidates matching the pattern found in 16MB of LV2.

### Root cause: device_type not stored as expected

The `device_type` field is **not** a simple `u32[7]` array in LV2 static memory. Looking at RPCS3's `Pad` class:
```cpp
struct Pad {
    bool ldd;  // <-- this is what determines device_type
    u32 m_device_type;  // <-- set by kernel based on ldd flag
    ...
};
```

Each controller has its own `Pad` object with `m_device_type = 5` (LDD) or `0` (standard). `cellPadGetInfo2` reads from these per-controller objects, not from a contiguous array.

The kernel computes `device_type` at query time based on whether the controller is an LDD. It's NOT a settable user value — it's an inherent property of how the controller was registered.

### Why LV2 poke can't fix device_type

- `device_type` is per-controller, in a kernel heap object (not static memory)
- Its value is determined by the LDD registration path, not a configurable field
- Even if we found the Pad object and patched `m_device_type=0`, the kernel code that reads it might re-derive it from the LDD flag
- The Pad object's address is allocated dynamically, hard to find without knowing internal allocation patterns

### Implications: hard reality about game compatibility

**GTA V and similar games check `device_type != 0` and reject LDD controllers.** This is a kernel-level property, not user-configurable. The only ways to make these games accept our controller:

1. **EBOOT patching per-game** — patch GTA V's binary to accept `device_type=5`. Per-game work.
2. **DEX + debug EBOOT compatibility mode** — original PS3xPAD v0.8 had this, but requires DEX firmware + debug EBOOT signature.
3. **LV2 kernel code patching** — patch the kernel function that sets `device_type` for LDD controllers. Highly risky, would crash on wrong kernel version.
4. **Accept the limitation** — many games work fine via LDD (Minecraft confirmed). GTA V/SC5 won't.

### What still works

- Basic DualSense input on XMB and most games via LDD
- PS button (via `vshtask_A02D46E7` import stub)
- LED control (green on connect)
- All standard buttons, sticks, triggers

### Verified: webMAN build + endpoints

- webMAN MOD 1.47.48q MOD [Rebug-PS3MAPI] on 4.93 CEX EvilNat Cobra 8.5
- Endpoints confirmed working: `/peek.lv2`, `/poke.lv2`, `/find.lv2`, `/cpursx.ps3`, `/vshplugin.ps3mapi`, `/loadprx.ps3`
- NOT available without DEBUG_MEM: `/dump.ps3?lv2`
- **CRITICAL: heavy `/find.lv2` over full LV2 OR many `/peek.lv2` calls in a loop WEDGES webMAN** (PS3 stays alive, just webMAN HTTP unresponsive). Recoverable by power cycle.

### Plugin load results on 4.93 (2026-07-11)

- xpad.sprx loaded into slot 2 as `XPADD`
- LDD registration succeeded (notification visible to user)
- LV2 scanner ran 16MB range — zero `[5,0,0,0,0,0,0]` candidates found
- Scanner reported `XPAD device_type[] NOT FOUND`
- **Conclusion: device_type is not a LV2-static array**

### Plugin status

- Current build (11323 bytes) has runtime scanner + LV2 poke scaffold
- `DEVICE_TYPE_ARRAY_ADDR=0` — never set, would not poke anything
- Keep scanner for now (per-load cost ~600ms, useful diagnostic)
- Alternative approaches to game compatibility must be explored separately

## Session: 2026-07-11 (continued) — Critical bugfix: lv2_peek64 was broken

### Bug discovery via file logging

Initial `lv2_peek64()` used `system_call_1(8, addr); return (uint64_t)p1;`. But `p1` is a `register` variable defined **inside** the `lv2syscall1` macro body — it does NOT exist outside the macro scope. So the function was returning garbage from whatever happened to be in a register.

The scan reported `cand8#1 at 0x5C2E00` (u8 byte pattern match). When checked via webMAN `/peek.lv2?5C2E00`, that address contained `00` at byte 0, not `05`. The `lv2_peek64` was clearly broken — file logging caught the bug.

### Fix

Rewrote `lv2_peek64()`, `lv2_poke32()`, and `prx_get_module_id_by_address()` using inline asm directly:

```c
static inline uint64_t lv2_peek64(uint64_t lv2_addr) {
  register uint64_t p1 asm("3") = lv2_addr + 0x8000000ULL;
  register uint64_t scn asm("11") = 8;
  __asm__ __volatile__("sc"
                       : "+r"(p1)
                       :
                       : "r0","r12","lr","ctr","xer","cr0","cr1","cr5","cr6","cr7","memory");
  return p1;
}
```

### File logging implementation

Added `log_msg()` helper that appends to `/dev_hdd0/tmp/xpad_log.txt`. `show_msg()` now also logs to file (via FTP/webMAN we can see plugin activity without being at the console). `log_clear()` truncates log at plugin start.

Added `vsnprintf` to `src/libc.c` (was missing — caused format errors with `%u`, `%llx`). Extended local printf to handle `%u`, `%lu`, `%llu`, `%llx`, `%lx`.

### After fix: scanner confirms no device_type array in 32MB

Log after rebuild and reload:
```
XPAD StartingXPAD Loaded!XPAD ldd registered unit:0 handle:0
XPAD ldd port unit:0 port:0
XPAD scan1 done 0 cands
XPAD scan2 done 0 cands
XPAD device_type[] NOT FOUND
```

**Zero candidates in 32MB range.** The earlier `0x5C2E00` match was from the broken peek returning garbage. **`device_type` is NOT stored as a static array in LV2 memory within 32MB.**

### Final conclusion

The PS3 kernel stores pad data as per-controller objects (likely in kernel heap), not as a contiguous `device_type[7]` array. The `device_type=5` value is computed at query time when `cellPadGetInfo2` is called.

**LV2 poke approach cannot fix GTA V game compatibility.** The earlier assumption that device_type lives at a fixed LV2 address was wrong.

### Real options for GTA V compatibility

1. **EBOOT patch GTA V** — patch game's binary to accept device_type=5
2. **Accept limitation** — DualSense works on XMB and games that don't check device_type
3. **DEX + debug EBOOT compatibility mode** — requires DEX firmware + debug EBOOT signature

### File log confirmation (via FTP)

```
$ curl http://192.168.1.128/dev_hdd0/tmp/xpad_log.txt
XPAD StartingXPAD Loaded!XPAD ldd registered unit:0 handle:0XPAD ldd port unit:0 port:0XPAD scan1 done 0 candsXPAD scan2 done 0 candsXPAD device_type[] NOT FOUND
```

The plugin logs ALL `show_msg()` calls. The scanner reports:
- `scan1 done 0 cands` — no u32 array matches
- `scan2 done 0 cands` — no u8 array matches
- `device_type[] NOT FOUND` — no verified match

### Lesson learned

**Without file logging, the broken lv2_peek64 would have stayed undetected.** VSH notifications require being at the console. File logging lets us inspect plugin behavior remotely. **All future plugins MUST include file logging** — add `log_msg()` calls at every key point.

### Plugin state (2026-07-11)

- Current build: 11838 bytes
- Scanner + log_msg + lv2_peek64/poke32 inline asm
- Plugin NOT adding itself to boot_plugins.txt — manual load only (per user policy)
- Loaded into slot 2, scanner reports NOT FOUND
- Next: discuss with user which direction to take (EBOOT patch / accept / etc.)
