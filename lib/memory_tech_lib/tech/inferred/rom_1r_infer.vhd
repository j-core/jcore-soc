-- Directly implement memory usig VHDL array. Used either in simulation or
-- relies on xst to infer block RAM.
architecture inferred of rom_1r is
  type mem_t is array (integer range 0 to 2**ADDR_WIDTH - 1)
    of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal mem : mem_t;
begin
  p : process(clk)
  begin
    if clk'event and clk = '1' then
      if en = '1' then
        -- synchronous read
        d <= mem(to_integer(unsigned(a)));
      end if;
    end if;
  end process;
end architecture;
