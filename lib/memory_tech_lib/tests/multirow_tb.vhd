-- Test ram_1rw with a larger ADDR_WIDTH than the underlying memory to ensure
-- it will instantiate multiple copies.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.test_pkg.all;
use work.memory_pack.all;
use work.mem_test_pack.all;

entity multirow_tb is
end multirow_tb;

architecture tb of multirow_tb is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal p : mem_port := MEM_PORT_NOP;

  signal dr : std_logic_vector(15 downto 0);

  procedure tick(signal clk : inout std_logic) is
  begin
    wait for 10 ns;
    clk <= '1';
    wait for 10 ns;
    clk <= '0';
  end procedure;

  for u_mem : ram_1rw use configuration work.ram_1rw_sim;
begin

  u_mem: ram_1rw
    generic map (
      SUBWORD_WIDTH => 8,
      SUBWORD_NUM => 2,
      ADDR_WIDTH => 10) -- instead of 8. Should instantiate 4 memories
    port map (
      rst => rst,
      clk => clk,
      en => p.en,
      wr => p.wr,
      we => p.we(1 downto 0),
      a => p.a(9 downto 0),
      dw => p.dw(15 downto 0),
      dr => dr,
      margin => "00");

  process
  begin
    test_plan(8, "multirow_tb");

    -- Memories do synchronous reads and writes at the rising clock edge. Setup
    -- read/write requests at the negative edge and check the results at the
    -- following negative edge.
    tick(clk);
    rst <= '0';
    tick(clk);

    p <= MEM_PORT_NOP;

    tick(clk);

    p <= writemem(0, x"0000aaaa");
    tick(clk);
    p <= writemem(255, x"0000bbbb");
    tick(clk);
    p <= writemem(256, x"0000cccc");
    tick(clk);
    p <= writemem(511, x"0000dddd");
    tick(clk);
    p <= writemem(512, x"0000eeee");
    tick(clk);
    p <= writemem(1023, x"0000ffff");
    tick(clk);

    p <= MEM_PORT_NOP;
    tick(clk);
    p <= readmem(256);
    tick(clk);
    test_equal(dr, x"cccc", "read 256");
    p <= readmem(0);
    tick(clk);
    test_equal(dr, x"aaaa", "read 0");
    p <= readmem(512);
    tick(clk);
    test_equal(dr, x"eeee", "read 512");
    p <= readmem(1023);
    tick(clk);
    test_equal(dr, x"ffff", "read 1023");
    p <= readmem(255);
    tick(clk);
    test_equal(dr, x"bbbb", "read 255");
    p <= readmem(511);
    tick(clk);
    test_equal(dr, x"dddd", "read 511");
    p <= MEM_PORT_NOP;
    tick(clk);
    test_equal(dr, x"dddd", "read data is latched during NOPs");
    tick(clk);
    p <= writemem(2, x"00000001");
    tick(clk);
    test_equal(dr, x"dddd", "read data is latched during writes");

    p <= MEM_PORT_NOP;
    tick(clk);
    wait;
  end process;
end architecture;
