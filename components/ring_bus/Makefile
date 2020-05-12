# include common VHDL list
VHDS :=
VHDLS := VHDS
include build.mk

VHDS += tests/ring_bus_tb.vhd
VHDS += tests/node_tap.vhd
VHDS += tests/word_tap.vhd
VHDS += tests/data_bus_adapter_tap.vhd
VHDS += tests/rbus_data_master_tap.vhd

VHDS += ../cpu/cpu2j0_pkg.vhd

VHDL_TESTS := node_tap word_tap data_bus_adapter_tap rbus_data_master_tap

VHDL_TOPS := ring_bus_tb
VHDL_TOPS += $(VHDL_TESTS)

TOOLS_DIR := $(firstword $(wildcard ../mcu_lib/tools) $(wildcard ../../tools))
RUNTESTS := $(TOOLS_DIR)/tests/runtests

VHDS += $(TOOLS_DIR)/tests/tap/test_pkg.vhd

all: $(VHDL_TOPS) $(VHDL_TESTS)

work-obj93.cf: $(VHDS)

$(RUNTESTS):
	make -C $(TOOLS_DIR)/tests

check: $(RUNTESTS) $(VHDL_TESTS)
	$(RUNTESTS) test_bins

tap: $(RUNTESTS) $(VHDL_TESTS)
	$(RUNTESTS) -t test_bins

# add additional dependencies caused by #include directives
node8b.vhm: node.vhm
node9b.vhm: node.vhm
ring_bus_pkg_body.vhd: ring_bus_pkg_body_generic.vhd

include $(TOOLS_DIR)/ghdl.mk

clean:
	rm -f *.cf *.o $(VHDL_TOPS) *_tap
	rm -f node.vhd node8b.vhd node9b.vhd node8b.vhm node9b.vhm

.PHONY: all clean check
