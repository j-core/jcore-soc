-- Implement memory by instantiating one or more fixed-size components. These
-- components can either be the real memory macros or VHDL models of them used
-- in simulation.
architecture memories of ram_1rw is
  constant mem_layout : mem_layout_t := memory_layout(1);
  signal combined_wr : std_logic;

  type dr_array_t is array (0 to mem_layout.rows-1) of std_logic_vector(dr'length - 1 downto 0);
  signal dr_array : dr_array_t;
  signal enables : std_logic_vector(mem_layout.rows-1 downto 0);
  signal selected_row : integer := 0;
  signal selected_row_read : integer := 0;
begin
  assert mem_layout.t /= INVALID report "Invalid memory dimensions" severity failure;
  assert mem_layout.cols = 1
    report "Do not yet support instantiating multiple columns of memories" severity failure;

  select_row: if a'left >= mem_layout.bank_addr_width generate
    selected_row <= to_integer(unsigned(a(a'left downto mem_layout.bank_addr_width)));
    process (clk, en, wr)
    begin
      if clk'event and clk = '1' then
        if en = '1' and wr = '0' then
          -- Keep separate selected row for reading to keep latched read
          -- behaviour. Only update it when a read happens.
          selected_row_read <= to_integer(unsigned(a(a'left downto mem_layout.bank_addr_width)));
        end if;
      end if;
    end process;
  end generate;
  dr <= dr_array(selected_row_read);

  process (selected_row, en)
  begin
    enables <= (others => '0');
    enables(selected_row) <= en;
  end process;

  rows: for row in 0 to mem_layout.rows - 1 generate
    genram_18x2048: if mem_layout.t = RAM_18x2048 generate
      combined_wr <= wr and we(0);
      mem: ram_18x2048_1rw
        port map (
          rst => rst,
          clk => clk,
          en => enables(row),
          wr => combined_wr,
          a => a(10 downto 0),
          dw => dw,
          dr => dr_array(row),
          margin => margin);
    end generate;

    genram_2x8x256: if mem_layout.t = RAM_2x8x256 generate
      mem: ram_2x8x256_1rw
        port map (
          rst => rst,
          clk => clk,
          en => enables(row),
          wr => wr,
          we => we,
          a => a(7 downto 0),
          dw => dw,
          dr => dr_array(row),
          margin => margin);
    end generate;
  end generate;
end architecture;
