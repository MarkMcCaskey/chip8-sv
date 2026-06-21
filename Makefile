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

.PHONY: clean
clean:
	rm -rf warmup/obj_dir obj_dir *.vcd warmup/*.vcd
