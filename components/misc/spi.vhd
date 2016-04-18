-- input clock is 50-100 MHz
-- This component will be enclosed in PIO
-- Oct 31: add anther ChipSelect for D2A board, add divider
-- TODO: clk_bus could be changed, 

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use work.cpu2j0_pack.all;
use work.attr_pack.all;

entity spi is 
        generic (c_csnum : integer range 2 to 5 := 2; 
                 fclk    : real range 25.0e6 to 100.0e6 := 31.25e6); 
        port (
	clk_bus : in std_logic;
	reset : in std_logic;
	db_i : in cpu_data_o_t;
	db_o : out cpu_data_i_t;
	spi_clk : out std_logic;
	spi_flashcs_o : out std_logic_vector(c_csnum - 1 downto 0);
	spi_miso : in std_logic;
	spi_mosi : out std_logic);

-- synopsys translate_off
	group bus_sigs : bus_ports(db_i, db_o);
-- synopsys translate_on
	attribute sei_port_local_name of spi_clk : signal is "clk";
	attribute sei_port_local_name of spi_flashcs_o : signal is "cs";
	attribute sei_port_local_name of spi_miso : signal is "miso";
	attribute sei_port_local_name of spi_mosi : signal is "mosi";

end entity spi;

architecture beh of spi is
        constant spi_clk_steps : integer range 0 to 127 := integer(ceil(fclk/800000.0)); -- (fclk/2)/400khz
        constant spi_clk_steps_diff : integer range -32 to 95 := spi_clk_steps - 32;

	signal rxbuf, rx_reg, txbuf, txdata : std_logic_vector(7 downto 0);
	signal counter : std_logic_vector(3 downto 0);
	signal cs_reg, cs1_reg, cs2_reg, cs3_reg, cs4_reg, cs1_n, cs2_n, cs3_n, cs4_n : std_logic;
	signal start, start1, counter_end, busy : std_logic;
	type t_state is (st_idle, st_redge, st_fedge, st_wait, st_done);
	signal spi_state : t_state;
	signal w_spi_mosi, w_miso, miso_sw : std_logic;
	signal  w_ackspi, w_ack : std_logic;
	signal div : std_logic_vector(6 downto 0);
	signal div_counter : integer range 0 to 127 := 40;
	signal mux_clk, mux_clk_enable : std_logic;
begin
	gen_5 : if c_csnum = 5 generate
		spi_flashcs_o <= cs4_n & cs3_n & cs2_n & cs1_n & cs_reg;
	end generate;
	gen_4 : if c_csnum = 4 generate
		spi_flashcs_o <= cs3_n & cs2_n & cs1_n & cs_reg;
	end generate;
	gen_3 : if c_csnum = 3 generate
	       	spi_flashcs_o <= cs2_n & cs1_n & cs_reg;
	end generate;
	gen_2 : if c_csnum = 2 generate
		spi_flashcs_o <= cs1_n & cs_reg;
       	end generate;
	cs1_n <= not cs1_reg;
	cs2_n <= not cs2_reg;
	cs3_n <= not cs3_reg;
	cs4_n <= not cs4_reg;
	db_o.ack <= db_i.en and w_ack;
	db_o.d <= x"000000" & "0" & cs4_reg & cs3_reg & cs2_reg & miso_sw & cs1_reg & busy & cs_reg when db_i.a(2) = '0' else
		  x"000000" & rx_reg;
	w_ack <= '1' when db_i.rd = '1' else
		 w_ackspi and db_i.en;
	counter_end <= counter(3);
	start <= db_i.wr and (not db_i.a(2)) and db_i.d(1);
	spi_mosi <= w_spi_mosi;
	w_miso <= spi_miso when miso_sw = '0' else
		  w_spi_mosi;

	-- Assume clk_bus is 25 MHz
	-- when div = 0: 12.5 MHz, div = 1: 6.25 MHz, div =2: 4.166 MHz 
	-- Fmux_clk = 12.5/(div + 1);
	-- Minium speed is 400K
	process(clk_bus, mux_clk_enable, reset, div) 
	begin
		if reset = '1' then
			div_counter <= 40;
		elsif rising_edge(clk_bus) then
                        -- <<< Temporary fix >>> Needs further work
                        -- SPI driver sets div either to 31 or 0.
                        -- Scale output spi_clk between (low speed 400Khz) to (full speed, i.e., fclk/ 2)
			if mux_clk =  '1' or mux_clk_enable = '0' then
                           if spi_clk_steps > 32 and div /= "0000000" then
		                div_counter <= to_integer(unsigned(div))+spi_clk_steps_diff;
                           else 
                                -- else when spi_clk_steps = 32 (< 32 indicates fclk < 25Mhz which we are not expecting)
                                -- or div = 0 in which case, need to set to max spi_clk speed (however, should be < 20Mhz)
				div_counter <= to_integer(unsigned(div));
                           end if;
			else
                           div_counter <= div_counter - 1;
			end if;
		end if;
	end process;
	mux_clk <= '1' when div_counter = 0 else
		   '0';

	process(clk_bus, reset)
	begin
		if reset = '1' then
			cs_reg <= '1';
			cs1_reg <= '0';
			cs2_reg <= '0';
			cs3_reg <= '0';
			cs4_reg <= '0';
			div <= std_logic_vector(to_unsigned(40,7)); -- for microboard
			miso_sw <= '0';
			txdata <= (others => '0');
			start1 <= '0';
		elsif rising_edge(clk_bus) then
			if db_i.wr = '1' then
				if db_i.a(2) = '0' then 
					cs_reg <= db_i.d(0);
				       	cs1_reg <= db_i.d(2);
				       	miso_sw <= db_i.d(3);
					cs2_reg <= db_i.d(4);
					cs3_reg <= db_i.d(5);
					cs4_reg <= db_i.d(6);
					div <= "00" & db_i.d(31 downto 27);
				else
				       	txdata <= db_i.d(7 downto 0);
				end if;
			end if;
			w_ackspi <= db_i.en;
			if start = '1' then
				start1 <= '1';
			elsif busy = '1' then
				start1 <= '0';
			end if;
		end if;
	end process;
	-- tested the maximum is 25 MHz for this FSM because of the routing delay.
	process(clk_bus, reset)
	begin
		if reset = '1' then
			spi_state <= st_idle;
			counter <= (others => '0');
			txbuf <= (others => '0');
			rx_reg <= (others => '0');
			rxbuf <= (others => '0');
			spi_clk <= '1';
			busy <= '0';
			mux_clk_enable <= '0';
			w_spi_mosi <= '1';
		elsif rising_edge(clk_bus) then
			case spi_state is 
				when st_idle => 
					counter <= (others => '0');
					spi_clk <= '1';
					if start1 = '1' then
						mux_clk_enable <= '1';
						spi_state <= st_fedge;
						txbuf <= txdata;
						busy <= '1';
					else
						mux_clk_enable <= '0';
						busy <= '0';
					end if;
				when st_fedge =>
					if mux_clk = '1' then
					       	w_spi_mosi <= txbuf(7);
						txbuf <= txbuf(6 downto 0) & '0';
						spi_clk <= '0';
						spi_state <= st_redge;
						counter <= std_logic_vector(to_unsigned(to_integer(unsigned(counter)) + 1,4));
					end if;
				when st_redge =>
					if mux_clk = '1' then
						spi_clk <= '1';
						if counter_end = '1' then
							spi_state <= st_wait;
						else
							spi_state <= st_fedge;
						end if;
						rxbuf <= rxbuf(6 downto 0) & w_miso;
					end if;
				when st_wait => 
					if mux_clk = '1' then
						spi_state <= st_done;
					end if;
				when st_done => 
					mux_clk_enable <= '0';
					spi_state <= st_idle;
					rx_reg <= rxbuf;
			end case;

		end if;
	end process;
	
end architecture beh;
