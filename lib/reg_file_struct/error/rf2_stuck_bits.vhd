library ieee;
use ieee.std_logic_1164.all;

use work.rf_pack.all;

-- values read from a specific register can have bits stuck high or low from
-- one or more ports
entity rf2_stuck_bits is
  generic (
    sync : boolean := false;
    lhqd : boolean := false;
    WIDTH : natural range 1 to 32;
    DEPTH : natural range 1 to 32;

    -- selects register that is faulty
    reg_addr : integer;
    -- values read from the register are bitwise ANDed with this mask
    and_mask : std_logic_vector;
    -- values read from the register are bitwise ORed with this mask after
    -- being ANDed by the and_mask
    or_mask : std_logic_vector;
    -- a bitfield that specifies which read ports are affected. Port i is
    -- affected if port_sel(i) = '1'.
    port_sel : std_logic_vector(0 to 1));
  port (
    clk: in  std_logic;
    rst: in  std_logic;
    D  : in  std_logic_vector(WIDTH-1 downto 0);
    WA : in  integer range 0 to DEPTH-1;
    WE : in  std_logic;
    RA0: in  integer range 0 to DEPTH-1;
    Q0 : out std_logic_vector(WIDTH-1 downto 0);
    RA1: in  integer range 0 to DEPTH-1;
    Q1 : out std_logic_vector(WIDTH-1 downto 0));
begin
  assert reg_addr >= 0 and reg_addr < DEPTH report "reg_addr generic doesn't match depth" severity failure;
  assert and_mask'length = WIDTH report "and_mask generic doesn't match width" severity failure;
  assert or_mask'length = WIDTH report "or_mask generic doesn't match width"  severity failure;
end rf2_stuck_bits;

architecture arch of rf2_stuck_bits is
signal rq0 : std_logic_vector(WIDTH-1 downto 0);
signal rq1 : std_logic_vector(WIDTH-1 downto 0);
begin
  rf : RF2
    generic map( sync => sync, lhqd => lhqd,
                 WIDTH => WIDTH, DEPTH => DEPTH )
    port    map( clk => clk, rst => rst, D => D, WA => WA, WE => WE,
                 RA0 => RA0, Q0 => rq0,
                 RA1 => RA1, Q1 => rq1 );
   Q0 <= (rq0 and and_mask) or or_mask when port_sel(0) = '1' and ra0 = reg_addr
         else rq0;
   Q1 <= (rq1 and and_mask) or or_mask when port_sel(1) = '1' and ra1 = reg_addr
         else rq1;
end arch;
