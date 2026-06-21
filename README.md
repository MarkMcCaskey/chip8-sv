# chip8-sv — CHIP-8 in SystemVerilog

A hardware implementation of the **CHIP-8** virtual machine, written in SystemVerilog and
developed **simulation-first** (no FPGA required to start). Built after finishing *nand2tetris*
Part I, to go deeper on real digital design with an industry HDL, proper testbenches, and waveforms.

## What CHIP-8 is

A tiny 1970s virtual machine: 4 KB RAM, sixteen 8-bit registers `V0`–`VF`, a 16-bit index
register `I`, a program counter, a small call stack, a 64×32 monochrome framebuffer, a 16-key
hex keypad, and two 60 Hz timers (delay + sound). ~35 two-byte opcodes. Small enough to finish,
rich enough to exercise FSMs, memory, an ALU, video, and I/O.

## Toolchain (all open-source / first-party)

- **Verilator 5.x** — primary simulator + linter (installed). We pass `--binary --timing` so
  testbenches stay pure SystemVerilog (no C++ harness needed).
- **SDL2** — for the later live-display harness (installed).
- **A VCD/FST waveform viewer** — only needed when debugging signals. GTKWave is the classic and
  is not yet installed. When you want it, install first-party: `brew install gtkwave`, or build
  from source from https://github.com/gtkwave/gtkwave  (the newer `surfer` viewer is another OSS option).

> Provenance: same rule as the nand2tetris repo — toolchain is OSS, installed via Homebrew
> (checksummed bottles) or built from the upstream repos. No proprietary vendor blobs
> (Vivado/Quartus), no unsigned binaries.

## The loop

```
make warmup     # builds + runs the counter sanity check, dumps warmup/counter.vcd
make clean      # remove build output + waveforms
```

`make warmup` proves the whole flow end-to-end before you write any CHIP-8 RTL. It should print
`WARMUP PASS`. Open `warmup/counter.vcd` in a waveform viewer to watch the counter tick.

Layout:
```
rtl/       your CHIP-8 modules go here
tb/        testbenches
warmup/    throwaway counter example (delete once you're comfortable)
Makefile   build/sim targets
```

## Roadmap (build it in steps)

Tick these off as you go. Each milestone is independently testable in sim.

- [x] **M0 — Toolchain warm-up** — counter + testbench + waveform (`make warmup`)
- [ ] **M1 — Memory & registers** — 4 KB RAM (block-RAM style), `V0`–`VF`, `I`, `PC`, `SP`, stack
- [x] **M2 — Fetch/decode FSM** — fetch a 2-byte opcode, split fields (`nnn` / `n` / `x` / `y` / `kk`)
- [x] **M3 — ALU & register ops** — `6xkk 7xkk 8xy0..8xyE Annn` (incl. `VF` flags; flag tests pending)
- [ ] **M4 — Control flow** — `1nnn 2nnn 00EE 3xkk 4xkk 5xy0 9xy0 Bnnn`
- [ ] **M5 — Timers** — 60 Hz delay + sound, clock divider from the CPU clock
- [ ] **M6 — Display** — 64×32 framebuffer + `Dxyn` sprite XOR draw with `VF` collision; `00E0` clear
- [ ] **M7 — Input** — 16-key keypad: `Ex9E ExA1 Fx0A`
- [ ] **M8 — Misc Fx** — `Fx07 Fx15 Fx18 Fx1E Fx29 Fx33 Fx55 Fx65`
- [ ] **M9 — Integration** — run CHIP-8 test ROMs in sim, then wire up the SDL live display
- [ ] **(stretch) FPGA** — open flow (Yosys + nextpnr) to a small board with real VGA/HDMI + buttons

## CHIP-8 references (spelled out — not clickable)

- Cowgod's Chip-8 Technical Reference (canonical opcode spec):
  http://devernay.free.fr/hacks/chip8/C8TECH10.HTM
- Tobias Langhoff, "Guide to making a CHIP-8 emulator" (very approachable walkthrough):
  https://tobiasvl.github.io/blog/write-a-chip-8-emulator/
- Timendus CHIP-8 test suite (ROMs to validate behavior in sim):
  https://github.com/Timendus/chip8-test-suite
