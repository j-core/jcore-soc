-- A flancter as described in 'Application Note: The "Flancter" by Rob Weinstein'.
-- A flag that can be set in one clock domain and cleared in another.

-- The xor-ed output of the flancter must be synchronized to whichever clock
-- domain is going to read it. This entity has generics to optionally
-- instantiate synchronizing flip-flops in the set and/or clear clock domains.
-- By default, the synchronizing flip-flops will be instantiated, relying on
-- the synthesis tool to automatically remove them if the output is left open.

library ieee;
use ieee.std_logic_1164.all;

entity flancter is
  generic (
    SYNC_SET_DATA : boolean := true;
    SYNC_CLR_DATA : boolean := true);
  port (
    rst : in std_logic;

    -- clock domain for setting the flancter to '1'
    set_clk : in std_logic;
    set_en  : in std_logic;

    -- clock domain for clearing the flancter to '0'
    clr_clk : in std_logic;
    clr_en  : in std_logic;

    -- data outputs:
    -- these are the same value. There are two ports because each is
    -- optionally synchronized to the set or clear clock domain by the
    -- SYNC_SET_DATA and SYNC_CLR_DATA generics.
    d_set : out std_logic;
    d_clr : out std_logic);
end entity;

architecture arch of flancter is
  signal set_ff : std_logic;
  signal clr_ff : std_logic;
  signal output : std_logic;
begin

  set_p : process (rst, set_clk) is
  begin
    if rst = '1' then
      set_ff <= '0';
    elsif set_clk'event and set_clk = '1' then
      if set_en = '1' then
        set_ff <= not clr_ff;
      end if;
    end if;
  end process;

  clr_p : process (rst, clr_clk) is
  begin
    if rst = '1' then
      clr_ff <= '0';
    elsif clr_clk'event and clr_clk = '1' then
      if clr_en = '1' then
        clr_ff <= set_ff;
      end if;
    end if;
  end process;

  output <= set_ff xor clr_ff;

  -- optional synchronize the output to set_clk
  sync_set_output: if SYNC_SET_DATA generate
    setsyncff : entity work.sync2ff
      port map (
        clk   => set_clk,
        reset => rst,
        sin   => output,
        sout  => d_set);
  end generate;
  nosync_set_output: if not SYNC_SET_DATA generate
    d_set <= output;
  end generate;

  -- optional synchronize the output to clr_clk
  sync_clr_output: if SYNC_CLR_DATA generate
    clrsyncff : entity work.sync2ff
      port map (
        clk   => clr_clk,
        reset => rst,
        sin   => output,
        sout  => d_clr);
  end generate;
  nosync_clr_output: if not SYNC_CLR_DATA generate
    d_clr <= output;
  end generate;

end architecture;
