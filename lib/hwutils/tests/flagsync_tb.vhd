library ieee;
use ieee.std_logic_1164.all;

entity flagsync_tb is
end;

architecture rtl of flagsync_tb is
  signal clkA : std_logic := '0';
  signal clkB : std_logic := '0';
  signal rst : std_logic := '1';

  shared variable ENDSIM : boolean := false;

  signal pulse_i : std_logic := '0';
  signal pulse_o : std_logic := '0';

  constant CLK_A_PERIOD : time := 18 ns;
  constant CLK_B_PERIOD : time := 5 ns;
begin
  clk_gen_a : process
  begin
    if ENDSIM = false then
      clkB <= '0';
      wait for CLK_A_PERIOD;
      clkB <= '1';
      wait for CLK_A_PERIOD;
    else
      wait;
    end if;
  end process;

  clk_gen_b : process
  begin
    if ENDSIM = false then
      clkA <= '0';
      wait for CLK_B_PERIOD;
      clkA <= '1';
      wait for CLK_B_PERIOD;
    else
      wait;
    end if;
  end process;

  pulse_sync : entity work.flagsync port map (
    rst => rst,
    clkA => clkA,
    inA => pulse_i,
    clkB => clkB,
    outB => pulse_o);

  process
  begin
    wait for 40 ns;
    rst <= '0';
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    pulse_i <= '1';
    wait until falling_edge(clkA);
    pulse_i <= '0';
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);

    wait for 500 ns;
    ENDSIM := true;

    wait;
  end process;
end;
