-- Generates cpu and mem clocks from an input 25MHz clock. There are different
-- architectures for different FPGA families.

library ieee;
use ieee.std_logic_1164.all;

use work.attr_pack.all;

entity clkin25_clkgen is
  generic (
    CLK_CPU_DIVIDE    : natural;
    CLK_MEM_2X_DIVIDE : natural);
  port (
    -- Clock in ports
    clk_in     : in  std_logic;
    -- Clock out ports
    clk_cpu    : out std_logic;
    clk_mem    : out std_logic;
    clk_mem_90 : out std_logic;
    clk_mem_2x : out std_logic;
    -- Status and control signals
    rst        : in  std_logic;
    lock       : out std_logic);
  -- synopsys translate_off
  group ext_sigs : global_ports(
    clk_cpu,
    clk_mem,
    clk_mem_90,
    clk_mem_2x);
  -- synopsys translate_on
end entity;
