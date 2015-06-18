library ieee;
use ieee.std_logic_1164.all;

package gpio_pack is

  -- fixed width register data types
  subtype reg8x4_data is std_logic_vector(4 * 8 - 1 downto 0);
  subtype reg8x1_data is std_logic_vector(8 downto 0);
  subtype reg9x4_data is std_logic_vector(4 * 9 - 1 downto 0);

  attribute num_words : natural;
  attribute num_words of reg8x4_data : subtype is 4;
  attribute num_words of reg8x1_data : subtype is 1;
  attribute num_words of reg9x4_data : subtype is 4;

  -- write enable types
  subtype reg8x4_we is std_logic_vector(reg8x4_data'num_words - 1 downto 0);
  subtype reg8x1_we is std_logic_vector(reg8x1_data'num_words - 1 downto 0);
  subtype reg9x4_we is std_logic_vector(reg9x4_data'num_words - 1 downto 0);

  type reg8x4_fixed_i is record
    en : std_logic;
    wr : std_logic;
    we : reg8x4_we;
    d  : reg8x4_data;
  end record;
  type reg8x4_fixed_o is record
    d   : reg8x4_data;
    ack : std_logic;
  end record;

  type reg8x1_fixed_i is record
    en : std_logic;
    wr : std_logic;
    we : reg8x1_we;
    d  : reg8x1_data;
  end record;
  type reg8x1_fixed_o is record
    d   : reg8x1_data;
    ack : std_logic;
  end record;

  type reg9x4_fixed_i is record
    en : std_logic;
    wr : std_logic;
    we : reg9x4_we;
    d  : reg9x4_data;
  end record;
  type reg9x4_fixed_o is record
    d   : reg9x4_data;
    ack : std_logic;
  end record;

  function we_write(base : reg8x4_data; d : reg8x4_data; we : reg8x4_we)
    return reg8x4_data;

  type gpio_register is (
    REG_DATA,
    REG_MASK,
    REG_EDGE,
    REG_CHANGES
  );

  type gpio_registers is array(gpio_register'left to
                               gpio_register'right) of reg8x4_data;

  subtype gpio_data is std_logic_vector(31 downto 0);

  component gpio is port (
    clk : in std_logic;
    rst : in std_logic;

    reg : in gpio_register;
    d_i : in reg8x4_fixed_i;
    d_o : out reg8x4_fixed_o;

    irq : out std_logic;
    p_i : in gpio_data;
    p_o : out gpio_data);
  end component;

  type gpio_reg is record
    d_o : reg8x4_fixed_o;
    irq : std_logic;

    p_o : gpio_data;
    p_i : gpio_data;
    p_i2 : gpio_data;

    changes : reg8x4_data;
    edge : reg8x4_data;
    mask : reg8x4_data;
  end record;

  constant GPIO_RESET : gpio_reg := (
    d_o => (d => (others => '0'), ack => '0'),
    irq => '0',
    -- TODO: Do not understand why bit 31 resets to 1, but that was previous behaviour
    p_o => (31 => '1', others => '0'),
    p_i => (others => '0'),
    p_i2 => (others => '0'),
    changes => (others => '0'),
    edge => (others => '0'),
    mask => (others => '0')
  );
end gpio_pack;

package body gpio_pack is
  function we_write(base : reg8x4_data; d : reg8x4_data; we : reg8x4_we)
    return reg8x4_data is
    variable r : reg8x4_data := base;
    variable left : natural;
    variable right : natural;
  begin
    for i in 0 to reg8x4_data'num_words - 1 loop
      if we(i) = '1' then
        right := i * 8;
        left := right + 7;
        r(left downto right) := d(left downto right);
      end if;
    end loop;
    return r;
  end function;

end gpio_pack;
