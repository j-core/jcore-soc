#!/bin/sh
perl v2p < uart.vhm > uart.vhd
ghdl -a uart_pkg.vhd
ghdl -a uart.vhd
ghdl -a tests/uart_tb.vhd
ghdl -r uart_tb --stop-time=1500uS --wave=tests/uart_tb.ghw
