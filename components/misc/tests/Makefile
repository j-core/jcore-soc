TOOLSDIR := $(firstword $(wildcard ../../mcu_lib/tools) $(wildcard ../../../tools))
RUNTESTS := $(TOOLSDIR)/tests/runtests

VHDS := ../gpio_pkg.vhd
VHDS += ../gpio.vhd
VHDS += ../bus_mux_pkg.vhd
VHDS += ../multi_master_bus_mux.vhd
VHDS += ../spi2.vhd

#VHDS += bus_mux_typec_tb.vhh
VHDS += gpio_tap.vhd
VHDS += i2cb_tb.vhd
VHDS += multi_master_bus_mux_tap.vhd
VHDS += spi_tb.vhd

VHDS += ../../cpu/cpu2j0_pkg.vhd
VHDS += ../i2cb.vhd
VHDS += ../../../lib/hwutils/attr_pkg.vhd
VHDS += $(TOOLSDIR)/tests/tap/test_pkg.vhd

$(info VHDS $(VHDS))

VHDL_TESTS := gpio_tap
VHDL_TESTS += multi_master_bus_mux_tap
VHDL_TESTS += i2cb_tb
VHDL_TESTS += spi_tb
VHDL_TOPS := $(VHDL_TESTS)

V2P := $(TOOLSDIR)/v2p

all: $(VHDL_TOPS)

i2cb_tb.ghw: i2cb_tb
	./i2cb_tb --wave=i2cb_tb.ghw

work-obj93.cf: $(VHDS)

check: all $(RUNTESTS)
	$(RUNTESTS) TESTS

tap: all $(RUNTESTS)
	$(RUNTESTS) -t TESTS

$(RUNTESTS):
	make $(TOOLSDIR)/tests

include $(TOOLSDIR)/ghdl.mk

clean:
	rm -f *.o $(VHDL_TOPS) *.cf *.tap
	rm -f gpio.vhd

.PHONY: all clean check
