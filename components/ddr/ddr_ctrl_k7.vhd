---------------------------------------------------------------------
-- TITLE: DDR SDRAM Interface
-- AUTHORS: Steve Rhoads (rhoadss@yahoo.com)
-- DATE CREATED: 7/26/07
-- FILENAME: ddr_ctrl.vhd
-- PROJECT: Plasma CPU core
-- COPYRIGHT: Software placed into the public domain by the author.
--    Software 'as is' without warranty.  Author liable for nothing.
-- DESCRIPTION:
--    Double Data Rate Sychronous Dynamic Random Access Memory Interface
--    ROW = address(25 downto 13)
--    BANK = address(12 downto 11)
--    COL = address(10 downto 2)
--    Requires CAS latency=2; burst size=2.  
--    Requires clk changes on rising_edge(clk_2x).
--    Requires active, address, byte_we, data_w stable throughout transfer.
--    DLL mode requires 77MHz.  Non-DLL mode runs at 25 MHz.
--
--
-- cycle_cnt 777777770000111122223333444455556666777777777777
-- clk_2x    __--__--__--__--__--__--__--__--__--__--__--__--__
-- clk       ____----____----____----____----____----____----
-- SD_CLK    --____----____----____----____----____----____----
-- cmd       ____write+++WRITE+++____________________________
-- SD_DQ     ~~~~~~~~~~~~~~uuuullllUUUULLLL~~~~~~~~~~~~~~~~~~
-- FOR 8 bit
-- active    ----------------------------____________________
-- pause     ____--------________--------____________________
-- cmd       ____write+++________WRITE+++____________________
-- SD_CLK    --____----____----____----____----____----____----
-- SD_DQ     ~~~~~~~~~~~~aaaabbbbccccddddAAAABBBBCCCCDDDD0000~~
--
-- cycle_cnt 777777770000111122223333444455556666777777777777
-- clk_2x    --__--__--__--__--__--__--__--__--__--__--__--__
-- clk       ____----____----____----____----____----____----
-- SD_CLK    ----____----____----____----____----____----____
-- cmd       ____read++++________________________read++++____
-- SD_DQ     ~~~~~~~~~~~~~~~~~~~~~~~~uuuullll~~~~~~~~~~~~~~~~
-- SD_DQnDLL ~~~~~~~~~~~~~~~~~~~~~~~~~~uuuullll~~~~~~~~~~~~~~
-- pause     ____------------------------________------------
--
-- Must run DdrInit() to initialize DDR chip.
-- Read Micron DDR SDRAM MT46V32M16 data sheet for more details.
---------------------------------------------------------------------
-- Weibin changes: 
-- 1) put states to enumate type instead of hard code
-- 2) cycle_count from signal to integer
-- 3) add generic c_period_clkbus is ns
-- 4) c_data_width generate interface size, for now support 8/16
-- 5) c_sa_width domain SD_SA size align to the ROW size
-- 6) DLL disable feature is for Micron DDR, not sure other DDR's character on DLL disable
-- 7) DLL disable require extra ONE write cycle on data output refer to f_get_write_active_end
-- 8) TODO: c_period_bus need to generate tWR, tRP etc parameters

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.cpu2j0_pack.all;
use work.ddr_pack.all;
use work.wrbuf_pack.all;
use work.attr_pack.all;

entity ddr_ctrl_k7 is
	generic (c_data_width : integer := 16;
                 c_sa_width : integer := 14;	-- contol address and SD_SA width
		 c_dll_enable : integer range 0 to 2:= 0;	-- 0: no DLL, 1 DLL, 2: LPDDR
		 c_period_clkbus : integer := 40);
   port(
      ddr_clk0      : in  std_logic;
      ddr_clk90     : in  std_logic;
      clk_2x        : in  std_logic;
      o_write_reg   : out std_logic;
      reset_in      : in  std_logic;
      db_i          : in  cpu_data_o_t;
      db_o          : out cpu_data_i_t;
      sd_data_o     : out sd_data_i_t;
      sd_data_i     : in  sd_data_o_t;
      sd_ctrl       : out sd_ctrl_t);
  attribute soc_port_global_name of ddr_clk0 : signal is "clk_mem";
  attribute soc_port_global_name of ddr_clk90 : signal is "clk_mem_90";
  attribute soc_port_global_name of clk_2x : signal is "clk_mem_2x";
  attribute soc_port_global_name of o_write_reg : signal is "ddr_write_reg";
  attribute soc_port_global_name of reset_in : signal is "reset";
  attribute soc_port_global_name of db_i : signal is "ddr_bus_o";
  attribute soc_port_global_name of db_o : signal is "ddr_bus_i";
  attribute soc_port_global_name of sd_data_o : signal is "ddr_sd_data_i";
  attribute soc_port_global_name of sd_data_i : signal is "ddr_sd_data_o";
  attribute soc_port_global_name of sd_ctrl : signal is "ddr_sd_ctrl";
end; --entity ddr

architecture logic of ddr_ctrl_k7 is

component wrbuf is port (
   clk  : in  std_logic;
   rst  : in  std_logic;
   a    : in  cpu_data_o_t;
   b    : in  cpu_data_i_t;
   ya   : out cpu_data_i_t;
   yb   : out cpu_data_o_t);
end component;

	function f_get_refreshcnt_max return integer is 
	begin
		-- Because this must follow the range of  tRAS and tREF, unless we add a counter for tRAS,
		-- otherwise don't change this value;
                -- change record tREFI x 1.0 value
	       	return 7800/c_period_clkbus - 1;	-- 7.8 uS
	end function f_get_refreshcnt_max;
	function f_get_cyccnt_max return integer is 
	begin
		if c_dll_enable = 2 then
			if c_data_width = 16 then
				return  5;
			else
				return 7;
			end if;
		elsif c_data_width = 16 then
			return 7;
		else
			return 9;
		end if;
	end function f_get_cyccnt_max;
	-- In DLL disable mode for Micron DDR, SD_DQ write cycles must provide extra one cycle after valid data output finish
	-- So that the last byte can be accept by DDR
	function f_get_write_prev_end return integer is 
	begin
		if c_dll_enable = 2 then
			if c_data_width = 16 then
				return 4;
			else
				return 6;
			end if;
		elsif c_data_width = 16 then
			return 6;
		else
			return 8;
		end if;
	end function f_get_write_prev_end;
	function f_get_write_active_end return integer is 
	begin
		if c_data_width = 16 then
			return 2;
		else
			return 4;
		end if;
	end function f_get_write_active_end;

   --Commands for bits RAS & CAS & WE
   subtype command_type is std_logic_vector(2 downto 0);
   constant COMMAND_LMR          : command_type := "000";
   constant COMMAND_AUTO_REFRESH : command_type := "001";
   constant COMMAND_PRECHARGE    : command_type := "010";
   constant COMMAND_ACTIVE       : command_type := "011";
   constant COMMAND_WRITE        : command_type := "100";
   constant COMMAND_READ         : command_type := "101";
   constant COMMAND_TERMINATE    : command_type := "110";
   constant COMMAND_NOP          : command_type := "111";

   type ddr_state_type is (state_power_on, state_idle, state_row_activate, 
     state_row_active, state_read, state_read2, state_read3, state_read5, state_precharge, state_precharge2, state_read4, state_write);
   constant c_cyccnt_max : integer := f_get_cyccnt_max;
   constant c_refreshcnt_max : integer := f_get_refreshcnt_max;
   constant c_write_active_end : integer := f_get_write_active_end;
   constant c_write_prev_end : integer := f_get_write_prev_end;

   signal cycle_count  : integer range 0 to c_cyccnt_max;  --half clocks since op
   signal refresh_cnt  : integer range 0 to c_refreshcnt_max;

   signal state_prev   : ddr_state_type;
   signal data_reg  : std_logic_vector((2*c_data_width)-1 downto 0); --write pipeline
   signal byte_we_reg : std_logic_vector((2*c_data_width/8)-1 downto 0);  --write pipeline
   signal data_reg_lo  : std_logic_vector((c_data_width-1) downto 0); --write pipeline
   signal byte_we_reg_lo : std_logic_vector((c_data_width/8)-1 downto 0);  --write pipeline
   signal write_prev   : std_logic;
   signal write_reg: std_logic;
   signal write_reg_0, write_reg_90: std_logic;
   signal cke_reg      : std_logic;
   signal bank_open    : std_logic_vector(3 downto 0);
   signal data_read    : std_logic_vector((2*c_data_width)-1 downto 0);
   signal byte_we      : std_logic_vector((2*c_data_width/8)-1 downto 0);
   signal bank_match : std_logic;
   signal db_i_int : cpu_data_o_t;
   signal db_o_int : cpu_data_i_t;

   --attribute maxskew : string;
   --attribute maxskew of write_active : signal is "350 ps";

begin

   wrbuf_inst:
        wrbuf port map (clk  => ddr_clk0,
                        rst  => reset_in,
                        a    => db_i,
                        b    => db_o_int,
                        ya   => db_o,
                        yb   => db_i_int);

   byte_we <= db_i_int.we when db_i_int.wr = '1' else "0000";

   ddr_proc: process(ddr_clk0, ddr_clk90, clk_2x, reset_in, 
                     db_i_int.en, db_i_int.a, byte_we,
                     bank_match, state_prev, refresh_cnt,  
                     byte_we_reg, data_reg, 
                     cycle_count, write_prev,
                     cke_reg, bank_open,
                     data_read, write_reg, write_reg_0, write_reg_90,
                     data_reg_lo, byte_we_reg_lo, sd_data_i)
   type address_array_type is array(3 downto 0) of std_logic_vector((c_sa_width -1) downto 0);
   variable address_row    : address_array_type;
   variable command        : std_logic_vector(2 downto 0); --RAS & CAS & WE
   variable bank_index     : integer;
   variable state_current  : ddr_state_type;

   begin
   
      o_write_reg <= write_reg;
      command := COMMAND_NOP;
      bank_index := to_integer(unsigned(db_i_int.a(12 downto 11)));
      state_current := state_prev;
      if db_i_int.a((c_sa_width + 12) downto 13) /= address_row(bank_index) then
	      bank_match <= '0';
      else
	      bank_match <= '1';
      end if;
      
      --DDR state machine to determine state_current and command
      case state_prev is
         when state_power_on =>
            if db_i_int.en = '1' then
               if db_i_int.wr = '1' then
                  command := db_i_int.a(6 downto 4); --LMR="000"
               else
                  state_current := state_idle;  --read transistions to state_idle
               end if;
            end if;

         when state_idle =>
            if refresh_cnt = 0 then
               state_current := state_precharge;
               command := COMMAND_AUTO_REFRESH;
            elsif db_i_int.en = '1' then
               state_current := state_row_activate;
               command := COMMAND_ACTIVE;
            end if;
            
         when state_row_activate =>
            state_current := state_row_active;

         when state_row_active =>
            if refresh_cnt = 0 then
               if write_prev = '0' then
                  state_current := state_precharge;
                  command := COMMAND_PRECHARGE;
               end if;
            elsif db_i_int.en = '1' then
               if bank_open(bank_index) = '0' then
                  state_current := state_row_activate;
                  command := COMMAND_ACTIVE;
               elsif bank_match = '0' then
                  if write_prev = '0' then
                     state_current := state_precharge;
                     command := COMMAND_PRECHARGE;
                  end if;
               else
                  if db_i_int.wr = '1' then
                     command := COMMAND_WRITE;
		     if c_data_width = 8 then
			     state_current := state_write;
		     end if;
                  elsif write_prev = '0' then
		     if c_dll_enable = 2 then	-- LPDDR
			     state_current := state_read2;
		     else
			     state_current := state_read;
		     end if;
                     command := COMMAND_READ;
                  end if;
               end if;
            end if;

         when state_write =>
	    state_current := state_row_active;

         when state_read =>
            state_current := state_read2;

         when state_read2 =>
		 if c_data_width = 8 then
			 state_current := state_read4;
		 else	-- 16
			 state_current := state_read3;
		 end if;
		 	
	 when state_read4 =>
		 state_current := state_read3;

         when state_read3 =>
            state_current := state_read5;

         when state_read5 =>
            state_current := state_row_active;

         when state_precharge =>
            state_current := state_precharge2;

         when state_precharge2 =>
            state_current := state_idle;

         when others =>
            state_current := state_idle;
      end case; --state_prev
      
      --rising_edge(ddr_clk0) domain registers
      if reset_in = '1' then
         state_prev   <= state_power_on;
         cke_reg      <= '0';
         refresh_cnt  <= c_refreshcnt_max;
         write_prev   <= '0';
         bank_open    <= "0000";
         write_reg    <= '0';
         sd_data_o.rd_lat_en    <= '0';
      elsif rising_edge(ddr_clk0) then
         if db_i_int.en = '1' then
            cke_reg <= '1';
         end if;

	 -- write_prev to make sure tWR = 2 cyc
         if command = COMMAND_WRITE then
            write_prev <= '1';
         elsif cycle_count >= c_write_prev_end then
            write_prev <= '0';
         end if;

         if command = COMMAND_ACTIVE then
            bank_open(bank_index) <= '1';
            address_row(bank_index) := db_i_int.a((c_sa_width + 12) downto 13);
         end if;
         
         if command = COMMAND_PRECHARGE then
            bank_open <= "0000";
         end if;
         
         if command = COMMAND_AUTO_REFRESH then
            refresh_cnt <= c_refreshcnt_max;
         elsif refresh_cnt /= 0 then
            refresh_cnt <= refresh_cnt - 1;
         end if;
         
         if command = COMMAND_WRITE then
            write_reg <= '1';
         else
            write_reg <= '0';
         end if;

         if command = COMMAND_READ then
            sd_data_o.rd_lat_en <= '1';
         elsif state_current = state_read5 then
            sd_data_o.rd_lat_en <= '0';
         end if;

         state_prev <= state_current;

      end if; --rising_edge(ddr_clk0)

      if rising_edge(ddr_clk0) then
         data_reg    <= db_i_int.d;
         byte_we_reg <= byte_we;
      end if;

      if falling_edge(ddr_clk0) then
         data_reg_lo <= data_reg((c_data_width-1) downto 0);
         byte_we_reg_lo <= byte_we_reg((c_data_width/8)-1 downto 0);
      end if;

      --if rising_edge(ddr_clk0) then
      --   if command = COMMAND_WRITE then
      --      data_reg    <= db_i_int.d;
      --      byte_we_reg <= byte_we;
      --   end if;
      --   if c_data_width = 16 then
      --      data_reg_lo <= data_reg((c_data_width-1) downto 0);
      --      byte_we_reg_lo <= byte_we_reg((c_data_width/8)-1 downto 0);
      --   else
      --      data_reg_lo <= data_reg((c_data_width-1) downto 0);
      --      byte_we_reg_lo <= byte_we_reg((c_data_width/8)-1 downto 0);
      --   end if;
      --end if;

      if reset_in = '1' then
         write_reg_90 <= '0';
      elsif rising_edge(ddr_clk90) then
         write_reg_90 <= write_reg;
      end if;

      if reset_in = '1' then
         write_reg_0 <= '0';
      elsif falling_edge(ddr_clk0) then
         write_reg_0 <= write_reg;
      end if;

      if rising_edge(ddr_clk0) then
         data_read <= sd_data_i.dqo_lat;
      end if; --rising_edge(ddr_clk0)
     
      --rising_edge(clk_2x) domain registers
      if reset_in = '1' then
         cycle_count <= 0;
      elsif rising_edge(clk_2x) then
         --Cycle_count
         if (command = COMMAND_READ or command = COMMAND_WRITE) then
            cycle_count <= 0;
         elsif cycle_count /= c_cyccnt_max then
            cycle_count <= cycle_count + 1;
         end if;
      end if;

      db_o_int.d <= data_read;
      --db_o_int.d <= dqo_lat;

      sd_data_o.dq_latp  <= data_reg((2*c_data_width)-1 downto c_data_width);
      sd_data_o.dq_latn  <= data_reg_lo;
      sd_data_o.dm_latp  <= not byte_we_reg((2*c_data_width/8)-1 downto (2*c_data_width/8)-2);
      sd_data_o.dm_latn  <= not byte_we_reg_lo;
      sd_data_o.dq_lat_en  <= write_reg_90;
      --sd_data_o.dqs_lat_en <= write_reg_90 or write_reg_0;
      -- to change below, to see if it's read or write 
        if write_reg='1' then--for write
          sd_data_o.dqs_lat_en <= write_reg or write_reg_0;
        else--for read
          sd_data_o.dqs_lat_en <= write_reg_90 or write_reg_0;
        end if;

      --DDR control signals
      sd_ctrl.cke  <= cke_reg;              --clock_enable
      sd_ctrl.cs   <= not cke_reg;          --chip_select

      if reset_in = '1' then
          sd_ctrl.ba   <= (others => '0');
          sd_ctrl.a    <= (others => '0');
          sd_ctrl.ras  <= '1';
          sd_ctrl.cas  <= '1';
          sd_ctrl.we   <= '1';
      elsif falling_edge(ddr_clk0) then
          sd_ctrl.ba   <= db_i_int.a(12 downto 11);  --bank_address

          if command = COMMAND_ACTIVE or state_current = state_power_on then
             sd_ctrl.a <= db_i_int.a((c_sa_width + 12) downto 13);  --address row
          elsif command = COMMAND_READ or command = COMMAND_WRITE then
             if c_data_width = 16 then
                sd_ctrl.a(11 downto 0) <= ("00" & db_i_int.a(10 downto 2) & "0"); --address col
             elsif c_data_width = 8 then
                sd_ctrl.a(11 downto 0) <= (db_i_int.a(10) & "0" & db_i_int.a(9 downto 2) & "00"); --address col
             end if;
             for i in 12 to c_sa_width - 1 loop
    	         sd_ctrl.a(i) <= '0';
             end loop;
          else
             sd_ctrl.a <= (10 => '1', others => '0');      --PERCHARGE all banks
          end if;

          sd_ctrl.ras  <= command(2);           --row_address_strobe
          sd_ctrl.cas  <= command(1);           --column_address_strobe
          sd_ctrl.we   <= command(0);           --write_enable
      end if; --falling_edge(ddr_clk0)

      if db_i_int.en = '1' then
	      if  state_prev /= state_power_on then
		      if command /= COMMAND_WRITE then
			      if state_prev /= state_read5 then
				      db_o_int.ack <= '0';
			      else
				      db_o_int.ack <= '1';
			      end if;
		      else
			      db_o_int.ack <= '1';
		      end if;
	      else
		      db_o_int.ack <= '1';
	      end if;
      else
	      db_o_int.ack <= '0';
      end if;

   end process; --ddr_proc
   
end; --architecture logic

