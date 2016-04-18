-- Generates bitlink clocks from an input 10MHz clock. There are different
-- architectures for different FPGA families.

library ieee;
use ieee.std_logic_1164.all;

use work.attr_pack.all;

entity clkin10_clkgen is
  port (
    -- Clock in ports
    clk_in         : in  std_logic;
    -- Clock out ports
    clk_bitlink    : out std_logic;
    clk_bitlink_2x : out std_logic;
    -- Status and control signals
    rst            : in  std_logic;
    lock           : out std_logic);
  -- synopsys translate_off
  group ext_sigs : global_ports(
    clk_bitlink,
    clk_bitlink_2x);
  -- synopsys translate_on
end entity;
