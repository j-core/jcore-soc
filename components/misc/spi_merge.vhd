-- Joins two spi buses to connect to a single spi controller.

library ieee;
use ieee.std_logic_1164.all;

entity spi_merge is
  port (
    mosi_merge : in std_logic;
    miso_merge : out std_logic;

    mosi1 : out std_logic;
    miso1 : in std_logic;

    mosi2 : out std_logic;
    miso2 : in std_logic;
    cs : in std_logic_vector(1 downto 0));
end entity;

architecture arch of spi_merge is
begin
  -- Masking the mosi and selecting the miso based on the chip select
  -- should not be necessary because the spi slave should stop driving
  -- miso and ignore mosi. However, on the mimas_v2 board it seems
  -- like the spi flash is staying on the bus after it is deselected
  -- so add muxes here in case spi slave is misbehaving.

  mosi1 <= mosi_merge when cs(0) = '0' else '0';
  mosi2 <= mosi_merge when cs(1) = '0' else '0';

  miso_merge <= miso2 when cs(1) = '0' else miso1;
end architecture;
