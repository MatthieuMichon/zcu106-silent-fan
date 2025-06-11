SOURCE_DIR = ../
BUILD_DIR = build

SYN ?= vivado
SYN_MODE ?= batch
SYN_FLAGS ?= -nojournal -notrace -mode $(SYN_MODE)

PART = xczu7ev-ffvc1156-2-e
SCRIPT = script.tcl

# Build script generation ------------------------------------------------------
define SCRIPT_CONTENTS
# Vivado TCL build script generated from $(realpath $(lastword $(MAKEFILE_LIST)))
package require Vivado
create_project -part $(PART) -in_memory
read_xdc [glob $(SOURCE_DIR)/*.xdc]
read_verilog -sv [glob $(SOURCE_DIR)/*.sv]
set top [lindex [find_top] 0]
synth_design -top $${top} -verilog_define DEBUG=TRUE -debug_log -assert -verbose
opt_design -debug_log -verbose
place_design -debug_log -timing_summary -verbose
route_design -debug_log -tns_cleanup -verbose
report_clock_utilization -file clock_utilization.txt
report_clocks -file clocks.txt
report_debug_core -full_path -file debug_core.txt
report_design_analysis -show_all -complexity -file design_analysis_complexity_report.txt
report_design_analysis -show_all -congestion -file design_analysis_congestion_report.txt
report_drc -file drc_report.txt
report_drc -ruledeck methodology_checks -file drc_report_methodology.txt
report_drc -ruledeck timing_checks -file drc_report_timing.txt
report_io -file io_report.txt -verbose
report_methodology -no_waivers -file methodology.txt
report_param -file param_report.txt -verbose
report_timing_summary -slack_lesser_than 0 -file timing_summary.txt -max_paths 99
report_utilization -quiet -hierarchical -hierarchical_depth 2 -file utilization_report.txt
xilinx::designutils::report_failfast -detailed_reports impl -file failfast_report.txt -quiet
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
write_bitstream -force -file $${top}.bit -verbose
write_debug_probes -force $${top}.ltx
write_checkpoint -force build.dcp
open_hw_manager -quiet
connect_hw_server -quiet
open_hw_target -quiet
set_property PROGRAM.FILE $${top}.bit [current_hw_device]
set_property PROBES.FILE $${top}.ltx [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device -quiet
endef
# ------------------------------------------------------------------------------

# Configuration script generation ----------------------------------------------
define CONF_SCRIPT_CONTENTS
# Vivado TCL build script generated from $(realpath $(lastword $(MAKEFILE_LIST)))
package require Vivado
open_hw_manager -quiet
connect_hw_server -quiet
open_hw_target -quiet
set_property PROGRAM.FILE [glob *.bit] [current_hw_device]
#set_property PROBES.FILE [glob *.ltx] [current_hw_device]
program_hw_devices [current_hw_device]
refresh_hw_device -quiet
endef
# ------------------------------------------------------------------------------

.PHONY: all
all: fpga

.PHONY: fpga
fpga: $(BUILD_DIR)/$(SCRIPT)
	cd $(BUILD_DIR) && $(SYN) $(SYN_FLAGS) -source $(SCRIPT)
	ln -snf $(BUILD_DIR) build-latest

.PHONY: run
run: build-latest
	$(file > $^/conf.tcl,$(CONF_SCRIPT_CONTENTS))
	cd $^ && $(SYN) $(SYN_FLAGS) -source conf.tcl

.PHONY: debug-gui
debug-gui: build-latest
	cd $^ && $(SYN)

$(BUILD_DIR)/$(SCRIPT): $(BUILD_DIR)
	$(file > $@,$(SCRIPT_CONTENTS))

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	$(RM) build-latest

distclean:
	$(RM) -r build-20*
