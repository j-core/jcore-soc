library ieee;
use ieee.std_logic_1164.all;

entity guardflancter_tb is
end;

architecture rtl of guardflancter_tb is
  signal clkA : std_logic := '0';
  signal clkB : std_logic := '0';
  signal rst : std_logic := '1';

  shared variable ENDSIM : boolean := false;

  signal set_en : std_logic := '0';
  signal clr_en : std_logic := '0';
  signal d_set : std_logic;
  signal d_clr : std_logic;

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

  guardflancter : entity work.guardflancter port map (
    rst => rst,
    set_clk => clkA,
    set_en => set_en,
    clr_clk => clkB,
    clr_en => clr_en,

    d_set => d_set,
    d_clr => d_clr);

  process
  begin
    wait for 40 ns;
    rst <= '0';
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    set_en <= '1';
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkB);
    set_en <= '0';
    wait until falling_edge(clkB);
    clr_en <= '1';
    wait until falling_edge(clkB);
    clr_en <= '0';
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);
    wait until falling_edge(clkA);

    wait for 500 ns;
    ENDSIM := true;

    wait;
  end process;
end;
