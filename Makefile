# CHIP-8 (SystemVerilog) -- simulation-first build.
# Requires Verilator 5.x. Waveforms: any VCD viewer (GTKWave / surfer).
# `--binary --timing` lets testbenches be pure SystemVerilog (no C++ harness).

VERILATOR ?= verilator
VFLAGS    ?= --binary --timing --trace -Wall -j 0

# Warnings to suppress while the CPU datapath is still half-wired (declared-but-
# unused state, undriven write port). Drop these as the design fills in.
WIP_WAIVERS = -Wno-UNUSEDSIGNAL -Wno-UNDRIVEN -Wno-WIDTHEXPAND

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
	$(VERILATOR) $(VFLAGS) $(WIP_WAIVERS) --Mdir obj_dir/cpu -o sim_cpu \
		tb/tb_cpu.sv rtl/chip8_cpu.sv rtl/ram.sv
	./obj_dir/cpu/sim_cpu

.PHONY: clean
clean:
	rm -rf warmup/obj_dir obj_dir *.vcd warmup/*.vcd
