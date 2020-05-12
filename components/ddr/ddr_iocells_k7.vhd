-- DDR IO Cells

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.VCOMPONENTS.all;
library work;
use work.config.all;
use work.ddr_pack.all;
use work.attr_pack.all;

entity ddr_iocells_k7 is
    port(
      ddr_clk0   : in std_logic;
      ddr_clk90  : in std_logic;
      reset      : in std_logic;
      i_write_reg: in std_logic;
      dr_data_i  : in  dr_data_i_t;
      dr_data_o  : out dr_data_o_t;
      sd_data_i  : in  sd_data_i_t;
      sd_data_o  : out sd_data_o_t;
      ckpo       : out std_logic);
  attribute soc_port_global_name of ddr_clk0 : signal is "clk_mem";
  attribute soc_port_global_name of ddr_clk90 : signal is "clk_mem_90";
  attribute soc_port_global_name of i_write_reg : signal is "ddr_write_reg";
  attribute soc_port_global_name of sd_data_o : signal is "ddr_sd_data_o";
  attribute soc_port_global_name of sd_data_i : signal is "ddr_sd_data_i";
  attribute soc_port_global_name of ckpo : signal is "ddr_clk";
  -- synopsys translate_off
  group sigs : global_ports(
    reset,
    dr_data_i,
    dr_data_o);
  -- synopsys translate_on
end;

architecture interface of ddr_iocells_k7 is
        signal ddr_clk0n : std_logic;
        signal ddr_clk90n : std_logic;
        signal dqs_del : std_logic_vector(1 downto 0);
        signal dqs_deln : std_logic_vector(1 downto 0);
        signal dqs_del_buf : std_logic_vector(1 downto 0);
        signal dqs_deln_buf : std_logic_vector(1 downto 0);
        signal dqp : std_logic_vector(CFG_DDRDQ_WIDTH-1 downto 0);
        signal dqn : std_logic_vector(CFG_DDRDQ_WIDTH-1 downto 0);
        signal dq_lat_en_n, dqs_lat_en_n : std_logic;
        signal ck_w : std_logic;
        signal dqs_clk : std_logic;
        signal write_reg_180 : std_logic;
begin
        ddr_clk0n  <= not ddr_clk0;
        ddr_clk90n <= not ddr_clk90;

        --IODELAY2_DQS_FFS : for i in 0 to 1 generate
        --    IODELAY2_inst : IODELAY2 
        --         generic map ( IDELAY_VALUE => 48, DELAY_src=> "IDATAIN", IDELAY_TYPE  => "FIXED")
        --         port map (IDATAIN => dr_data_i.dqsi(i), T => '1', ODATAIN => '0', CLK => '0', IOCLK0  => '0', IOCLK1  => '0',
        --                   CAL => '0', INC => '0', CE => '0', RST => '0', DATAOUT => dqs_del(i));
        --end generate;

        --genddqddrin: for i in 0 to 1 generate
        --    DQS_DEL_BUFIO2_inst  : BUFIO2 port map (I => dqs_del(i), IOCLK => dqs_del_buf(i));
        --    DQS_DELN_BUFIO2_inst : BUFIO2 generic map (I_INVERT => TRUE) port map (I => dqs_del(i), IOCLK => dqs_deln_buf(i));
        --end generate;

        -- NOTE:
        -- Has not been successful in utlizing IODELAY2 to capture memory read data with delayed dqs.
        -- ISE is complaining the design is not routable if used as above. It is saying there is a routing conflict
        -- between CLK1 pin on IDDR2 and CLK1 pin ODDR2 dq's.
        -- Need to figure a way to bring internal clocks to dqs pad and loopback into the IODELAY2 cell I think.
        -- Workaround: internal clocks are used to capture memory read data in the IDDR2 cell.

        --dqs_deln_buf <= not dqs_del_buf;
        IDDR2_FFS : for i in 0 to 15 generate
            --IDDR2_inst : IDDR2
            --      generic map(DDR_ALIGNMENT => "NONE", -- Sets output alignment to "NONE", "C0", "C1"
            --                  INIT_Q0 => '0', -- Sets initial state of the Q0 output to '0' or '1'
            --                  INIT_Q1 => '0', -- Sets initial state of the Q1 output to '0' or '1'
            --                  SRTYPE => "ASYNC") -- Specifies "SYNC" or "ASYNC" set/reset
            --      port map (Q0 => dqp(i),        -- 1-bit output captured with C0 clock
            --                Q1 => dqn(i),        -- 1-bit output captured with C1 clock
            --                --C0 => dqs_del_buf(i/8),  -- 1-bit clock input
            --                --C1 => dqs_deln_buf(i/8), -- 1-bit clock input
            --                C0 => ddr_clk90n,  -- 1-bit clock input
            --                C1 => ddr_clk90, -- 1-bit clock input
            --                CE => '1',           -- 1-bit clock enable input
            --                D => dr_data_i.dqi(i),         -- 1-bit data input
            --                R => '0',            -- 1-bit reset input
            --                S => '0');           -- 1-bit set input
            IDDR_inst : IDDR
                  generic map(DDR_CLK_EDGE => "OPPOSITE_EDGE", 
                              INIT_Q1 => '0', -- Sets initial state of the Q0 output to '0' or '1'
                              INIT_Q2 => '0', -- Sets initial state of the Q1 output to '0' or '1'
                              SRTYPE => "ASYNC") -- Specifies "SYNC" or "ASYNC" set/reset
                  port map (Q1 => dqp(i),        
                            Q2 => dqn(i),        
                            C  => ddr_clk90n,  -- 1-bit clock input
                            CE => '1',           -- 1-bit clock enable input
                            D => dr_data_i.dqi(i),         -- 1-bit data input
                            R => '0',            -- 1-bit reset input
                            S => '0');           -- 1-bit set input
        end generate;

        ODDR_DQS_FFS : for i in 0 to 1 generate
            --ODDR2_DQS_inst : ODDR2
            --     generic map (SRTYPE => "ASYNC") 
            --     port map (Q => dr_data_o.dqso(i), C0 => ddr_clk0n, C1 => ddr_clk0, CE => '1', D0 => '0', D1 => '1', R  => '0', S  => '0');
            ODDR_DQS_inst : ODDR--DEFAULT IS OPPOSITE EDGE
                 generic map (SRTYPE => "ASYNC") 
                 --port map (Q => dr_data_o.dqso(i), C => ddr_clk90, CE => '1', D1 => '0', D2 => '1', R  => '0', S  => '0');
                 port map (Q => dr_data_o.dqso(i), C => dqs_clk, CE => '1', D1 => '0', D2 => '1', R  => '0', S  => '0');
        end generate;

        process(ddr_clk0n)
        begin
          if rising_edge(ddr_clk0n) then
            write_reg_180 <= i_write_reg;
          end if;
        end process;

        process(ddr_clk90, ddr_clk0n, i_write_reg,write_reg_180)
        begin
          if (i_write_reg='1') or (write_reg_180='1')then
             dqs_clk <= ddr_clk90;
          else
             dqs_clk <= ddr_clk0n;
          end if;
        end process;

        ODDR_DM_FFS : for i in 0 to 1 generate
            --ODDR2_DM_inst : ODDR2
            --     generic map (SRTYPE => "ASYNC") 
            --     port map (Q => dr_data_o.dmo(i), C0 => ddr_clk90n, C1 => ddr_clk90, CE => '1', D0 => sd_data_i.dm_latp(i), D1 => sd_data_i.dm_latn(i), R  => '0', S  => '0');
            ODDR_DM_inst : ODDR
                 generic map (SRTYPE => "ASYNC") 
                 --port map (Q => dr_data_o.dmo(i), C => ddr_clk90n, CE => '1', D1 => sd_data_i.dm_latp(i), D2 => sd_data_i.dm_latn(i), R  => '0', S  => '0');
                 port map (Q => dr_data_o.dmo(i), C => ddr_clk0n, CE => '1', D1 => sd_data_i.dm_latp(i), D2 => sd_data_i.dm_latn(i), R  => '0', S  => '0');
        end generate;

        ODDR_DQ_FFS : for i in 0 to 15 generate
            --ODDR2_DQ_inst : ODDR2
            --     generic map (SRTYPE => "ASYNC") 
            --     port map (Q => dr_data_o.dqo(i), C0 => ddr_clk90n, C1 => ddr_clk90, CE => '1', D0 => sd_data_i.dq_latp(i), D1 => sd_data_i.dq_latn(i), R  => '0', S  => '0');
            ODDR_DQ_inst : ODDR
                 generic map (SRTYPE => "ASYNC") 
                 port map (Q => dr_data_o.dqo(i), C => ddr_clk0n,  CE => '1', D1 => sd_data_i.dq_latp(i), D2 => sd_data_i.dq_latn(i), R  => '0', S  => '0');
        end generate;
 
        dq_lat_en_n <= not sd_data_i.dq_lat_en; dqs_lat_en_n <= not sd_data_i.dqs_lat_en;
        ODDR_DQ_OE_FFS: for i in 0 to 17 generate
            --ODDR2_DQ_OE_inst : ODDR2 generic map ( SRTYPE => "ASYNC") 
            --                   port map (Q => dr_data_o.dq_outen(i), C0 => ddr_clk90n, C1 => ddr_clk90, CE => '1', D0 => dq_lat_en_n, D1 => dq_lat_en_n, R  => '0', S  => '0');
            ODDR_DQ_OE_inst : ODDR generic map (SRTYPE=>"ASYNC")
                               port map (Q => dr_data_o.dq_outen(i), C => ddr_clk0n, CE => '1', D1 => dq_lat_en_n, D2 => dq_lat_en_n, R  => '0', S  => '0');
        end generate;
        ODDR_DQS_OE_FFS: for i in 0 to 1 generate
            --ODDR2_DQS_OE_inst : ODDR2 generic map ( SRTYPE => "ASYNC") 
            --                    port map (Q => dr_data_o.dqs_outen(i), C0 => ddr_clk0n, C1 => ddr_clk0, CE => '1', D0 => dqs_lat_en_n, D1 => dqs_lat_en_n, R  => '0', S  => '0');
            ODDR_DQS_OE_inst : ODDR generic map (SRTYPE=>"ASYNC")--move it forward, since data is moved forward
                                --port map (Q => dr_data_o.dqs_outen(i), C => ddr_clk90, CE => '1', D1 => dqs_lat_en_n, D2 => dqs_lat_en_n, R  => '0', S  => '0');
                                port map (Q => dr_data_o.dqs_outen(i), C => dqs_clk, CE => '1', D1 => dqs_lat_en_n, D2 => dqs_lat_en_n, R  => '0', S  => '0');
        end generate;

        --u_ck_ddr : ODDR2 generic map ( SRTYPE => "ASYNC") port map (Q => ckpo, C0 => ddr_clk90n, C1 => ddr_clk90, CE => '1', D0 => '1', D1 => '0', R  => '0', S  => '0');
        u_ck_ddr : ODDR generic map ( SRTYPE => "ASYNC") port map (Q => ckpo, C => ddr_clk90n, CE => '1', D1 => '1', D2 => '0', R  => '0', S  => '0');

        --sd_data_o.dqo_lat <= dqp & dqn; -- USE when dqs from pad is used after IODELAY2
        sd_data_o.dqo_lat <= dqn & dqp; -- USE when internal clocks are used for capture.

end interface;
