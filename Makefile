PYTHON ?= python3
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
YOSYS ?= yosys
RTL = $(wildcard rtl/*.sv)
UNITS = pid pwm mailbox protection sequencer closed_loop
.PHONY: all test lint synth cross clean plot
all: test
build:
	mkdir -p build
build/pid_vectors.txt: tools/gen_pid.py tools/pid_reference.py | build
	$(PYTHON) tools/gen_pid.py $@
build/pid.vvp: rtl/fixed_pid.sv tb/tb_pid.sv | build
	$(IVERILOG) -g2012 -Wall -s tb_pid -o $@ $^
build/pwm.vvp: rtl/pwm_deadtime.sv tb/tb_pwm.sv | build
	$(IVERILOG) -g2012 -Wall -s tb_pwm -o $@ $^
build/mailbox.vvp: rtl/adc_mailbox.sv tb/tb_mailbox.sv | build
	$(IVERILOG) -g2012 -Wall -s tb_mailbox -o $@ $^
build/protection.vvp: rtl/rail_protection.sv tb/tb_protection.sv | build
	$(IVERILOG) -g2012 -Wall -s tb_protection -o $@ $^
build/sequencer.vvp: rtl/rail_sequencer.sv tb/tb_sequencer.sv | build
	$(IVERILOG) -g2012 -Wall -s tb_sequencer -o $@ $^
build/closed_loop.vvp: rtl/fixed_pid.sv rtl/pwm_deadtime.sv tb/tb_closed_loop.sv | build
	$(IVERILOG) -g2012 -Wall -s tb_closed_loop -o $@ $^
build/pmic.vvp: $(RTL) tb/tb_pmic.sv tb/i2c_master.vh | build
	$(IVERILOG) -g2012 -Wall -Itb -s tb_pmic -o $@ $(RTL) tb/tb_pmic.sv
test: $(addprefix build/,$(addsuffix .vvp,$(UNITS))) build/pid_vectors.txt build/pmic.vvp
	$(PYTHON) tools/regress.py --vvp $(VVP)
lint:
	$(VERILATOR) --lint-only --Wall --top-module pmic_top $(RTL)
synth: | build
	$(YOSYS) -Q -T -s tools/synth.ys > build/synthesis.log
	$(PYTHON) tools/synth_report.py
build/obj_verilator/pmic_verilator: $(RTL) tb/tb_pmic.sv tb/i2c_master.vh | build
	$(VERILATOR) --binary --timing -Wno-WIDTH --top-module tb_pmic -Itb --Mdir build/obj_verilator -o pmic_verilator $(RTL) tb/tb_pmic.sv > build/verilator-build.log 2>&1
cross: build/obj_verilator/pmic_verilator
	$(PYTHON) tools/cross_sim.py
plot:
	$(PYTHON) tools/plot_loop.py
clean:
	rm -rf build
