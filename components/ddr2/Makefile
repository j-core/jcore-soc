VHDS :=
VHDS += sim_config.vhd
VHDS += sm_tb.vhd
VHDS += ../cpu/cpu2j0_pkg.vhd
VHDS += ../../targets/data_bus_pkg.vhd

VHDLS := VHDS
include build.mk

TOOLS_DIR := ../../tools
include $(TOOLS_DIR)/mk_utils.mk

VHDS += $(call include_vhdl,../../lib/hwutils)
VHDS += $(call include_vhdl,../icache)

VHDL_TOPS := sm_tb

all: $(VHDL_TOPS)

work-obj93.cf: $(VHDS)

sm_tb.ghw: $(VHDL_TOPS)
	./sm_tb --wave=$@ --stop-time=200nS

include $(TOOLS_DIR)/ghdl.mk

clean:
	rm -f *.cf *.o $(VHDL_TOPS) *_tap *.ghw
	rm -f updown.vhd

.PHONY: all clean
