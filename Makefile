# CHIP-8 (SystemVerilog) -- simulation-first build.
# Requires Verilator 5.x (already installed). Waveforms: any VCD viewer (GTKWave / surfer).
#
# We use `--binary --timing` so testbenches can be written in pure SystemVerilog
# (initial blocks, # delays, @posedge) with no C++ harness.

VERILATOR ?= verilator
VFLAGS    ?= --binary --timing --trace -Wall -j 0

# ---- warm-up: prove the toolchain end-to-end ----
.PHONY: warmup
warmup:
	$(VERILATOR) $(VFLAGS) --Mdir warmup/obj_dir -o sim_counter \
		warmup/tb_counter.sv warmup/counter.sv
	./warmup/obj_dir/sim_counter

.PHONY: clean
clean:
	rm -rf warmup/obj_dir obj_dir *.vcd warmup/*.vcd
