-- ROM with 1 read port and sync reads.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.memory_pack.all;
entity rom_1r is
  generic (
    DATA_WIDTH : natural;
    ADDR_WIDTH : natural;
    CHECK_DIMENSIONS : boolean := true);
  port (
    clk : in  std_logic;
    en  : in  std_logic;
    a   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    d   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    margin : in std_logic);

  -- This 1 read port ROM has only one underlying macro but the types and
  -- function below follow the same pattern as the other RAMs which do have
  -- multiple memories..
  type mem_type_t is (INVALID, ROM_32x2048);
  type mem_layout_t is record
    t : mem_type_t;
    -- a 2-d grid of fixed-size memories is used to implement larger memories.
    rows : natural range 1 to 8; -- more rows = more addressable words
    cols : natural range 1 to 2; -- more cols = wider data words
    bank_addr_width : natural;
  end record;

  -- Determine the memory layout (type and number) from the dimension generics.
  -- The body of this function can access the generics directly, but function
  -- need some argument.
  function memory_layout(dummy : natural) return mem_layout_t is
    variable r : mem_layout_t := ( INVALID, 1, 1, 0 );
  begin
    -- only support the exact underlying dimensions for now.
    -- TODO: Expand this to support larger dimensions
    if DATA_WIDTH = 32 and ADDR_WIDTH >= 11 then
      r.t := ROM_32x2048;
      r.bank_addr_width := 11;
      r.rows := 2**(ADDR_WIDTH - r.bank_addr_width);
      r.cols := 1;
    end if;
    return r;
  end function;

begin
  assert not CHECK_DIMENSIONS or memory_layout(1).t /= INVALID
    report "Invalid memory dimensions" severity failure;
end entity;
