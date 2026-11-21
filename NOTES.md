# iOS 16 on kiev (Motorola One 5G Ace XT2113-2, SM7225) - working notes

## Agent handoff / active work (2026-11-21, latest)

### STATE at end of 2026-11-21 (session start):

**Hardware collected:**
- XT2113-2 with unlocked bootloader
- Live FDT extracted via `adb pull /proc/device-tree dtb_live/`
- Key constants documented from live FDT

**Hardware constants (from live FDT):**
| Component | sweet (SM7150) | kiev (SM7225) | Source |
|-----------|----------------|---------------|--------|
| GICD | 0x17a00000 | 0x17a00000 | Same |
| GICR | 0x17a60000 | 0x17a60000 | Same |
| UFS | 0x01d84000 | 0x01d84000 | Same (ufshc@1d84000) |
| FB | 0x9c000000 | 0x9c000000 | Assumed same (ABL splash) |
| TIMEBASE | 19.2 MHz | 19.2 MHz | Same |
| **VTIMER_INTID** | **19** | **13** | **DIFFERENT!** |
| **PTIMER_INTID** | **18** | **14** | **DIFFERENT!** |
| CPU topology | 2× A76 + 6× A55 | 2× A77 + 6× A55 | Different big cores |
| CPU MPIDR Aff1 | 0x000-0x700 | 0x000-0x700 | Same layout |
| Touch | Goodix GT9896 | **FocalTech** (FTS) | **DIFFERENT** |
| Display panel | CSOT (1080x2400) | **CSOT FT8756** | Different panel |
| Compatible | xiaomi,sweet qcom,sm7150 | **motorola,kiev qcom,sm7225** | **DIFFERENT** |

**Files created this session:**
- `tools/mkadt_kiev.py` - Device tree generator for kiev (VTIMER_INTID=13, 8 CPU nodes, Kryo 570)
- `shim/shim_kiev.c` - Boot shim with kiev timer INTIDs, GIC setup
- `shim/console_kiev.h/.c` - Console headers for kiev
- `shim/mmu_kiev.h/.c` - MMU for kiev
- `shim/ufs_kiev.h/.c` - UFS for kiev (same base address)
- `shim/loader_kiev.c` - Payload loader with "KIEVXNU" magic
- `shim/build_kiev.sh` - Build script for kiev shim
- `xnu/patches/0004-kiev-machine-config.patch` - Machine config (KIEV board)
- `xnu/patches/0016-kiev-device-tree-platform-expert.patch` - KievPlatformExpert
- `xnu/patches/0017-kiev-device-tree-virtual-timer-irq.patch` - Timer INTID 13
- `xnu/patches/0018-kiev-boot-cpu-driver.patch` - CPU driver for Kryo 570
- `xnu/patches/0065-kiev-smp-psci.patch` - SMP PSCI for 8 cores (2× A77 + 6× A55)

**Pending tasks:**
1. Test shim build (needs DTB from stock boot.img)
2. Create kiev-specific XNU patches for:
   - Touch driver (FocalTech FTS, not Goodix)
   - Display driver (CSOT FT8756 panel timings)
   - PMIC/battery (likely PM6150/6350, different from PM6150L)
   - Buttons (PMIC GPIOs)
   - RPMh regulator voting
3. Update `tools/sweet-root-tweaks.py` → `tools/kiev-root-tweaks.py`
4. Build kernel via GitHub Actions
5. Test boot on device

**Bootloader notes:**
- Motorola ABL (different from Xiaomi ABL on sweet)
- Must use `fastboot boot` for temporary images (preserves Android)
- User approved using internal UFS (userdata partition) for iOS root
- Keep bootloaders, recovery, modem, persist, and backups intact

**Next concrete action:**
- Obtain stock boot.img DTB from user's device for shim build
- Or guide user through extracting it if not already done