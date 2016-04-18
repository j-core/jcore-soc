library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mem_test_pack is
  type mem_type is (
    ROM_GEN_32x2048_1R,
    ROM_FIXED_32x2048_1R,
    RAM_GEN_2x8x256_1RW,
    RAM_FIXED_2x8x256_1RW,
    RAM_GEN_18x2048_1RW,
    RAM_FIXED_18x2048_1RW,
    RAM_GEN_2x8x1024_1RW,
    RAM_GEN_2x8x2048_2RW,
    RAM_FIXED_2x8x2048_2RW,
    RAM_GEN_32x1x512_2RW,
    RAM_FIXED_32x1x512_2RW
  );
  type enables_t is array (mem_type'left to mem_type'right) of std_logic;
  type data_width_t is array (mem_type'left to mem_type'right) of integer;
  type mem_type_list is array (integer range <>) of mem_type;

  constant data_widths : data_width_t := (
    32,
    32,
    16,
    16,
    18,
    18,
    16,
    16,
    16,
    32,
    32
  );
  constant one_port_roms : mem_type_list := (
    ROM_GEN_32x2048_1R,
    ROM_FIXED_32x2048_1R
  );
  constant one_port_rams : mem_type_list := (
    RAM_GEN_2x8x256_1RW,
    RAM_FIXED_2x8x256_1RW,
    RAM_GEN_18x2048_1RW,
    RAM_FIXED_18x2048_1RW,
    RAM_GEN_2x8x1024_1RW
  );
  constant two_port_rams : mem_type_list := (
    RAM_GEN_2x8x2048_2RW,
    RAM_FIXED_2x8x2048_2RW,
    RAM_GEN_32x1x512_2RW,
    RAM_FIXED_32x1x512_2RW
  );

  constant MEMS_ADDR_WIDTH : integer := 32;
  constant MEMS_DATA_WIDTH : integer := 32;

  type data_array_t is array (mem_type'left to mem_type'right)
    of std_logic_vector(MEMS_DATA_WIDTH-1 downto 0);

  type mem_port is record
    en : std_logic;
    wr : std_logic;
    we : std_logic_vector(31 downto 0);
    a : std_logic_vector(MEMS_ADDR_WIDTH-1 downto 0);
    dw : std_logic_vector(MEMS_DATA_WIDTH-1 downto 0);
  end record;
  constant MEM_PORT_NOP : mem_port :=
    ('0', '0', (others => '0'), (others => '0'), (others => '0'));

  function readmem(addr : integer) return mem_port;
  function writemem(addr : integer;
                    data : std_logic_vector(MEMS_DATA_WIDTH-1 downto 0);
                    we : std_logic_vector := x"FFFFFFFF")
  return mem_port;

  component memories is
    generic (
      FOR_SYNTHESIS : boolean := true);
    port (
      rst0 : in std_logic;
      clk0 : in std_logic;
      rst1 : in std_logic;
      clk1 : in std_logic;
      select_mem : in mem_type;
      p0 : in mem_port;
      p1 : in mem_port;
      dr0 : out data_array_t;
      dr1 : out data_array_t);
  end component;
end package;

package body mem_test_pack is
  function readmem(addr : integer) return mem_port is
    variable r : mem_port := MEM_PORT_NOP;
  begin
    r.en := '1';
    r.a := std_logic_vector(to_unsigned(addr, r.a'length));
    return r;
  end function;

  function writemem(addr : integer;
                    data : std_logic_vector(MEMS_DATA_WIDTH-1 downto 0);
                    we : std_logic_vector := x"FFFFFFFF")
  return mem_port is
    alias we2 : std_logic_vector(we'length - 1 downto 0) is we;
    variable r : mem_port := MEM_PORT_NOP;
  begin
    r.en := '1';
    r.wr := '1';
    r.we(we2'left downto 0) := we2;
    r.a := std_logic_vector(to_unsigned(addr, r.a'length));
    r.dw := data;
    return r;
  end function;
end package body;
