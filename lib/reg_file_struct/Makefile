# include common VHDL list
VHDS :=
VHDLS := VHDS
include build.mk

VHDS += tests/bist_rf_tb.vhd
VHDS += tests/rf_tb.vhd
VHDS += tests/marchc_1rf1.vhd
VHDS += tests/marchc_1rf1_bw.vhd
VHDS += tests/marchc_1rf2.vhd
VHDS += tests/marchc_1rf4.vhd
VHDS += tests/marchc_3rf2.vhd
VHDS += tests/marchc_rf1_rf2_rf4.vhd
VHDS += tests/bist_tb_pkg.vhd
VHDS += error/rf2_stuck_bits.vhd
VHDS += tools/tests/tap/test_pkg.vhd

VHDL_TESTS := bist_rf_tb
VHDL_TESTS += marchc_1rf1
VHDL_TESTS += marchc_1rf1_bw
VHDL_TESTS += marchc_1rf2
VHDL_TESTS += marchc_1rf4
VHDL_TESTS += marchc_3rf2
VHDL_TESTS += marchc_rf1_rf2_rf4

VHDL_TOPS := rf_tb
VHDL_TOPS += $(VHDL_TESTS)

TOOLS_DIR := $(firstword $(wildcard ../../tools) tools)

all: $(VHDL_TOPS) check

work-obj93.cf: $(VHDS)

RUNTESTS := $(TOOLS_DIR)/tests/runtests
$(RUNTESTS):
	make -C $(dir $@)

check: $(RUNTESTS) $(VHDL_TESTS)
	$(RUNTESTS) tests/TESTS

tap: $(RUNTESTS) $(VHDL_TESTS)
	$(RUNTESTS) -t tests/TESTS

include $(TOOLS_DIR)/ghdl.mk

clean:
	rm -f *.cf *.o $(VHDL_TOPS) *_tap
	make -C $(dir $(RUNTESTS)) clean

.PHONY: all clean check tap
