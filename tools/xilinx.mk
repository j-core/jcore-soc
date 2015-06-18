# The top level module should define the variables below then include
# this file.  The files listed should be in the same directory as the
# Makefile.  
#
#   variable	description
#   ----------  -------------
#   project	project name (top level module should match this name)
#   top_module  top level module of the project
#   vfiles	all local .v files
#   vhdlfiles   all local .vhd files
#   ucffile     user contraint file
#   part        FPGA part name (xc4vfx12-10-sf363)
#   part2        FPGA part name (xc4vfx12-sf363-10)
#   flashsize   size of flash for mcs file (16384)
#   optfile     (optional) xst extra opttions file to put in .scr
#   map_opts    (optional) options to give to map
#   par_opts    (optional) options to give to par
#   bitgen_opts (optional) options to give to bitgen
#   promgen_opts (optional) options to give to promgen
#   intstyle    (optional) intstyle option to all tools

top_module ?= $(project)
map_opts ?= -ol high -w
par_opts ?= -ol high
promgen_opts ?= -spi -data_width 8
flashsize ?= 512

twr: $(project).twr $(project).post_map.twr
etwr: $(project)_err.twr

$(project).mcs: $(project).bit
	promgen -w -s $(flashsize) -p mcs $(promgen_opts) -o $@ -u 0 $^

$(project).bin: $(project).mcs
	promgen -w -p bin -r $^

$(project).bit: $(project)_par.ncd
	bitgen $(intstyle) -g DriveDone:yes -g StartupClk:Cclk $(bitgen_opts) -w $(project)_par.ncd $(project).bit

$(project)_par.ncd: $(project).ncd
	par $(intstyle) $(par_opts) -w $(project).ncd $(project)_par.ncd

$(project).ncd: $(project).ngd
	map $(intstyle) $(map_opts) $<

$(project).ucf : $(ucffile)
	cat $^ /dev/null > $@.temp
	cmp -s $@.temp $@ || mv $@.temp $@
	rm -f $@.temp

$(project).ngd: $(project).ngc $(project).ucf
	ngdbuild $(intstyle) $(project).ngc -uc $(project).ucf -p $(part2) $@

$(project).ngc: $(vfiles) $(vhdlfiles) $(project).scr $(project).prj
	@command -v xst || ( printf "**************************************************************************\n******* Cannot find xst. Have you sourced the xilinx settings file? ******\n******* ex: source /opt/Xilinx/13.1/ISE_DS/settings32.sh            ******\n**************************************************************************\n" && false )
	xst $(intstyle) -ifn $(project).scr -ofn $(project).syr

$(project).prj: $(vfiles) $(vhdlfiles) $(project).ucf force
	rm -f $(project).tmpprj
	for src in $(vfiles); do echo "verilog work $$src" >> $(project).tmpprj; done
# support .v files in the vhdfiles variable by filtering them out and
# treating them as verilog. It can be easier to do this than to build
# separate lists in some cases
	for src in $(filter %.v,$(vhdlfiles)); do echo "verilog work $$src" >> $(project).tmpprj; done
	for src in $(filter-out %.v,$(vhdlfiles)); do echo "vhdl work $$src" >> $(project).tmpprj; done
	sort -u $(project).tmpprj > $(project).sortprj
# only replace the real prj if the new one is different to prevent
# unneeded rebuilding
	cmp -s $(project).sortprj $@ || mv $(project).sortprj $@
	rm -f $(project).tmpprj $(project).sortprj

$(project).scr: $(optfile) force
	echo "run" > $@.temp
	echo "-p $(part)" >> $@.temp
	echo "-top $(top_module)" >> $@.temp
	echo "-ifn $(project).prj" >> $@.temp
	echo "-ofn $(project)" >> $@.temp
	echo "-ofmt NGC" >> $@.temp
	cat $(optfile) /dev/null >> $@.temp
# only replace the real .scr if the new one is different to prevent
# unneeded rebuilding
	cmp -s $@.temp $@ || mv $@.temp $@
	rm -f $@.temp

$(project).post_map.twr:
	trce -v 10 -l 3 -u 3 -fastpaths -timegroups $(project).ncd $(project).pcf -o $@ -ucf $(project).ucf

$(project).twr:
	trce -v 3 -tsi $(project).tsi -l 3 -u 3 -fastpaths -timegroups $(project)_par.ncd $(project).pcf -o $(project).twr -ucf $(project).ucf

$(project)_err.twr:
	trce -e 10 -l 3 -u 3 $(project)_par.ncd $(project).pcf -o $(project)_err.twr -ucf $(project).ucf

smartxplorer: $(project).ucf $(project).ngc
	smartxplorer -p $(part2) -uc $(project).ucf -wd smartxplorer_$(project) $(project).ngc

.PHONY: twr etwr force smartxplorer
