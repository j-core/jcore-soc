-- ROM with 1 read port, sync reads, 32 bits wide, and 2048 entries deep.
library ieee;
use ieee.std_logic_1164.all;
entity rom_32x2048_1r is
  port (
    clk : in  std_logic;
    en  : in  std_logic;
    a   : in  std_logic_vector(10 downto 0);
    d   : out std_logic_vector(31 downto 0);
    margin : in std_logic);
end entity;
