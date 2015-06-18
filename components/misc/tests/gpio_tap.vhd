library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.test_pkg.all;
use work.gpio_pack.all;

entity gpio_tap is
end;

architecture tb of gpio_tap is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  shared variable ENDSIM : boolean := false;

  type gpio_ctrl is record
    reg : gpio_register;
    d : reg8x4_fixed_i;
  end record;

  procedure read(signal ctrl : out gpio_ctrl; r : gpio_register)
  is
  begin
    ctrl.reg <= r;
    ctrl.d.en <= '1';
    ctrl.d.wr <= '0';
  end;

  procedure write(signal ctrl : out gpio_ctrl; r : gpio_register;
                  d : reg8x4_data; we : reg8x4_we := "1111")
  is
  begin
    ctrl.reg <= r;
    ctrl.d.en <= '1';
    ctrl.d.wr <= '1';
    ctrl.d.d <= d;
    ctrl.d.we <= we;
  end;

  procedure stop(signal ctrl : out gpio_ctrl)
  is
  begin
    ctrl.d.en <= '0';
    ctrl.d.wr <= '0';
  end;

  signal ctrl : gpio_ctrl := (
    reg => REG_DATA,
    d => (en => '0', wr => '0',
          we => (others => '0'), d => (others => '0'))
  );
  signal d_o : reg8x4_fixed_o := (d => (others => '0'), ack => '0');

  signal irq : std_logic := '0';
  signal p_i : gpio_data := (others => '0');
  signal p_o : gpio_data := (others => '0');
begin
  clk_gen : process
  begin
    if ENDSIM = false then
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  g : gpio port map (
    clk => clk,
    rst => rst,
    reg => ctrl.reg,
    d_i => ctrl.d,
    d_o => d_o,
    irq => irq,
    p_i => p_i,
    p_o => p_o
  );

  process
  begin
    test_plan(26, "gpio_tap");
    test_ok(true, "true");
    wait for 10 ns;
    rst <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 1 ns;
    test_equal(d_o.ack, '0', "No active request -> No ACK");
    wait until rising_edge(clk);
    wait for 1 ns;
    read(ctrl, REG_DATA);
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"00000000", "Data starts 0");

    test_comment("read changes");
    read(ctrl, REG_CHANGES);
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"00000000", "Changes starts 0");

    test_comment("Set some bits in p_i");
    p_i(3) <= '1';
    p_i(16) <= '1';
    wait until rising_edge(clk);
    wait for 1 ns;
    read(ctrl, REG_CHANGES);
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    --test_comment("Check changes " & time'image(now));
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"00010008", "read changed edges");

    wait until rising_edge(clk);
    wait for 1 ns;
    read(ctrl, REG_CHANGES);
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"00000000", "read changes clears it");

    test_comment("test EDGE");
    write(ctrl, REG_EDGE, x"0000ffff");
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "write ACK");
    read(ctrl, REG_EDGE);

    p_i(3) <= '0';
    p_i(16) <= '0';
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"0000FFFF", "read back written REG_EDGE");
    read(ctrl, REG_CHANGES);

    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"00000008", "falling edge of one pin seen due to edge");
    wait until rising_edge(clk);
    test_comment("test MASK");
    write(ctrl, REG_MASK, x"ffff0000");
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "write ACK");
    read(ctrl, REG_MASK);

    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"FFFF0000", "read back written REG_MASK");

    test_equal(irq, '0', "irq 0 with no changes");
    p_i(3) <= '1';

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    test_equal(irq, '0', "irq still 0 with masked change");
    p_i(17) <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    test_equal(irq, '1', "irq 1 with unmasked change");
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    read(ctrl, REG_CHANGES);
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "read ACK");
    test_equal(d_o.d, x"00020008", "changes");
    wait until rising_edge(clk);
    test_equal(irq, '0', "irq 0 again after clearing changes");

    test_comment("write output");
    write(ctrl, REG_DATA, x"12345678");
    wait until rising_edge(clk);
    wait for 1 ns;
    stop(ctrl);
    test_equal(d_o.ack, '1', "write ACK");
    test_equal(p_o, x"12345678", "data out matches");
    test_finished("done");
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 40 ns;
    ENDSIM := true;
    wait;
  end process;
end tb;
