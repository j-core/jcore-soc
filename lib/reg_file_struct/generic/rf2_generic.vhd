-- async / sync 2R sync 1W register file

architecture inferred of RF2 is

type mem_t is array ( natural range <> ) of std_logic_vector(WIDTH-1 downto 0);
signal mem : mem_t(0 to DEPTH-1); 

signal la0  : integer range 0 to DEPTH-1;
signal la1  : integer range 0 to DEPTH-1;

begin
   -- clock in and capture input data / address / write enable : sync write
   pw : process(clk, rst, D, WE, RA0, RA1, WA)
   begin
      if rst = '1' then
         la0 <= 0;
         la1 <= 0;
      elsif clk'event and clk = '1' then
         la0 <= RA0;
         la1 <= RA1;

         if WE = '1' then mem(WA) <= D; end if;
      end if;
   end process;

   grb : if sync = false generate
      -- output buffers : async read
      q0 <= mem(ra0);
      q1 <= mem(ra1);
   end generate;

   grr : if sync = true generate
      -- output buffers : sync read
      q0 <= mem(la0);
      q1 <= mem(la1);
   end generate;
end inferred;
