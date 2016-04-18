-- RAM with 1 read/write port, sync reads and writes, 18 bits wide, and 2048
-- entries deep.
library ieee;
use ieee.std_logic_1164.all;
entity ram_18x2048_1rw is
  port (
    rst : in  std_logic;
    clk : in  std_logic;
    en  : in  std_logic;
    wr  : in  std_logic;
    a   : in  std_logic_vector(10 downto 0);
    dw  : in  std_logic_vector(17 downto 0);
    dr  : out std_logic_vector(17 downto 0);
    margin : in std_logic_vector(1 downto 0));
end entity;
