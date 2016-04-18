-- RAM with 2 read/write port, sync reads and writes.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.memory_pack.all;
entity ram_2rw is
  generic (
    SUBWORD_WIDTH : natural;
    SUBWORD_NUM : natural;
    ADDR_WIDTH : natural;
    CHECK_DIMENSIONS : boolean := true);
  port (
    rst0 : in  std_logic;
    clk0 : in  std_logic;
    en0  : in  std_logic;
    wr0  : in  std_logic;
    we0  : in  std_logic_vector(SUBWORD_NUM-1 downto 0);
    a0   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    dw0  : in  std_logic_vector(SUBWORD_WIDTH*SUBWORD_NUM-1 downto 0);
    dr0  : out std_logic_vector(SUBWORD_WIDTH*SUBWORD_NUM-1 downto 0);
    rst1 : in  std_logic;
    clk1 : in  std_logic;
    en1  : in  std_logic;
    wr1  : in  std_logic;
    we1  : in  std_logic_vector(SUBWORD_NUM-1 downto 0);
    a1   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    dw1  : in  std_logic_vector(SUBWORD_WIDTH*SUBWORD_NUM-1 downto 0);
    dr1  : out std_logic_vector(SUBWORD_WIDTH*SUBWORD_NUM-1 downto 0);
    margin0 : in std_logic;
    margin1 : in std_logic);

  -- This 2 read/write port RAM can be implemented with different underlying
  -- macros, and multiple copies of the macros can be instantiated to support
  -- different sizes of RAM.
  type mem_type_t is (INVALID, RAM_32x1x512, RAM_2x8x2048);
  type mem_layout_t is record
    t : mem_type_t;
    -- a 2-d grid of fixed-size memories is used to implement larger memories.
    rows : natural range 1 to 8; -- more rows = more addressable words
    cols : natural range 1 to 2; -- more cols = wider data words
    bank_addr_width : natural;
    we_scale : natural;
  end record;

  -- Determine the memory layout (type and number) from the dimension generics.
  -- The body of this function can access the generics directly, but function
  -- need some argument.
  function memory_layout(dummy : natural) return mem_layout_t is
    variable r : mem_layout_t := ( INVALID, 1, 1, 0, 1 );
  begin
    -- only support the exact underlying dimensions for now.
    -- TODO: Expand this to support larger dimensions
    -- TODO: Support subword_width > 1 and < 8 using the RAM_32x1x512
    if SUBWORD_WIDTH = 8 and SUBWORD_NUM = 2 and ADDR_WIDTH >= 11 then
      r.t := RAM_2x8x2048;
      r.bank_addr_width := 11;
      r.rows := 2**(ADDR_WIDTH - r.bank_addr_width);
      r.cols := 1;
    elsif SUBWORD_WIDTH = 1 and SUBWORD_NUM = 32 and ADDR_WIDTH >= 9 then
      r.t := RAM_32x1x512;
      r.bank_addr_width := 9;
      r.rows := 2**(ADDR_WIDTH - r.bank_addr_width);
      r.cols := 1;
    elsif SUBWORD_WIDTH = 8 and SUBWORD_NUM = 4 and ADDR_WIDTH >= 9 then
      r.t := RAM_32x1x512;
      r.bank_addr_width := 9;
      r.rows := 2**(ADDR_WIDTH - r.bank_addr_width);
      r.cols := 1;
      r.we_scale := 8;
    end if;
    return r;
  end function;

begin
  assert not CHECK_DIMENSIONS or memory_layout(1).t /= INVALID
    report "Invalid memory dimensions" severity failure;
end entity;
