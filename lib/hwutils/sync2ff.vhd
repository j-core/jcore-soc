library ieee;
use ieee.std_logic_1164.all;

entity sync2ff is
  port (clk   : in  std_logic;
        reset : in  std_logic;
        sin   : in  std_logic;
        sout  : out std_logic);
end;

architecture rtl of sync2ff is
  signal sync : std_logic;
  signal guard : std_logic;

  -- Disable Shift Register Extraction to avoid collapsing flipflops
  attribute shreg_extract          : string;
  attribute shreg_extract of sync  : signal is "no";
  attribute shreg_extract of guard : signal is "no";

  attribute keep          : string;
  attribute keep of sync  : signal is "true";
  attribute keep of guard : signal is "true";

  -- locate two flip-flops near eachother so a metastable state has the
  -- most time to settle before second registers input
  attribute rloc          : string;
  attribute rloc of sync : signal is "X0Y0";
  attribute rloc of guard : signal is "X1Y0";
  -- create hu_set so these rloc constraints only constrain these two flip-flops
  attribute hu_set : string;
  attribute hu_set of sync : signal is "sync2ff";
  attribute hu_set of guard : signal is "sync2ff";

begin
  process(clk, reset)
  begin
    if reset = '1' then
      sync <= '0';
      guard <= '0';
      sout <= '0';
    elsif rising_edge(clk) then
      sync <= sin;
      guard <= sync;
      sout <= guard;
    end if;
  end process;
end;
