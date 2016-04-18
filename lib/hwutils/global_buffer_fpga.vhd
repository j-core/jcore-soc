library unisim;
use unisim.vcomponents.all;

architecture fpga of global_buffer is
begin
  b : BUFG port map (i => i, o => o);
end architecture;
