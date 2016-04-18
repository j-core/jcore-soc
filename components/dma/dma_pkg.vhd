library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.bist_pack.all;
use work.cpu2j0_pack.all;

package dma_pack is

constant DMA_ADDR_WIDTH            : natural := 32; -- 4G Byte
constant DMA_DDR_BUS_WIDTH         : natural := 32;

  type bus_ddr_o_t is record
    en       : std_logic;
    a        : std_logic_vector(DMA_ADDR_WIDTH-1         downto 0);
    d        : std_logic_vector(DMA_DDR_BUS_WIDTH-1   downto 0);
    wr       : std_logic;
    we       : std_logic_vector(DMA_DDR_BUS_WIDTH/8-1 downto 0);
    burst32  : std_logic;
    burst16  : std_logic;
  end record;

  type bus_ddr_i_t is record
    d       : std_logic_vector(DMA_DDR_BUS_WIDTH-1    downto 0);
    ack     : std_logic;
  end record;

  -- functions for connecting bus_ddr and cpu_data buses
  function to_cpu_data(i : bus_ddr_o_t) return cpu_data_o_t;
  function to_bus_ddr(i : cpu_data_i_t) return bus_ddr_i_t;

  function loopback_bus(i : bus_ddr_o_t) return bus_ddr_i_t;
end package;

package body dma_pack is

  function to_cpu_data(i : bus_ddr_o_t) return cpu_data_o_t is
    variable o : cpu_data_o_t;
  begin
    o.en := i.en;
    o.a  := i.a;
    o.d  := i.d;
    o.wr := i.wr;
    o.rd := i.en and (not i.wr);
    o.we := i.we;
    return o;
  end function;

  function to_bus_ddr(i : cpu_data_i_t) return bus_ddr_i_t is
    variable o : bus_ddr_i_t;
  begin
    o.d   := i.d;
    o.ack := i.ack;
    return o;
  end function;

  function loopback_bus(i : bus_ddr_o_t) return bus_ddr_i_t is
    variable o : bus_ddr_i_t;
  begin
    o.ack := i.en;
    o.d   := (others => '0');
    return o;
  end function;

end dma_pack;



