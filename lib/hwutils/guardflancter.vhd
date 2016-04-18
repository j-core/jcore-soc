-- Wraps a flancter to ensure the set_en and clr_en inputs are being pulsed
-- correctly. The set_en to the underlying flancter is pulsed only once when
-- the output to the set clk domain is low. Similarly, the underlying clr_en is
-- pulsed only once when the output to the clr clk domain is high. This is to
-- avoid simulataneously setting both set_en and clr_en, which the 

library ieee;
use ieee.std_logic_1164.all;

entity guardflancter is
  port (
    rst : in std_logic;

    -- clock domain for setting the flancter to '1'
    set_clk : in std_logic;
    set_en  : in std_logic;

    -- clock domain for clearing the flancter to '0'
    clr_clk : in std_logic;
    clr_en  : in std_logic;

    d_set : out std_logic;
    d_clr : out std_logic);
end entity;

architecture arch of guardflancter is
  -- prevents setting the flancter when it's already set
  signal will_set : std_logic;
  -- prevents clearing the flancter when it's already cleared
  signal will_clr : std_logic;

  -- connected to ports of flancter
  signal fset_en : std_logic;
  signal fclr_en : std_logic;
  signal fd_set  : std_logic;
  signal fd_clr  : std_logic;
begin

  set_p : process (rst, set_clk) is
  begin
    if rst = '1' then
      will_set <= '0';
      fset_en  <= '0';
    elsif set_clk'event and set_clk = '1' then
      fset_en <= '0';
      -- only pulse fset_en if it hasn't already been pulsed and the output is
      -- currently low
      if set_en = '1' and will_set = '0' and fd_set = '0' then
        will_set <= '1';
        fset_en  <= '1';
      elsif fd_set = '1' then
        will_set <= '0';
      end if;
    end if;
  end process;

  clr_p : process (rst, clr_clk) is
  begin
    if rst = '1' then
      will_clr <= '0';
      fclr_en  <= '0';
    elsif clr_clk'event and clr_clk = '1' then
      fclr_en <= '0';
      -- only pulse fclr_en if it hasn't already been pulsed and the output is
      -- currently high
      if clr_en = '1' and will_clr = '0' and fd_clr = '1' then
        will_clr <= '1';
        fclr_en  <= '1';
      elsif fd_clr = '0' then
        will_clr <= '0';
      end if;
    end if;
  end process;

  flancter : entity work.flancter
    generic map (
      SYNC_SET_DATA => true,
      SYNC_CLR_DATA => true)
    port map (
      rst     => rst,
      set_clk => set_clk,
      set_en  => fset_en,
      clr_clk => clr_clk,
      clr_en  => fclr_en,
      d_set   => fd_set,
      d_clr   => fd_clr);

  d_set <= fd_set;
  d_clr <= fd_clr;

end architecture;
