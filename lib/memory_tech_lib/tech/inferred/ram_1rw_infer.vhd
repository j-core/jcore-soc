-- Directly implement memory usig VHDL array. Used either in simulation or
-- relies on xst to infer block RAM.
architecture inferred of ram_1rw is
  type mem_t is array (integer range 0 to 2**ADDR_WIDTH - 1)
    of std_logic_vector(dw'length - 1 downto 0);
  signal mem : mem_t;
  signal wr_we : std_logic_vector(SUBWORD_NUM - 1 downto 0);
begin
  one_subword : if SUBWORD_NUM = 1 generate
    process(clk)
    begin
      if clk'event and clk = '1' then
        if en = '1' then
          if wr = '1' then
            -- synchronous write
            mem(to_integer(unsigned(a))) <= dw;
          else
            -- synchronous latched read
            dr <= mem(to_integer(unsigned(a)));
          end if;
        end if;
      end if;
    end process;
  end generate;
  subwords : if SUBWORD_NUM /= 1 generate
    -- combine wr and we signals so that xst will infer a block RAM
    wr_we <= mask_bits(wr, we);

    process(clk)
    begin
      if clk'event and clk = '1' then
        if en = '1' then
          if wr_we = (wr_we'range => '0') then
            -- synchronous latched read
            dr <= mem(to_integer(unsigned(a)));
          end if;
          -- synchronous write
          for i in integer range 0 to SUBWORD_NUM-1 loop
            if wr_we(i) = '1' then
              mem(to_integer(unsigned(a)))((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH)
                <= dw((i+1)*SUBWORD_WIDTH-1 downto i*SUBWORD_WIDTH);
            end if;
          end loop;
        end if;
      end if;
    end process;
  end generate;
end architecture;
