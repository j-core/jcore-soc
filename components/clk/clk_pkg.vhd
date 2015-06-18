library ieee;
use ieee.std_logic_1164.all;

package clk_pack is 
  component dds_18432 is 
    generic (c_busperiod : integer := 40);
    port (
      cin_50mhz  : in std_logic;
      rst_i      : in std_logic;
      cout_18432 : out std_logic);
  end component dds_18432;
  component clk_gate is
    port (
      clk_i     : in std_logic;
      clk2x_o   : out std_logic;
      clkfx_o   : out std_logic;
      reset_i   : in std_logic;
      reset_o   : out std_logic;
      clk90sh_o : out std_logic;
      clklock_o : out std_logic;
      clk0      : out std_logic;
      clk90     : out std_logic;
      clk180    : out std_logic;
      clk270    : out std_logic);
  end component clk_gate;
end clk_pack;
