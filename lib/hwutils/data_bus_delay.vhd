library ieee;
use ieee.std_logic_1164.all;
use work.cpu2j0_pack.all;

entity data_bus_delay is
  generic (
    INSERT_WRITE_DELAY : boolean;
    INSERT_READ_DELAY : boolean);
  port (
    clk : in std_logic;
    rst : in std_logic;
    master_o : in cpu_data_o_t;
    master_i : out cpu_data_i_t;
    slave_o : out cpu_data_o_t;
    slave_i : in cpu_data_i_t); 
end data_bus_delay;

architecture rtl of data_bus_delay is

-- explanation of INSERT_*_DELAY (only read-d is shown, write-d is obvious)
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

  -- wording: del = delay, nodel = no delay,
  --          t_r = this_r (in .vhd from .vhm)

  signal t_r_master_i : cpu_data_i_t;
  signal t_r_ma_o_wr  : std_logic; -- for choice 2, 3, 4
  signal t_r_slave_i_ack : std_logic; -- for choice 2
  signal t_r_slave_i     : cpu_data_i_t;  -- for choice 3, 4

begin

  -- choice 1 (through box)
  r_nodel_w_nodel : if(not INSERT_WRITE_DELAY) and
                      (not INSERT_READ_DELAY ) generate
    slave_o <= master_o;
    master_i <= slave_i;
  end generate;

  -- choice 2
  r_nodel_w_del : if     INSERT_WRITE_DELAY  and
                    (not INSERT_READ_DELAY ) generate
    p0_onewait : process(clk, rst)
    begin
      if rst = '1' then
        t_r_slave_i_ack <= '0';
        t_r_ma_o_wr <= '0';
      elsif clk = '1' and clk'event then
        t_r_slave_i_ack <= slave_i.ack;
        t_r_ma_o_wr <= master_o.wr;
      end if;
    end process;
    -- output drive
    slave_o.we <= master_o.we;
    slave_o.a  <= master_o.a ;
    slave_o.d  <= master_o.d ;
    slave_o.en <= master_o.en and ((not t_r_slave_i_ack) or (not t_r_ma_o_wr));
    slave_o.wr <= master_o.wr and  (not t_r_slave_i_ack) ;
    slave_o.rd <= master_o.rd ;
    master_i.ack <= t_r_slave_i_ack when (t_r_ma_o_wr = '1') else
                        slave_i.ack;
    master_i.d <= slave_i.d;
  end generate;

  -- choice 3 & 4
  r_del : if INSERT_READ_DELAY   generate
    p0_onewait : process(clk, rst)
    begin
      if rst = '1' then
        t_r_slave_i <= (ack => '0', d => (others => '0'));
        t_r_ma_o_wr <= '0';
      elsif clk = '1' and clk'event then
        t_r_slave_i <= slave_i;
        t_r_ma_o_wr <= master_o.wr;
      end if;
    end process;
    -- output drive
    slave_o.we <= master_o.we;
    slave_o.a  <= master_o.a ;
    slave_o.d  <= master_o.d ;
    slave_o.en <= master_o.en and  (not t_r_slave_i.ack) 
                   when INSERT_WRITE_DELAY else
                  master_o.en and ((not t_r_slave_i.ack) or t_r_ma_o_wr);
    slave_o.wr <= master_o.wr and  (not t_r_slave_i.ack)
                   when INSERT_WRITE_DELAY else
                  master_o.wr;
    slave_o.rd <= master_o.rd and  (not t_r_slave_i.ack);
    master_i.ack <= t_r_slave_i.ack when (INSERT_WRITE_DELAY or
                                          (t_r_ma_o_wr = '0')) else
                        slave_i.ack;
    master_i.d <= t_r_slave_i.d;
  end generate;

end rtl;

