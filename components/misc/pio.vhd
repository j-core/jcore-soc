library ieee;
use ieee.std_logic_1164.all;
use work.cpu2j0_pack.all;
use work.attr_pack.all;

entity pio is
	generic (
	DEFAULT_OUT : std_logic_vector(31 downto 0) := (31 => '1', others => '0'));
	port (
	clk_bus : in std_logic;
	reset : in std_logic;
	db_i : in cpu_data_o_t;
	db_o : out cpu_data_i_t;
	irq : out std_logic;
	p_i : in std_logic_vector(31 downto 0);
	p_o : out std_logic_vector(31 downto 0));

-- synopsys translate_off
	group bus_sigs : bus_signals(irq,db_i, db_o);
-- synopsys translate_on
	attribute sei_port_irq of irq : signal is true;
	attribute sei_port_global_name of p_o : signal is "po";
	attribute sei_port_global_name of p_i : signal is "pi";
end entity pio;

architecture beh of pio is
	signal pio_dout : std_logic_vector(31 downto 0);
	signal pi_reg2, pi_reg, pi_edge, pi_changes, pi_mask : std_logic_vector(31 downto 0);
	signal pi_chread : std_logic;
	signal irq_r0, irq_r1 : std_logic;
begin
	p_o <= pio_dout;
	db_o.d <= pi_changes when db_i.a(5 downto 2) = "0011" else
		  pi_edge when db_i.a(5 downto 2) = "0010" else
		  pi_mask when db_i.a(5 downto 2) = "0001" else
		  pi_reg;
	db_o.ack <= db_i.en;
	irq <=  irq_r0  and not irq_r1;		-- on the rising edge

	process(clk_bus, reset)
	begin
		if reset = '1' then
			pi_mask <= (others => '0');
			pi_reg <= (others => '0');
			pi_reg2 <= (others => '0');
			pi_edge <= (others => '0');
		       	pio_dout <= DEFAULT_OUT;
			irq_r1 <= '0';
			irq_r0 <= '0';
	       	elsif rising_edge(clk_bus) then
			pi_reg <= p_i;
			pi_reg2 <= pi_reg;
			pi_chread <= '0';
		       	if db_i.wr = '1' then
				if db_i.a(5 downto 2) = "0000" then	-- 0 -- 3 W for PO
					if db_i.we(3) = '1' then 
						pio_dout(31 downto 24) <= db_i.d(31 downto 24);
					end if;
					if db_i.we(2) = '1' then
						pio_dout(23 downto 16) <= db_i.d(23 downto 16);
					end if;
					if db_i.we(1) = '1' then
						pio_dout(15 downto 8) <= db_i.d(15 downto 8);
					end if;
					if db_i.we(0) = '1' then
						pio_dout(7 downto 0) <= db_i.d(7 downto 0);
					end if;
				elsif db_i.a(5 downto 2) = "0001" then	-- 4 -- 7 for PI mask
					pi_mask <= db_i.d;
				elsif db_i.a(5 downto 2) = "0010" then
					pi_edge <= db_i.d;
				end if;
			elsif db_i.rd = '1' and db_i.a(5 downto 2) = "0011" then
				pi_chread <= '1';
			end if;
			-- PI edge detect
			for i in 0 to 31 loop
				if pi_chread = '1' then
					pi_changes(i) <= '0';
				elsif pi_reg2(i) = '1' and pi_reg(i) = '0' then
					pi_changes(i) <= '1';
				elsif pi_reg2(i) = '0' and pi_reg(i) = '1' then	-- falling edge
					if pi_edge(i) = '1' then
					       	pi_changes(i) <= '1';
					end if;
				end if;
			end loop;
			if (pi_mask and pi_changes) = x"00000000" then
				irq_r0 <= '0';
			else
				irq_r0 <= '1';
			end if;
			irq_r1 <= irq_r0;
	       	end if;
       	end process;
end architecture beh;
