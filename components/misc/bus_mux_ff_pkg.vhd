-- Refer to HS2J0 CPU cocre datasheet for the following defination
-- Weibin

library ieee;
use ieee.std_logic_1164.all;
use work.cpu2j0_pack.all;

package bus_mux_ff_pkg is
  component multi_master_bus_muxff is port (
    rst : in std_logic;
    clk : in std_logic;
    m1_i : out cpu_data_i_t;
    m1_o : in cpu_data_o_t;
    m2_i : out cpu_data_i_t;
    m2_o : in cpu_data_o_t;
    slave_i : in cpu_data_i_t;
    slave_o : out cpu_data_o_t;
    sel_m2 : out std_logic
  );
  end component;
end package;
