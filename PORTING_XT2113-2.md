# Porting ios-sweet to XT2113-2 (Motorola One 5G Ace / kiev)

## Device Information
- **Model**: Motorola One 5G Ace
- **Codename**: kiev
- **SoC**: Qualcomm Snapdragon 750G (SM7225)
- **CPU**: 2× Kryo 570 Gold (Cortex-A77) @ 2.2 GHz + 6× Kryo 570 Silver (Cortex-A55) @ 1.8 GHz
- **GPU**: Adreno 619
- **RAM**: 6 GB LPDDR4x
- **Storage**: 128 GB UFS 2.2
- **Display**: 6.7" 1080×2400 IPS LCD, 60 Hz
- **Battery**: 5000 mAh

## Key Differences from sweet (SM7150)

| Area | sweet (SM7150) | kiev (SM7225) | Porting Impact |
|------|----------------|---------------|----------------|
| **Big Cores** | 2× A76 | 2× A77 | New CPU errata, different PMU, different freq table |
| **Little Cores** | 6× A55 | 6× A55 | Same architecture, different freq table |
| **GIC** | GICv3 @ 0x17a00000 | **SAME @ 0x17a00000** | No change |
| **Timer** | 19.2 MHz, VTIMER INTID 19 | **19.2 MHz, VTIMER INTID 13** | **CRITICAL - different PPI mapping** |
| **UFS** | @ 0x01d84000 | **SAME @ 0x01d84000** | No change |
| **Display** | FB @ 0x9c000000 | **SAME @ 0x9c000000 (assumed)** | No change |
| **Touch** | Goodix GT9896 @ QUP SE7 | **FocalTech FTS** | **DIFFERENT - new driver needed** |
| **PMIC** | PM6150L | **PM6150/6350 (TBD)** | **DIFFERENT - new driver needed** |
| **RPMh** | Present | **Present (TBD)** | Likely similar |
| **Bootloader** | Xiaomi ABL | **Motorola ABL** | Different DTB structure |

## Files Requiring Changes

### 1. Boot Shim (`shim/`) - **DONE (kiev variants created)**
| File | Status | Notes |
|------|--------|-------|
| `shim_kiev.c` | ✅ Created | VTIMER_INTID=13, PTIMER_INTID=14, GIC setup |
| `start.S` | ✅ No changes | Generic ARM64 entry |
| `mmu_kiev.c/.h` | ✅ Created | Uses FB_PHYS=0x9c000000 |
| `ufs_kiev.c/.h` | ✅ Created | Same UFS_BASE=0x01d84000 |
| `console_kiev.c/.h` | ✅ Created | Same FB constants |
| `loader_kiev.c` | ✅ Created | "KIEVXNU" magic |
| `build_kiev.sh` | ✅ Created | Outputs `shim-boot-kiev.img` |

### 2. Device Tree Generator (`tools/`) - **DONE**
| File | Status | Notes |
|------|--------|-------|
| `mkadt_kiev.py` | ✅ Created | VTIMER_INTID=13, 8 CPU nodes (Kryo 570), motorola,kiev compatible |

### 3. XNU Patches (`xnu/patches/`) - **CORE PATCHES CREATED**
| Patch | Description | Status |
|-------|-------------|--------|
| 0004-kiev-machine-config.patch | KIEV board config, cache line, GIC | ✅ Created |
| 0016-kiev-device-tree-platform-expert.patch | KievPlatformExpert.cpp | ✅ Created |
| 0017-kiev-device-tree-virtual-timer-irq.patch | VTIMER INTID=13 from ADT | ✅ Created |
| 0018-kiev-boot-cpu-driver.patch | KievCPU.cpp (Kryo 570) | ✅ Created |
| 0065-kiev-smp-psci.patch | SMP PSCI for 8 cores (2×A77+6×A55) | ✅ Created |
| 0028-0034 | UFS driver | 🔄 TBD (same MMIO as sweet) |
| 0046 | IOSurface/IOMFB | 🔄 TBD (same as sweet) |
| 0058 | HID event services | 🔄 TBD (same framework) |
| 0059 | iPhone identity | 🔄 Keep (iPhone X) |
| 0060 | keys/touch drivers | ❌ NEW - FocalTech touch, PMIC buttons |
| 0061 | iPhone X display size | 🔄 Keep (1125×2436) |
| 0062 | touch/power/battery | ❌ NEW - PMIC, RPMh, fuel gauge |
| 0063 | Goodix GENI packing | ❌ NEW - FocalTech protocol |
| 0078 | SMP 8 cores | ✅ Handled by 0065 |

### 4. Root Tweaks (`tools/sweet-root-tweaks.py`)
- Rename to `kiev-root-tweaks.py`
- Update any device-specific paths

### 5. Build Scripts
- `tools/mkpayload.py` - Works generically with ADT
- `tools/mkiosroot.sh` - Generic, no changes
- `shim/build.sh` - Output naming

## Required Hardware Information - **COLLECTED (2026-11-21)**

Live FDT extracted from XT2113-2 via `adb pull /proc/device-tree dtb_live/`:

**Key extracted constants:**
- Memory: `<0x80000000 0x3dd00000>, <0xc0000000 0xc0000000>` (same as sweet)
- Timer: clock-frequency 19200000, interrupts PPI 13 (vtimer), 14 (ptimer), 11, 12
- GIC: GICD @ 0x17a00000, GICR @ 0x17a60000 (same as sweet)
- UFS: ufshc@1d84000 (same as sweet)
- CPU: 8 cores, MPIDR Aff1 0x000-0x500 (A55), 0x600-0x700 (A77)
- Compatible: "motorola,kiev", "qcom,sm7225"
- Touch: FocalTech on I2C (different from Goodix)
- Display: CSOT FT8756 panel, 1080x2400

```bash
# Still needed: stock boot.img DTB for shim build
# On the phone (in fastboot):
# 1. Boot to fastboot
# 2. Extract stock boot.img to get DTB:
python3 tools/unpack_bootv2.py backup/boot.img dtb/boot_unpacked
```

## Porting Sequence

### Phase 1: Hardware Discovery (Week 1) - ✅ **DONE (2026-11-21)**
1. ✅ Get live FDT from XT2113-2
2. ✅ Document all MMIO addresses, interrupts, clock frequencies
3. ✅ Identify touch controller (FocalTech), PMIC (TBD), display panel (CSOT FT8756)
4. ✅ Verify bootloader unlock status (unlocked) and ABL behavior (Motorola)

### Phase 2: Boot Shim (Week 2) - ✅ **DONE (2026-11-21)**
1. ✅ Created `shim/shim_kiev.c` with kiev MMIO constants (VTIMER_INTID=13)
2. ✅ Created `shim/mmu_kiev.c/.h` with kiev memory map
3. ✅ Created `shim/ufs_kiev.c/.h` for SM7225 UFS controller (same as sweet)
4. ✅ Created `shim/build_kiev.sh` - outputs `shim-boot-kiev.img`
5. ⏳ **PENDING**: Test shim boots to console on device (needs stock boot.img DTB)

### Phase 3: Device Tree Generator (Week 2-3) - ✅ **DONE (2026-11-21)**
1. ✅ Created `tools/mkadt_kiev.py` with kiev constants
2. ⏳ **PENDING**: Generate ADT, verify with `mkadt_kiev.py --dump`
3. ⏳ **PENDING**: Test payload loading with shim

### Phase 4: XNU Patches (Week 3-5) - **CORE PATCHES CREATED (2026-11-21)**
1. ✅ Created `KievPlatformExpert.cpp` via patch 0016
2. ✅ CPU topology for Kryo 570 (8 homogeneous cores) via patch 0004/0065
3. ✅ SMP PSCI for 8 cores (2× A77 + 6× A55) via patch 0065
4. ✅ Timer INTID handling via patch 0017
5. ❌ **TODO**: Touch driver (FocalTech FTS - new protocol)
6. ❌ **TODO**: Button driver (PMIC GPIOs - different from sweet)
7. ❌ **TODO**: Display driver (CSOT FT8756 panel timings)
8. ❌ **TODO**: Battery/fuel gauge (PMIC - likely PM6150/6350)
9. ❌ **TODO**: RPMh regulator voting for touch rail
10. ⏳ **PENDING**: Build kernel via GitHub Actions

### Phase 5: Integration (Week 5-6)
1. Build iOS root image (same as sweet)
2. Create payload + boot image
3. Test boot on device
4. Debug via persistent log (OrangeFox recovery)

## Resources Needed

- **XT2113-2 device** with unlocked bootloader
- **Linux PC** with `aarch64-linux-gnu-gcc`, `mkbootimg`, `fastboot`
- **GitHub account** for kernel CI (macOS runners)
- **OrangeFox recovery** for log extraction
- **IPSW**: iPhone X (iPhone10,3) iOS 16.7.16 (20H392)

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Different GIC layout | High | Must get live FDT first |
| Different touch IC | High | Identify from FDT / dmesg |
| Different PMIC | High | Identify from FDT |
| Motorola ABL quirks | Medium | Test shim-boot early |
| UFS controller differences | Medium | SM7225 UFS similar to SM7150 |
| A77 vs A76 errata | Medium | Check ARM errata for Cortex-A77 |

## Next Steps

1. **Immediate**: Obtain stock boot.img DTB from user's device (needed for shim build)
2. **Then**: Test shim build with `./build_kiev.sh`
3. **Then**: Generate ADT with `python3 tools/mkadt_kiev.py out/kiev.adt --dump`
4. **Then**: Create kiev-specific XNU patches for touch, display, PMIC, buttons, RPMh
5. **Then**: Build kernel via GitHub Actions
6. **Then**: Test boot on device with `fastboot boot shim/out/shim-boot-kiev.img`

---

**Note**: This port is significantly more complex than a simple config change. The SM7225 (750G) has different big cores (A77 vs A76), which affects CPU bring-up, power management, and errata handling. The touch controller (FocalTech vs Goodix) requires a completely new driver. Budget 6-8 weeks for a working boot to SpringBoard.

---

**Note**: This port is significantly more complex than a simple config change. The SM7225 (750G) has different big cores (A77 vs A76), which affects CPU bring-up, power management, and errata handling. Budget 6-8 weeks for a working boot to SpringBoard.