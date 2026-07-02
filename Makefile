# CHIP-8 (SystemVerilog) -- simulation-first build.
# Requires Verilator 5.x. Waveforms: any VCD viewer (GTKWave / surfer).
# `--binary --timing` lets testbenches be pure SystemVerilog (no C++ harness).

VERILATOR ?= verilator
VFLAGS    ?= --binary --timing --trace -Wall -j 0

# ---- warm-up: prove the toolchain end-to-end ----
.PHONY: warmup
warmup:
	@mkdir -p warmup/obj_dir
	$(VERILATOR) $(VFLAGS) --Mdir warmup/obj_dir -o sim_counter \
		warmup/tb_counter.sv warmup/counter.sv
	./warmup/obj_dir/sim_counter

# ---- M1: 4 KB RAM ----
.PHONY: ram
ram:
	@mkdir -p obj_dir/ram
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/ram -o sim_ram \
		tb/tb_ram.sv rtl/ram.sv
	./obj_dir/ram/sim_ram

# ---- M2: CPU fetch/decode/execute ----
.PHONY: cpu
cpu:
	@mkdir -p obj_dir/cpu
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/cpu -o sim_cpu \
		tb/tb_cpu.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/cpu/sim_cpu

# ---- M3: ALU / VF flag tests ----
.PHONY: alu
alu:
	@mkdir -p obj_dir/alu
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/alu -o sim_alu \
		tb/tb_alu.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/alu/sim_alu

# ---- M4: control flow (calls/returns/skips/jumps) ----
.PHONY: ctrl
ctrl:
	@mkdir -p obj_dir/ctrl
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/ctrl -o sim_ctrl \
		tb/tb_ctrl.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/ctrl/sim_ctrl

# ---- M5: 60 Hz timers ----
.PHONY: timer
timer:
	@mkdir -p obj_dir/timer
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/timer -o sim_timer \
		tb/tb_timer.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/timer/sim_timer

# ---- M6: framebuffer + Dxyn draw ----
.PHONY: display
display:
	@mkdir -p obj_dir/display
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/display -o sim_display \
		tb/tb_display.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/display/sim_display

# ---- M7: keypad input ----
.PHONY: input
input:
	@mkdir -p obj_dir/input
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/input -o sim_input \
		tb/tb_input.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/input/sim_input

# ---- M8: misc Fx (BCD, reg save/load, font, random) ----
.PHONY: misc
misc:
	@mkdir -p obj_dir/misc
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/misc -o sim_misc \
		tb/tb_misc.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/misc/sim_misc

# ---- M9: run a real CHIP-8 ROM in simulation ----
# Usage: make rom ROM=roms/3-corax+.ch8 [CYCLES=300000] [SEL=0]
# Fetch the Timendus test suite first with: make roms
ROM    ?= roms/1-chip8-logo.ch8
CYCLES ?= 300000
SEL    ?= 0
.PHONY: rom
rom:
	@mkdir -p obj_dir/rom
	$(VERILATOR) $(VFLAGS) --Mdir obj_dir/rom -o sim_rom \
		tb/tb_rom.sv rtl/chip8_cpu.sv rtl/ram.sv
	xxd -p -c1 $(ROM) > obj_dir/rom/rom.hex
	./obj_dir/rom/sim_rom +ROM=obj_dir/rom/rom.hex +CYCLES=$(CYCLES) +SEL=$(SEL)

# Timendus chip8-test-suite ROMs (GPL-3.0, fetched from the upstream repo;
# kept out of git -- see .gitignore).
.PHONY: roms
roms:
	@mkdir -p roms
	for r in 1-chip8-logo 2-ibm-logo 3-corax+ 4-flags 5-quirks 6-keypad; do \
		curl -sfL -o roms/$$r.ch8 \
			"https://raw.githubusercontent.com/Timendus/chip8-test-suite/main/bin/$$r.ch8"; \
	done
	@ls -l roms

# ---- M9: live SDL display (real window / keyboard / beeper) ----
# Usage: make run ROM=roms/1-chip8-logo.ch8
# The -G override must match kCyclesPerFrame in sim/sim_main.cpp (64 cycles
# per 60 Hz frame = one timer tick per frame, ~16 instructions/frame).
.PHONY: sdl run
sdl:
	@mkdir -p obj_dir/sdl
	$(VERILATOR) --cc --exe --build -j 0 -Wall --Mdir obj_dir/sdl \
		-GCYCLES_PER_TICK=64 \
		-CFLAGS "$$(sdl2-config --cflags)" -LDFLAGS "$$(sdl2-config --libs)" \
		-o chip8_sdl rtl/chip8_cpu.sv rtl/ram.sv sim/sim_main.cpp

run: sdl
	./obj_dir/sdl/chip8_sdl $(ROM)

.PHONY: clean
clean:
	rm -rf warmup/obj_dir obj_dir *.vcd warmup/*.vcd
