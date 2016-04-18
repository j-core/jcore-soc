-- Implement memory by instantiating one or more fixed-size components. These
-- components can either be the real memory macros or VHDL models of them used
-- in simulation.
architecture memories of rom_1r is
  constant mem_layout : mem_layout_t := memory_layout(1);
  type dr_array_t is array (0 to mem_layout.rows-1) of std_logic_vector(d'length - 1 downto 0);
  signal dr_array : dr_array_t;
  signal selected_row : integer := 0;
begin
  assert mem_layout.t /= INVALID report "Invalid memory dimensions" severity failure;
  assert mem_layout.cols = 1
    report "Do not yet support instantiating multipe columns of memories" severity failure;

  select_row: if a'left >= mem_layout.bank_addr_width generate
    selected_row <= to_integer(unsigned(a(a'left downto mem_layout.bank_addr_width)));
  end generate;
  d <= dr_array(selected_row);

  rows: for row in 0 to mem_layout.rows - 1 generate
    genrom_32x2048: if mem_layout.t = ROM_32x2048 generate
      mem: rom_32x2048_1r
        port map (
          clk => clk,
          en => en,
          a => a(10 downto 0),
          d => dr_array(row),
          margin => margin);
    end generate;
  end generate;
end architecture;
