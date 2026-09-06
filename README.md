# CAN Fault Injector IP Core

### Directory Structure 

- `lib`: External Libraries (hdl-modules)
- `gen`: Generated data outputs from hdl-registers
- `src/hdl`: VHDL Synthesis Source 
- `src/sim`: VHDL Sim Source 
- `src/registers`: TOML Configuration for HDL-Registers 
- `scripts`: Various Scripts

### Generating Register file

Register code (VHDL + C++ + Rust) is generated from
`src/registers/can_fd_fi_registers.toml` by `scripts/generate_registers.py`.
The Python environment is managed with [PDM](https://pdm-project.org).

First-time setup (bootstraps a local PDM into `.local-pdm/` and installs deps):

```bash
source setupPdm.sh
pdm install
```

Then, to (re)generate the register artifacts into `gen/`:

```bash
pdm generate
```

Other PDM scripts: `pdm format` / `pdm check` (ruff), `pdm test` (pytest).
`./generate.sh` is a convenience wrapper that does the bootstrap + install + generate in one go.
This step also runs automatically as a pre-build step during a full project build
(see `scripts/generate-can-registers.sh`, registered in `scripts/project-settings.sh`).

> The conda `scripts/environment.yml` is kept only as a fallback; PDM is the primary path.
