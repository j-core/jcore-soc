library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.cpu2j0_pack.all;
use work.misc_pack.all;
use work.aic2_pack.all;

entity aic is 
	generic (
	c_busperiod : integer := 40;
	-- sets the vector number sent to the CPU for each of the 8 elements of
        -- the irq_i port
	vector_numbers : v_irq_t := (x"11", x"12", x"13", x"14", x"15", x"16", x"17", x"18")
	);
	port (
	clk_bus : in std_logic;
	rst_i : in std_logic;
	db_i : in cpu_data_o_t;
	db_o : out cpu_data_i_t;
	bstb_i : in std_logic;	-- bus stb use for breakpoint only
	back_i : in std_logic;	-- bus ack: use for breakpoint only
	rtc_sec : out std_logic_vector(63 downto 0);	-- clk_bus domain
	rtc_nsec : out std_logic_vector(31 downto 0);
	irq_i : in std_logic_vector(7 downto 0) := (others => '0');
	enmi_i : in std_logic;
	event_i : in cpu_event_o_t;
	event_o : out cpu_event_i_t
);
end aic;

architecture behav of aic is
	constant c_event_nmi : std_logic_vector(2 downto 0) := "001";
	constant c_event_irq : std_logic_vector(2 downto 0) := "000";
	constant c_event_cer : std_logic_vector(2 downto 0) := "010";
	constant c_event_der : std_logic_vector(2 downto 0) := "011";
	constant c_event_mres : std_logic_vector(2 downto 0) := "110";
	constant c_event_nevt : std_logic_vector(2 downto 0) := "111";
	-- use one hot encode
	constant c_id1 : std_logic_vector(9 downto 0) := "00" & x"01";
	constant c_id10 : std_logic_vector(9 downto 0) := "10" & x"00";
	-- The following is IRQ level(3 downto 0) & vector(7 downto 0) for each irq_i
	constant id_irq : v_irq_t := (x"01", x"02", x"04", x"08", x"10", x"20", x"40", x"80");
	-- Assume irq_i(0) is the highest level, irq_i(7) is the lowest level 
	-- switch the orders if nessrary
	component aic_edgedet port (
		q : out std_logic;
		clk : in std_logic;
		rst : in std_logic;
		irq : in std_logic;
		en_i : in std_logic;
		clr_i : in std_logic);
	end component aic_edgedet;

	signal reg_event, w_event, w_irqevent : std_logic_vector(24 downto 0);
	signal  w_ack : std_logic;
	signal s_enmi, s_eirq, s_eirq2, s_cer, s_der, s_mrs, w_wctrl, w_enmi: std_logic;
	signal w_cer1, w_cer2, w_cer3 : std_logic;
	signal testvect : std_logic_vector(11 downto 0);
	signal count_enable, pit_enable, brk_enable, pit_event : std_logic;
	signal count : std_logic_vector(11 downto 0);
	signal brkadr : std_logic_vector(31 downto 0);
	signal r_nmi, r_irq1, r_irq10, r_cpuerr, r_dmaerr, r_mrst: std_logic;
	signal w_debug, w_pitout, w_rtcout : std_logic_vector(31 downto 0);
	signal pit_cntr, pit_throttle : std_logic_vector(31 downto 0);
	signal reg_rtc_sec : std_logic_vector(63 downto 0);
	signal reg_rtc_nsec : std_logic_vector(31 downto 0);
	signal es_irqs, q_irqs, ec_irqs : std_logic_vector(7 downto 0);
	type ilevel_t is array(0 to 7) of std_logic_vector(3 downto 0);
	signal ilevel : ilevel_t;
	signal qq_irqs : std_logic;
	signal vnmi : std_logic;
	signal vcount : std_logic_vector(20 downto 0);
	type t_vstate is (v_idle, v_int, v_dly_check, v_check);
	signal vstate : t_vstate;

	-- debug
	type db_state_t is (db_init, db_int);
	signal db_state, da_state : db_state_t;
	signal db_count : std_logic_vector(3 downto 0);
	signal db_ackcount : std_logic_vector(10 downto 0);
	signal pit_flag : std_logic;	-- flip over when there is PIT event

	signal event_req : std_logic_vector(2 downto 0);
	signal event_info : std_logic_vector(11 downto 0);
begin
	event_o <= to_event_i(event_req, event_info);
	get_irqs : for irr in irq_i'range generate
		iedge_inst : aic_edgedet port map( q => q_irqs(irr), clk => clk_bus, rst => rst_i, irq => irq_i(irr), en_i => es_irqs(irr), clr_i => ec_irqs(irr));
	end generate;
	rtc_sec <= reg_rtc_sec;
	rtc_nsec <= reg_rtc_nsec;
	-- For now RTC is read only
	p_rtc : process(clk_bus, rst_i)
	begin
		if rst_i = '1' then
			reg_rtc_sec <= (others => '0');
			reg_rtc_nsec <= (others => '0');
		elsif rising_edge(clk_bus) then	
			if reg_rtc_nsec >= std_logic_vector(to_unsigned(1e9, reg_rtc_nsec'length)) then
				reg_rtc_nsec <= reg_rtc_nsec -  (1e9 - c_busperiod);	--999999960;
				reg_rtc_sec <= reg_rtc_sec + 1;
			else
				reg_rtc_nsec <= reg_rtc_nsec + c_busperiod;
			end if;
			if (db_i.wr and db_i.a(5)) = '1' then
				if db_i.a(3 downto 2) = "00" then
					reg_rtc_sec(63 downto 32) <= db_i.d;
				elsif db_i.a(3 downto 2) = "01" then
					reg_rtc_sec(31 downto 0) <= db_i.d;
				elsif db_i.a(3 downto 2) = "10" then
					reg_rtc_nsec <= db_i.d;
				end if;
			end if;
		end if;
	end process;

	p_debug : process(clk_bus, rst_i) 
	begin
		if rst_i = '1' then
			db_count <= (others => '0');
			db_state <= db_init;
			da_state <= db_init;
			db_ackcount <= (others => '0');
		elsif rising_edge(clk_bus) then
                        db_ackcount <= (others => '1');--yk added temp to easy timing 
			case db_state is 
				when db_init =>
					if q_irqs(6) = '1' then
						db_state <= db_int;
						db_count <= db_count + 1;
					end if;
				when db_int =>
					if q_irqs(6) = '0' then
						db_state <= db_init;
					end if;
			end case;
			case da_state is
				when db_init =>
					if event_i.ack = '1' then
						da_state <= db_int;
						--yk commented; db_ackcount <= db_ackcount + 1;
					end if;
				when db_int =>
					if event_i.ack = '0' then
						da_state <= db_init;
					end if;
			end case;
		end if;
	end process;

	db_o.ack <= '0' when db_i.en = '0' else
		     '1' when db_i.rd = '1' else
		     w_ack;

        -- Register layout for reads
        -- addr bits
        -- 5432   Contents
        -----------------------------------
        -- 0000 - "00000" & pit_enable & count_enable & brk_enable & testvect & count
        -- 0001 - brkadd
        -- 0010 - ilevels
        -- 0011 - irq_i & q_irqs & pit_flag & db_ackcount & db_count
        -- 0100 - PIT throttle
        -- 0101 - PIT counter
        -- 0110 - Bus clock period in nanoseconds
        -- 0111 - zero
        -- 1x00 - RTC seconds upper 32 bits
        -- 1x01 - RTC seconds lower 32 bits
        -- 1x10 - RTC nanoseconds
        -- 1x11 - zero
	db_o.d <= w_rtcout when db_i.a(5) = '1' else
		  w_pitout when db_i.a(4) = '1' else
		  w_debug when db_i.a(3) = '1' else
		  "00000" & pit_enable & count_enable & brk_enable & testvect & count when db_i.a(2) = '0' else
		  brkadr;
	w_debug <= ilevel(7) & ilevel(6) & ilevel(5) & ilevel(4) & ilevel(3) & ilevel(2) & ilevel(1) & ilevel(0) when db_i.a(2) = '0' else
		   irq_i & q_irqs & pit_flag & db_ackcount & db_count;
	w_pitout <= (others => '0') when db_i.a(3 downto 2) = "11" else
                    std_logic_vector(to_unsigned(c_busperiod, w_pitout'length)) when db_i.a(3) = '1' else
		    pit_throttle when db_i.a(2) = '0' else
		    pit_cntr;
	w_rtcout <= reg_rtc_sec(63 downto 32) when db_i.a(3 downto 2) = "00" else
		    reg_rtc_sec(31 downto 0) when db_i.a(3 downto 2) = "01" else
		    reg_rtc_nsec when db_i.a(3 downto 2) = "10" else
		    (others => '0');
	-- external set IRQ using interrupt priority level. when the level is 0. the interrupt is disabled

	es_irqs(0) <= ilevel(0)(0) or ilevel(0)(1) or ilevel(0)(2) or ilevel(0)(3);
	es_irqs(1) <= ilevel(1)(0) or ilevel(1)(1) or ilevel(1)(2) or ilevel(1)(3);
	es_irqs(2) <= ilevel(2)(0) or ilevel(2)(1) or ilevel(2)(2) or ilevel(2)(3);
	es_irqs(3) <= ilevel(3)(0) or ilevel(3)(1) or ilevel(3)(2) or ilevel(3)(3);
	es_irqs(4) <= ilevel(4)(0) or ilevel(4)(1) or ilevel(4)(2) or ilevel(4)(3);
	es_irqs(5) <= ilevel(5)(0) or ilevel(5)(1) or ilevel(5)(2) or ilevel(5)(3);
	es_irqs(6) <= ilevel(6)(0) or ilevel(6)(1) or ilevel(6)(2) or ilevel(6)(3);
	es_irqs(7) <= ilevel(7)(0) or ilevel(7)(1) or ilevel(7)(2) or ilevel(7)(3);
	qq_irqs <= q_irqs(0) or q_irqs(1) or q_irqs(2) or q_irqs(3) or q_irqs(4) or q_irqs(5) or q_irqs(6) or q_irqs(7);

	w_event <= x"00" & "00" & c_event_mres & x"f02" when r_mrst = '1' else
		   x"00" & "00" & c_event_der & x"f0a" when r_dmaerr = '1' else
		   x"00" & "00" & c_event_cer & x"f09" when r_cpuerr = '1' else
		   c_id1 & c_event_nmi & x"f0b" when r_nmi = '1' else
		   c_id1 & c_event_irq & testvect when r_irq1 = '1' else
		   w_irqevent when qq_irqs = '1' else
		   c_id10 & c_event_irq & x"319" when r_irq10 = '1' else 
		   x"00" & "00" & c_event_nevt & x"f18";
	p_lat : process(clk_bus, rst_i) 
	begin
		if rst_i = '1' then
			reg_event(14 downto 12) <= (others => '1');
			reg_event(11 downto 0) <= x"F18";
			reg_event(24 downto 15) <= (others => '0');
		elsif rising_edge(clk_bus) then
			reg_event <= w_event;
		end if;
	end process p_lat;
	event_req <= reg_event(14 downto 12);
	event_info <= reg_event(11 downto 0);

	p_priority: process(q_irqs, ilevel)
		variable high_i :integer range 0 to 7 := 0;
		variable high_level : std_logic_vector(3 downto 0);
	begin
		high_i := 0;
		high_level := (others => '0');
		for i in q_irqs'range loop
			if q_irqs(i) = '1' then
				if ilevel(i) > high_level then
					high_level := ilevel(i);
					high_i := i;
				end if;
			end if;
		end loop;
		w_irqevent <= '0' & id_irq(high_i) & '0' & c_event_irq & ilevel(high_i) & vector_numbers(high_i);
	end process p_priority;
	pit_event <= '1' when pit_cntr = pit_throttle else
		     '0';

	p_interface: process(clk_bus, rst_i)
	begin
		if rst_i = '1' then
			brkadr <= (others => '0');
			pit_enable <= '0';
			pit_cntr <= (others => '0');
			-- default pit_throttle to 100 Hz
			pit_throttle <= std_logic_vector(to_unsigned(1e9 / 100 / c_busperiod,
					pit_throttle'length));
			count_enable <= '0';
			count <= (others => '1');
			brk_enable <= '0';
			w_ack <= '0';
			r_nmi <= '0';
			r_irq1 <= '0';
			r_irq10 <= '0';
			r_cpuerr <= '0';
			r_dmaerr <= '0';
			r_mrst <= '0';
			for ii in 0 to 7 loop
				ilevel(ii) <= (others => '0');
			end loop;
			testvect <= (others => '0');
			ec_irqs <= (others => '1');
			pit_flag <= '0';
		elsif rising_edge(clk_bus) then
			w_ack <= db_i.en;
			if db_i.wr = '1' and db_i.a(5) = '0' then
				if db_i.a(4) = '0' then
					if db_i.a(3) = '0' then
						if db_i.a(2) = '0' then
							if pit_enable = '0' then
								testvect <= db_i.d(23 downto 12);
							end if;
							brk_enable <= db_i.d(24);
							count_enable <= db_i.d(25);
							pit_enable <= db_i.d(26);
							count <= db_i.d(11 downto 0);
						else
							brkadr <= db_i.d;
						end if;
					elsif db_i.a(2) = '0' then
						ilevel(7) <= db_i.d(31 downto 28);
						ilevel(6) <= db_i.d(27 downto 24);
						ilevel(5) <= db_i.d(23 downto 20);
						ilevel(4) <= db_i.d(19 downto 16);
						ilevel(3) <= db_i.d(15 downto 12);
						ilevel(2) <= db_i.d(11 downto 8);
						ilevel(1) <= db_i.d(7 downto 4);
						ilevel(0) <= db_i.d(3 downto 0);
					end if;
				else	-- db_i.a(4) = '1' 
					if db_i.a(3 downto 2) = "00" then
						if pit_enable = '0' then
							pit_throttle <= db_i.d;
						end if;
					end if;
				end if;
			end if;
			if count_enable = '1' then
				count <= count - 1;
			end if;
			if pit_enable = '1' then
				if pit_event = '1' then
					pit_cntr <= (others => '0');
					pit_flag <= not pit_flag;
				else
					pit_cntr <= pit_cntr + 1;
				end if;
			else
				pit_cntr <= (others => '0');
			end if;
			if s_mrs = '1' then
				r_mrst <= '1';
			end if;
			if s_cer = '1' then
				r_cpuerr <= '1';
			end if;
			if s_der = '1' then
				r_dmaerr <= '1';
			end if;
			if s_eirq = '1' then
				r_irq1 <= '1';
			end if;
			if s_eirq2 = '1' then
				r_irq10 <= '1';
			end if;
			if s_enmi = '1' then
				r_nmi <= '1';
			end if;
			if event_i.ack = '1' then
				ec_irqs <= (others => '0');
				if reg_event(14 downto 12) = c_event_mres then
					r_mrst <= '0';
			       	elsif reg_event(14 downto 12) = c_event_cer then
				       	r_cpuerr <= '0';
			       	elsif reg_event(14 downto 12) = c_event_der then
				       	r_dmaerr <= '0';
			       	elsif reg_event(14 downto 12) = c_event_nmi then
				       	r_nmi <= '0';
			       	elsif reg_event(14 downto 12) = c_event_irq then
				       	if reg_event(15) = '1' then
					       	r_irq1 <= '0';
					elsif reg_event(24) = '1' then
						r_irq10 <= '0';
					end if;
					ec_irqs <= reg_event(23 downto 16);
				end if;
			else
				ec_irqs <= (others => '0');
			end if;
		end if;
	end process p_interface;

	w_wctrl <= '0' when db_i.wr = '0' else
		   '0' when db_i.a(5 downto 2) /= "0000" else
		   '0' when db_i.we(3) = '0' else
		   '1';
	s_mrs <= w_wctrl and db_i.d(27);
	s_der <= w_wctrl and db_i.d(28);
	-- CPU Error detect
	s_cer <= (w_wctrl and db_i.d(29)) or w_cer1 or w_cer2 or w_cer3;
	w_cer1 <= bstb_i and db_i.we(3) and db_i.we(2) and not db_i.we(1) and not db_i.we(0) and back_i and db_i.a(1);
       	w_cer2 <=  bstb_i and not db_i.we(3) and not db_i.we(2) and db_i.we(1) and db_i.we(0) and back_i and not db_i.a(1);
       	w_cer3 <=  bstb_i and db_i.we(3) and db_i.we(2) and db_i.we(1) and db_i.we(0) and back_i and (db_i.a(0) or db_i.a(1)) ;
	-- PIT interrupt

	s_eirq <= (w_wctrl and db_i.d(30)) or pit_event;
	s_eirq2 <= count_enable when (count = x"000") else '0';
	s_enmi <= (w_wctrl and db_i.d(31)) or w_enmi or vnmi;
	w_enmi <= brk_enable and bstb_i and back_i when db_i.a = brkadr else '0';
	-- Vlad's test NMI hack stuff
	process(clk_bus, rst_i) 
	begin
		if rst_i = '1' then
			vstate <= v_idle;
			vnmi <= '0';
			vcount <= (others => '0');
		elsif rising_edge(clk_bus) then
			case vstate is 
				when v_idle => 
					if enmi_i = '0' then
						vstate <= v_int;
						vnmi <= '1';
					end if;
				when v_int => 
					vnmi <= '0';
					vstate <= v_dly_check;
					vcount <= (others => '0');
				when v_dly_check => -- check if high every 5 mS
					if vcount > x"1312d0" then
						vstate <= v_check;
					else
						vcount <= vcount +1;
					end if;
				when v_check => 
					if enmi_i = '1' then 
						vstate <= v_idle;
					else
						vcount <= (others => '0');
						vstate <= v_dly_check;
					end if;
			end case;
		end if;
	end process;
end behav;
