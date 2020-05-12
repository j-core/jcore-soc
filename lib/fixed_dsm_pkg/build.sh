#!/bin/sh

rm *.o *.cf
ghdl -a ieee/fixed_float_types_c.vhd
ghdl -a ieee/fixed_pkg_c.vhd

ghdl -a fixed_dsm_pkg.vhd

ghdl -a test.vhd

ghdl -e fdm_tb
ghdl -r fdm_tb --wave=fdm_tb.ghw

ghdl -a test_cordic.vhd

ghdl -e cordic_tb
ghdl -r cordic_tb
