TOOLS_DIR :=$(wildcard ../../tools)
include $(TOOLS_DIR)/mk_utils.mk

VHDS :=
VHDLS := VHDS
include build.mk
VHDS += $(TOOLS_DIR)/tests/tap/test_pkg.vhd
VHDS += $(wildcard tests/*.vhd)

VHDL_TESTS := flagsync_tb
VHDL_TESTS += flancter_tb
VHDL_TESTS += guardflancter_tb

VHDL_TOPS :=
VHDL_TOPS += $(VHDL_TESTS)

all: $(VHDL_TOPS)

work-obj93.cf: $(VHDS)

RUNTESTS := $(TOOLS_DIR)/tests/runtests
$(RUNTESTS):
	make -C $(TOOLS_DIR)/tests

check: $(RUNTESTS) $(VHDL_TESTS)
	$(RUNTESTS) test_bins

tap: $(RUNTESTS) $(VHDL_TESTS)
	$(RUNTESTS) -t test_bins

include $(TOOLS_DIR)/ghdl.mk

clean:
	rm -f *.cf *.o $(VHDL_TOPS) *_tap *.ghw
	make -C $(TOOLS_DIR)/tests clean

.PHONY: all clean check tap
