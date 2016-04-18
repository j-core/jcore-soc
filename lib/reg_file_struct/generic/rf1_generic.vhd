-- async / sync 1R sync 1W register file

architecture inferred of RF1 is

type mem_t is array ( natural range <> ) of std_logic_vector(WIDTH-1 downto 0);
signal mem : mem_t(0 to DEPTH-1); 

signal la0  : integer range 0 to DEPTH-1;

begin
   -- clock in and capture input data / address / write enable : sync write
   pw : process(clk, rst, D, WE, RA0, WA)
   begin
      if rst = '1' then
         la0 <= 0;
      elsif clk'event and clk = '1' then
         la0 <= RA0;

         if WE = '1' then mem(WA) <= D; end if;
      end if;
   end process;

   grb : if sync = false generate
      -- output buffers : async read
      q0 <= mem(ra0);
   end generate;

   grr : if sync = true generate
      -- output buffers : sync read
      q0 <= mem(la0);
   end generate;
end inferred;
