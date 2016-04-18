library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package memory_pack is

-- RAM with 1 read/write port, sync reads and writes.
component ram_1rw is
  generic (
    SUBWORD_WIDTH : natural;
    SUBWORD_NUM : natural;
    ADDR_WIDTH : natural);
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
end component;

-- RAM with 1 read/write port, sync reads and writes, 18 bits wide, and 2048
-- entries deep.
component ram_18x2048_1rw is
  port (
    rst : in  std_logic;
    clk : in  std_logic;
    en  : in  std_logic;
    wr  : in  std_logic;
    a   : in  std_logic_vector(10 downto 0);
    dw  : in  std_logic_vector(17 downto 0);
    dr  : out std_logic_vector(17 downto 0);
    margin : in std_logic_vector(1 downto 0));
end component;

-- RAM with 1 read/write port, sync reads and writes, 16 bits wide with 2 8-bit
-- byte write select inputs, and 256 entries deep.
component ram_2x8x256_1rw is
  port (
    rst : in  std_logic;
    clk : in  std_logic;
    en  : in  std_logic;
    wr  : in  std_logic;
    we  : in  std_logic_vector( 1 downto 0);
    a   : in  std_logic_vector( 7 downto 0);
    dw  : in  std_logic_vector(15 downto 0);
    dr  : out std_logic_vector(15 downto 0);
    margin : in std_logic_vector(1 downto 0));
end component;

-- RAM with 2 read/write port, sync reads and writes.
component ram_2rw is
  generic (
    SUBWORD_WIDTH : natural;
    SUBWORD_NUM : natural;
    ADDR_WIDTH : natural);
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
end component;

-- RAM with 2 read/write ports, sync reads and writes, 16 bits wide with 2 8-bit
-- byte write select inputs, and 2048 entries deep.
component ram_2x8x2048_2rw is
  port (
    rst0 : in  std_logic;
    clk0 : in  std_logic;
    en0  : in  std_logic;
    wr0  : in  std_logic;
    we0  : in  std_logic_vector( 1 downto 0);
    a0   : in  std_logic_vector(10 downto 0);
    dw0  : in  std_logic_vector(15 downto 0);
    dr0  : out std_logic_vector(15 downto 0);
    rst1 : in  std_logic;
    clk1 : in  std_logic;
    en1  : in  std_logic;
    wr1  : in  std_logic;
    we1  : in  std_logic_vector( 1 downto 0);
    a1   : in  std_logic_vector(10 downto 0);
    dw1  : in  std_logic_vector(15 downto 0);
    dr1  : out std_logic_vector(15 downto 0);
    margin0 : in std_logic;
    margin1 : in std_logic);
end component;

-- RAM with 1 read/write port, sync reads and writes, 32 bits wide with 32
-- 1-bit write select inputs, and 512 entries deep.
component ram_32x1x512_2rw is
  port (
    rst0 : in  std_logic;
    clk0 : in  std_logic;
    en0  : in  std_logic;
    wr0  : in  std_logic;
    we0  : in  std_logic_vector(31 downto 0);
    a0   : in  std_logic_vector( 8 downto 0);
    dw0  : in  std_logic_vector(31 downto 0);
    dr0  : out std_logic_vector(31 downto 0);
    rst1 : in  std_logic;
    clk1 : in  std_logic;
    en1  : in  std_logic;
    wr1  : in  std_logic;
    we1  : in  std_logic_vector(31 downto 0);
    a1   : in  std_logic_vector( 8 downto 0);
    dw1  : in  std_logic_vector(31 downto 0);
    dr1  : out std_logic_vector(31 downto 0);
    margin0 : in std_logic;
    margin1 : in std_logic);
end component;

-- ROM with 1 read port and sync reads.
component rom_1r is
  generic (
    DATA_WIDTH : natural;
    ADDR_WIDTH : natural);
  port (
    clk : in  std_logic;
    en  : in  std_logic;
    a   : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    d   : out std_logic_vector(DATA_WIDTH-1 downto 0);
    margin : in std_logic);
end component;

-- ROM with 1 read port, sync reads, 32 bits wide, and 2048 entries deep.
component rom_32x2048_1r is
  port (
    clk : in  std_logic;
    en  : in  std_logic;
    a   : in  std_logic_vector(10 downto 0);
    d   : out std_logic_vector(31 downto 0);
    margin : in std_logic);
end component;

constant RAM32X32_WIDTH : natural := 32;
constant RAM32X32_DEPTH : natural := 32;
constant RAM32X32_BYTES : natural := RAM32X32_WIDTH/8;

type ram_read_type_t is ( ASYNC, SYNC0, SYNC1 );

subtype ram_32x32_d_t is std_logic_vector(RAM32X32_WIDTH-1 downto 0);
type ram_32x32_d_vector_t is array (natural range <>) of ram_32x32_d_t;

type ram_32x32_w_t is record
   a   : integer range 0 to RAM32X32_DEPTH-1;
   d   : ram_32x32_d_t;
   wr  : std_logic;
   we  : std_logic_vector(RAM32X32_BYTES-1 downto 0);
end record;

type ram_32x32_r_t is record
   a   : integer range 0 to RAM32X32_DEPTH-1;
end record;

type ram_32x32_r_vector_t is array (natural range <>) of ram_32x32_r_t;
 
type ram_32x32_1w2r_t is record
   w   : ram_32x32_w_t;
   r   : ram_32x32_r_vector_t(0 to 1);
end record;

constant ASYNCRAM_32X32_1W2R_RESET : ram_32x32_1w2r_t := (
   w=> ( 0, (others => '0'), '0', (others => '0') ) ,
   r=> ( (a => 0), (a => 0) ) );

procedure read (M : inout ram_32x32_1w2r_t; P : in integer; A : in integer);
procedure write(M : inout ram_32x32_1w2r_t; A : in integer; D : in std_logic_vector);
procedure write(M : inout ram_32x32_1w2r_t; A : in integer; D : in std_logic_vector; B : in std_logic_vector);
procedure write_disable(M : inout ram_32x32_1w2r_t);

component ram_32x32 is
   generic (
   read : ram_read_type_t := ASYNC);
   port (
   clk : in  std_logic;
   w   : in  ram_32x32_w_t;
   r   : in  ram_32x32_r_t;
   d   : out ram_32x32_d_t);
end component;

constant RAM32X2048_WIDTH : natural := 32;
constant RAM32X2048_DEPTH : natural := 2048;
constant RAM32X2048_BYTES : natural := RAM32X2048_WIDTH/8;

subtype ram_32x2048_d_t is std_logic_vector(RAM32X2048_WIDTH-1 downto 0);
type ram_32x2048_d_vector_t is array (natural range <>) of ram_32x2048_d_t;

type ram_32x2048_w_t is record
   a   : integer range 0 to RAM32X2048_DEPTH-1;
   d   : ram_32x2048_d_t;
   wr  : std_logic;
   we  : std_logic_vector(RAM32X2048_BYTES-1 downto 0);
end record;

type ram_32x2048_r_t is record
   a   : integer range 0 to RAM32X2048_DEPTH-1;
end record;

type ram_32x2048_r_vector_t is array (natural range <>) of ram_32x2048_r_t;
 
type ram_32x2048_1w2r_t is record
   w   : ram_32x2048_w_t;
   r   : ram_32x2048_r_vector_t(0 to 1);
end record;

constant ASYNCRAM_32X2048_1W2R_RESET : ram_32x2048_1w2r_t := (
   w=> ( 0, (others => '0'), '0', (others => '0') ) ,
   r=> ( (a => 0), (a => 0) ) );

procedure read (M : inout ram_32x2048_1w2r_t; P : in integer; A : in integer);
procedure write(M : inout ram_32x2048_1w2r_t; A : in integer; D : in std_logic_vector);
procedure write(M : inout ram_32x2048_1w2r_t; A : in integer; D : in std_logic_vector; B : in std_logic_vector);
procedure write_disable(M : inout ram_32x2048_1w2r_t);

component ram_32x2048 is
   generic (
   read : ram_read_type_t := ASYNC);
   port (
   clk : in  std_logic;
   w   : in  ram_32x2048_w_t;
   r   : in  ram_32x2048_r_t;
   d   : out ram_32x2048_d_t);
end component;

function mask_bits(en : std_logic; bits : std_logic_vector) return std_logic_vector;

function expand_bits(bits : std_logic_vector; n : natural) return std_logic_vector;

end memory_pack;

package body memory_pack is

procedure read(M : inout ram_32x32_1w2r_t; P : in integer; A : in integer) is
begin
   M.r(P).a := A;
end read;

procedure write(M : inout ram_32x32_1w2r_t; A : in integer; D : in std_logic_vector) is
begin
   M.w.a    := A;
   M.w.d    := D;
   M.w.wr   := '1';
   M.w.we   := (others => '1');
end write;

procedure write(M : inout ram_32x32_1w2r_t; A : in integer; D : in std_logic_vector; B : in std_logic_vector) is
begin
   M.w.a    := A;
   M.w.d    := D;
   M.w.wr   := '1';
   M.w.we   := B;
end write;

procedure write_disable(M : inout ram_32x32_1w2r_t) is
begin
   M.w.wr   := '0';
   m.w.we   := (others => '0');
end write_disable;

procedure read(M : inout ram_32x2048_1w2r_t; P : in integer; A : in integer) is
begin
   M.r(P).a := A;
end read;

procedure write(M : inout ram_32x2048_1w2r_t; A : in integer; D : in std_logic_vector) is
begin
   M.w.a    := A;
   M.w.d    := D;
   M.w.wr   := '1';
   M.w.we   := (others => '1');
end write;

procedure write(M : inout ram_32x2048_1w2r_t; A : in integer; D : in std_logic_vector; B : in std_logic_vector) is
begin
   M.w.a    := A;
   M.w.d    := D;
   M.w.wr   := '1';
   M.w.we   := B;
end write;

procedure write_disable(M : inout ram_32x2048_1w2r_t) is
begin
   M.w.wr   := '0';
   m.w.we   := (others => '0');
end write_disable;

function mask_bits(en : std_logic; bits : std_logic_vector) return std_logic_vector is
  alias bitsv : std_logic_vector(bits'length - 1 downto 0) is bits;
  variable r : std_logic_vector(bits'length - 1 downto 0) := (others => '0');
begin
  if en = '1' then
    r := bitsv;
  end if;
  return r;
end function;

-- Returns an slv that repeates each bit in a given slv N times
function expand_bits(bits : std_logic_vector; n : natural) return std_logic_vector is
  alias bitsv : std_logic_vector(bits'length - 1 downto 0) is bits;
  variable r : std_logic_vector(bits'length * n - 1 downto 0) := (others => '0');
begin
  for i in integer range 0 to bits'length - 1 loop
    r((i+1) * n - 1 downto i * n) := (others => bitsv(i));
  end loop;
  return r;
end function;

end memory_pack;
