all: help

# components from component/ whose VHDL is included in builds
COMPONENTS :=
COMPONENTS += clk
COMPONENTS += cpu
COMPONENTS += ddr2
COMPONENTS += dma
COMPONENTS += icache
COMPONENTS += misc
COMPONENTS += uartlite

# libraries from lib/ whose VHDL is included in builds
LIBS :=
LIBS += hwutils
LIBS += reg_file_struct
LIBS += memory_tech_lib

VHDL_DIRS := targets
VHDL_DIRS += $(addprefix components/,$(COMPONENTS))
VHDL_DIRS += $(addprefix lib/,$(LIBS))

# directories to run make in to build tests
TEST_DIRS := components/cpu/tests
TEST_DIRS += components/misc/tests

# some tests need to be built differently
TEST_DIRS2 :=

# directories to run make clean in
CLEAN_DIRS := $(addprefix components/,$(COMPONENTS))
CLEAN_DIRS += $(addprefix lib/,$(LIB))
# only clean those directories that have a Makefile
CLEAN_DIRS := $(foreach d,$(CLEAN_DIRS),$(wildcard $(d)/Makefile))
CLEAN_DIRS := $(dir $(CLEAN_DIRS))
CLEAN_DIRS += tools/tests
CLEAN_DIRS += boot
# ensure all TEST_DIRS are also cleaned
CLEAN_DIRS += $(TEST_DIRS) $(TEST_DIRS2)
CLEAN_DIRS := $(sort $(CLEAN_DIRS))

REVISION := "open"
export REVISION

ISE_VERSION := $(shell xst -help 2>/dev/null | head -1 | sed -n 's/^.*Release \([^ ]*\) .*/\1/p')
export ISE_VERSION

################################################################################
# Gather list of VHDL files
################################################################################

include tools/mk_utils.mk

#$(info VHDL_DIRS $(VHDL_DIRS))
VHDS_ASIC := $(foreach d,$(VHDL_DIRS),$(call include_asic_vhdl,$(d)))
VHDS_ASIC := $(sort $(VHDS_ASIC))

VHDS_FPGA := $(foreach d,$(VHDL_DIRS),$(call include_fpga_vhdl,$(d)))
VHDS_FPGA := $(sort $(VHDS_FPGA))

################################################################################
# Running Tests
################################################################################

# Gather the contents of all TESTS files into a single TESTS file so
# runtests can run them all at once. Alternatively, could modify
# runtests to accept multiple file names.
TEST_BINS := $(foreach d,$(TEST_DIRS) $(TEST_DIRS2),$(addprefix $(d)/,$(shell cat $(firstword $(wildcard $(d)/test_bins) $(wildcard $(d)/TESTS) /dev/null))))
test_bins: force
	rm -f $@
	for t in $(TEST_BINS); do echo "$$t" >> $@; done

build_tests:
	for d in $(TEST_DIRS); do make -C "$$d" || exit 1; done
	for d in $(TEST_DIRS2); do make -C "$$d" taptests || exit 1; done

check: test_bins tools/tests/runtests build_tests
	tools/tests/runtests test_bins

tap: test_bins tools/tests/runtests build_tests
	tools/tests/runtests -t test_bins
# gather the tap files
	rm -rf tap
	mkdir tap
	for t in $(TEST_BINS); do mkdir -p `dirname "tap/$$t"` && cp "$$t.tap" `dirname "tap/$$t"`; done

################################################################################
# Builds boards
################################################################################

# Boards are subdirectories of targets/boards. The tools, environment
# and steps required to build a board are controlled by the Makefile
# in each board direcotry. This soc_top Makefile does four things to
# support the individual boards:
#
# 1. Finds the list of boards and creates Makefile targets for them in
# this Makefile.
#
# 2. When building a board, creates an output directory with a unique
# name which will be the worked directory of the build.
#
# 3. Exports several environment variables that the board makefile can
# use, including the list of all VHDL files.
#
# 4. Dispatch to the board Makefile
#

BOARD_NAMES := $(dir $(wildcard targets/boards/*/Makefile))
BOARD_NAMES := $(foreach D,$(BOARD_NAMES),$(D:%/=%))
BOARD_NAMES := $(notdir $(BOARD_NAMES))
BOARD_NAMES := $(sort $(BOARD_NAMES))
#$(info BOARD_NAMES: $(BOARD_NAMES))

override MAKE_TIME := $(shell date +%Y-%m-%d_%H-%M-%S)

$(BOARD_NAMES): REL_OUTPUT_DIR=output/$(MAKE_TIME)_$@
$(BOARD_NAMES): BOARD_NAME = $@
$(BOARD_NAMES): BOARD_DIR = $(abspath targets/boards/$@)
$(BOARD_NAMES): TOP_DIR := $(abspath .)
$(BOARD_NAMES): TOOLS_DIR := $(abspath tools)
$(BOARD_NAMES): VHDL_FILES := $(VHDS_FPGA)
$(BOARD_NAMES): VHDL_FILES_ASIC := $(VHDS_ASIC)

$(BOARD_NAMES): tools
# create output directory
	@echo "Creating output directory: $(REL_OUTPUT_DIR)"
# create parent output directory with -p
	mkdir -p "$(dir $(REL_OUTPUT_DIR))"
# but create actual output directory without -p so it fails if it
# already exists
	mkdir "$(REL_OUTPUT_DIR)"
# create a handy last_output link
ifneq ($(LAST_OUTPUT),false)
	rm -f last_output
	ln -Tfs "$(REL_OUTPUT_DIR)" last_output
endif
# create a stub Makefile in the output directory that captures the
# above variables so the other targets can be run later
	@echo "REVISION:=$(REVISION)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "ISE_VERSION:=$(ISE_VERSION)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "BOARD_NAME:=$(BOARD_NAME)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "BOARD_DIR:=$(BOARD_DIR)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "TOP_DIR:=$(TOP_DIR)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "OUTPUT_DIR:=$(TOP_DIR)/$(REL_OUTPUT_DIR)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "TOOLS_DIR:=$(TOOLS_DIR)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "VHDL_FILES:=$(VHDL_FILES)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "VHDL_FILES_ASIC:=$(VHDL_FILES_ASIC)" >> "$(REL_OUTPUT_DIR)/Makefile"
	@echo "include ../../targets/boards/$@/Makefile" >> "$(REL_OUTPUT_DIR)/Makefile"

# Run board makefile in with the output working directory
	make -C "$(REL_OUTPUT_DIR)" $(TARGET)

################################################################################
# tools
################################################################################

tools: tools/tests/runtests
	make -C tools/genram

tools/tests/runtests: force
	make -C tools/tests

ifeq ($(wildcard $(TOP_DIR)/soc_gen.jar),)

soc_gen:
	@command -v lein || (printf "***************************************************************************\n****** Cannot find lein tool (http://leiningen.org/) nor soc_gen.jar ******\n****** One is required to run the soc_gen tool.                      ******\n***************************************************************************\n" && false)
	(cd targets/soc_gen; lein run --all "$(BOARDS)")
	@echo "Done"

else

# use packaged soc_gen.jar
soc_gen:
	@echo "Running soc_gen.jar"
	(cd targets/soc_gen; java -jar ../../soc_gen.jar --all "$(BOARDS)")
	@echo "Done"

endif

help:
	@echo "To build a bitstream for a specific board, run 'make <BOARDNAME>' where <BOARDNAME> is one of"
	@for b in $(BOARD_NAMES); do echo "  - $$b"; done
	@echo ""

	@echo "'make check' will build and run a series of GHDL simulation tests"

	@echo ""
	@echo "A tool named soc_gen generates some of the VHDL that goes into the bitstreams"
	@echo "'make soc_gen' will run soc_gen for all boards"
	@echo "'make <BOARDNAME> TARGET=soc_gen' runs soc_gen for a specific board"

	@echo ""
	@echo "See the README file for more information."

clean:
	rm -f test_bins
	rm -rf tap
	for d in $(CLEAN_DIRS); do make -C "$$d" clean || exit 1; done

.PHONY: all help clean force check tap build_tests tools soc_gen $(BOARD_NAMES)
