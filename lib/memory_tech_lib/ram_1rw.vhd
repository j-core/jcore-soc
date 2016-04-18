-- RAM with 1 read/write port, sync reads and writes.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.memory_pack.all;
entity ram_1rw is
  generic (
    SUBWORD_WIDTH : natural;
    SUBWORD_NUM : natural;
    ADDR_WIDTH : natural;
    CHECK_DIMENSIONS : boolean := true);
  port (
    rst : in  std_logic;
    clk : in  std_logic;
    en  : in  std_logic;
    wr  : in  std_logic;
    we  : in  std_logic_vector(SUBWORD_NUM-1 downto 0);
    a   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    dw  : in  std_logic_vector(SUBWORD_WIDTH*SUBWORD_NUM-1 downto 0);
    dr  : out std_logic_vector(SUBWORD_WIDTH*SUBWORD_NUM-1 downto 0);
    margin : in std_logic_vector(1 downto 0));

  -- This 1 read/write port RAM can be implemented with different underlying
  -- macros, and multiple copies of the macros can be instantiated to support
  -- different sizes of RAM.
  type mem_type_t is (INVALID, RAM_18x2048, RAM_2x8x256);
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
    if SUBWORD_WIDTH = 18 and SUBWORD_NUM = 1 and ADDR_WIDTH >= 11 then
      r.t := RAM_18x2048;
      r.bank_addr_width := 11;
      r.rows := 2**(ADDR_WIDTH - r.bank_addr_width);
      r.cols := 1;
    elsif SUBWORD_WIDTH = 8 and SUBWORD_NUM = 2 and ADDR_WIDTH >= 8 then
      r.t := RAM_2x8x256;
      r.bank_addr_width := 8;
      r.rows := 2**(ADDR_WIDTH - r.bank_addr_width);
      r.cols := 1;
    end if;
    return r;
  end function;

begin
  assert not CHECK_DIMENSIONS or memory_layout(1).t /= INVALID
    report "Invalid memory dimensions" severity failure;
end entity;
