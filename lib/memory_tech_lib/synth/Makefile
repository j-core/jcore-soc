TOP_DIR := $(abspath ../../..)
MEM_TECH_LIB := $(abspath ..)
TOOLS_DIR := $(TOP_DIR)/tools
project = synth

all:
	rm -rf output
	mkdir output
	make -C output -f ../Makefile $(project).ngc TOP_DIR=$(TOP_DIR) MEM_TECH_LIB=$(MEM_TECH_LIB)

synth.ngc: force

include $(TOOLS_DIR)/mk_utils.mk

vhdlfiles := ../mem_top.vhd
vhdlfiles += $(MEM_TECH_LIB)/tests/memories.vhd
vhdlfiles += $(MEM_TECH_LIB)/tests/mem_test_pkg.vhd
vhdlfiles += $(call include_vhdl,$(MEM_TECH_LIB))

top_module = mem_top
part = xc6slx45-2-csg324
optfile = $(TOP_DIR)/xilinx.opt $(TOP_DIR)/withoutpads.opt

include $(TOOLS_DIR)/xilinx.mk

.PHONY: all force
