library ieee;
use ieee.std_logic_1164.all;
use work.cpu2j0_pack.all;

entity instr_bus_delay is
  generic (
    INSERT_DELAY : boolean);
  port (
    clk : in std_logic;
    rst : in std_logic;
    master_o : in cpu_instruction_o_t;
    master_i : out cpu_instruction_i_t;
    slave_o : out cpu_instruction_o_t;
    slave_i : in cpu_instruction_i_t); 
end instr_bus_delay;

architecture rtl of instr_bus_delay is

-- explanation of INSERT_DELAY
--                          ---> time
-- clk          _HH__HH__HH__HH__HH__
-- master_o.en  _HHHHHHHHHHHH________
-- master_i.d   _________XdddX_______  -> even if slave_i.d has large delay
-- master_i.ack _________HHHH________     from starting point (flip-flop) ,
-- slave_o.en   _HHHHHHHH____________     master_i.d has flip-flop-direct
-- slave_i.d    _____XdddX___________     delay characteristic.
-- slave_i.ack  _____HHHH____________
-- end explanation of spec of INSERT_*_DELAY 
-- -----------------------------------------------------------------------

  -- wording: t_r = this_r (in .vhd from .vhm)

  signal t_r_slave_i_ack : std_logic;

begin

  -- no delay (= through box)
  inst_nodel : if(not INSERT_DELAY) generate
    slave_o <= master_o;
    master_i <= slave_i;
  end generate;

  -- delay 
  inst_del : if INSERT_DELAY generate
    p0_onewait : process(clk, rst)
    begin
      if rst = '1' then
        master_i        <= (ack => '0', d => (others => '0'));
        t_r_slave_i_ack <= '0';
      elsif clk = '1' and clk'event then
        master_i        <= slave_i;
        t_r_slave_i_ack <= slave_i.ack;
      end if;
    end process;
    -- output drive
    slave_o.a           <= master_o.a;
    slave_o.en          <= master_o.en and (not t_r_slave_i_ack);
    slave_o.jp          <= master_o.jp and (not t_r_slave_i_ack);
  end generate;

end rtl;

