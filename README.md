

# CAN-FD-FI
<img width="994" height="384" alt="inject" src="https://github.com/user-attachments/assets/9eb3e72f-23c9-4660-b474-69b2374dd3fd" />


A synthesizable bus-based Controller Area Network fault injector targeting CAN 2.0 and CAN FD nodes, written in VHDL. Tested up to 240 MHz on an AMD Zynq UltraScale+ MPSoC.

## Features

- Non-intrusive bus injection utilizing a standard off-the-shelf CAN transceiver
- Reliable injections for CAN 2.0 and CAN FD data phase rates (upper bound set by transceiver loop delay and bus propagation)
- Protocol aware frame parsing and injection
- Scalable multi-slot injection configuration of up to eight slots.
- Filtered targeting of nodes via CAN IDs
  - Supports 11-bit base and 29-bit extended identifiers
  - Supports identifier ranges via bitwise wildcard masks
- DLL injections targeting most frame segments:
  - Recessive frame bits after arbitration
  - Recessive stuffing bits after arbitration (differentiates fixed and dynamic stuff bits)
  - DLC override for error-passive targets
  - Full DATA and CRC payload override/spoofing for error-passive targets
- Injection status feedback via AXI flag registers and interrupts

## Injection Flow

### Configuration
The core is initialized in configration mode and must be provided via AXI registers with:
- Bit timing parameters: BRP, TSEG1, TSEG2, SJW for nominal and data rates, as well as SSP offset for TDC.
- Injection sampling offsets: Pre-Sample-Point (PSP) and Fault-Injection-Point (FIP) as a TQ offset from the Sync-Segment.
- Slot configurations for each of the eight slots:
  - 29-bit target ID and mask
  - Trigger criteria: injection type, target field, and metadata
  - Optional Data-CRC override vector (up to 576 bits, streamed into internal BRAM via 32-bit segments)

Once configured, configuration mode can be disabled and the core begins monitoring the bus for an SOF.

### Valid Injection Targets
| Type | Target Field | Metadata | Description |
| :--- | :--- | :--- | :--- |
| `FI-BIT` | `CTRL`, `DATA`, `CRC-STF`, `CRC`, `EOF` | Bit offset in field | Flips target bit to dominant |
| `FI-DATA` | NA | Frame DLC | Overrides Payload + CRC (First override must be recessive) |
| `FI-DLC` | NA | 4-bit DLC | Overrides frame DLC field (First override must be recessive) |
| `FI-BSFX` | `CRC-STF`, `CRC` | Stuff bit index in field | Flips target fixed stuff bit to dominant  |
| `FI-BSDY` | `CTRL`, `DATA`, `CRC` | Stuff bit index in field | Flips target dynamic stuff bit to dominant |




###  Injection Procedure

1. **Wake & Match:** On detecting SOF, the core parses the identifier and compares it against active slot configurations. On match, the matching injection slot is loaded into an active register.
2. **Monitoring & Trigger:** Once provided with a valid configuration, the core parses the frame and monitors each bit, if the next bit, according to the internal FSM matches the trigger, it initiates an injection.
3. **Performing an Injection:**
   - The core samples the bus at the PSP before other nodes hit their sample point.
   - If recessive, the core drives the bus dominant at the configured FIP.
   - For single-bit targets, the core returns to passive listening immediately after the bit.
   - For multi-bit overrides (Such as `FI-DLC` or `FI-DATA`), the core shifts the FIP to the bit boundary, suspends PSP sampling, and actively drives the bus either through the DLC or up to the CRC-DEL field.
4. **Feedback Assembly:** The core tracks the remaining frame through EOF or an Error Flag, sets status flags (See below), raises an interrupt if enabled, and resets its state for the next SOF.

### Status Flags
An injection can also be unsuccessful if invalid settings are provided. In total the core differentiates between 3 different errors, each with their respective flag:
- **Injection Miss:** Target bit was never encountered in the received frame.
- **Injection Dominant:** Target bit was already dominant on the bus; cannot overwrite.
- **Invalid DLC:** Frame DLC does not match the configured override vector length.

## Architecture
<img width="2773" height="1567" alt="General_Structure" src="https://github.com/user-attachments/assets/2c01ba5d-7dd4-409e-a5ce-fcc081deab72" />

- **Timing Unit:** Interfaces directly with physical CAN TX and RX lines. Handles wake & sleep,  resynchronization, transitions between nominal and data rate, transmitter delay compensation, and drives injection requests at TQ resolution.
- **Parsing Unit:** Performs bit destuffing, decodes frame structure from Timing Unit samples, assembles ID/DLC fields, and signals frame boundary transitions to the Timing Unit.
- **Memory Unit:** Implements ID matching, manages BRAM storage for payload override vectors, retrieves active injection slots, and handles AXI interrupt dispatch.
- **Override Unit:** Compares active frame state against injection triggers, validates the PSP sample, streams stuffed override data, and captures injection status flags.

## Verification

The core was verified in simulation through three test stages:
- Unit-level static verification for all sub-components.
- CAN parsing verified against 10,000 CTU-CAN-FD reference test vectors.
- Override logic verified against 13,000 randomized test permutations covering diverse frame configurations and injection triggers.

## Resource Utilization

Target: **AMD Zynq UltraScale+ ZU4EG** (8 injection slots, 240 MHz core clock).  
Worst-case setup slack: **0.358 ns**, worst-case hold slack: **0.017 ns**.

| Instance / Module | LUT | FF | BRAM |
| :--- | :---: | :---: | :---: |
| AXI Interface | 546 | 780 | — |
| Parser Unit | 254 | 112 | — |
| Memory Unit | 193 | 91 | 9 |
| Override Unit | 269 | 130 | — |
| Timing Unit | 373 | 210 | — |
| **Total** | **1635** | **1323** | **9** |

## Directory Structure

- `gen`: Generated register artifacts from hdl-registers
- `src/hdl`: VHDL synthesis source
- `src/sim`: VHDL testbenches and simulation sources
- `src/registers`: Register definition files TOML
- `src/sw`: Target CLI software
- `scripts`: Various Scripts

## External Dependencies

- **[HDL-Registers](https://github.com/hdl-registers/hdl-registers) & [HDL-Modules](https://github.com/hdl-modules/hdl-modules):** AXI interface and register generator
- **[CANHacks](https://github.com/kentindell/canhack):** Override test vector generation
- **[CTU-CAN-FD](https://github.com/Logic-Design-Services/CTU-CAN-FD):** ISO compliance reference vectors
- **[Clap](https://github.com/clap-rs/clap):** Command-line parsing for the Rust target utility

## Register File Generation

Hardware registers and software bindings (VHDL, C++, Rust) are generated from `src/registers/can_fd_fi_registers.toml`.

Setup the Python environment (managed with PDM):
```bash
source setupPdm.sh
pdm install
```
Generate artifacts into `gen/`:
```bash
pdm generate
```

## Running the Configuration CLI

The utility in `src/sw/rust_can_fd_fi_test` runs on the target board to configure injection profiles and timing at runtime via Linux UIO.

### Prerequisites
-   Rust toolchain on the target or a configured cross-compilation environment
-   Up-to-date register bindings generated via `pdm generate`
    
### Device Tree Requirements

The CLI scans `/sys/class/uio/uio*/device/of_node` for nodes matching the prefix `can_fi_axi_top_bd_wrap` and binds via `generic-uio`:
-   The physical address range assigned to the core's AXI interface must be exposed as a `generic-uio` node.
-   The kernel module `uio_pdrv_genirq` must be active (`uio_pdrv_genirq.of_id=generic-uio` in bootargs).
    
### Building

From `src/sw/rust_can_fd_fi_test`:
```bash
# Cross-compilation for 64-bit ARM:
cargo build --release --target aarch64-unknown-linux-gnu

# Native compilation on target:
cargo build --release
```
### Usage
```bash
# Inspect available subcommands and injection options
sudo ./rust_can_fd_fi_test --help

# Query core status on a specific instance
sudo ./rust_can_fd_fi_test --device can1 status
```
