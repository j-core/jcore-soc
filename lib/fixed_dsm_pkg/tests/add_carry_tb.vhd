library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fixed_float_types.all;
use work.fixed_pkg.all;
use work.test_pkg.all;

entity add_carry_tb is
end add_carry_tb;

architecture tb of add_carry_tb is

  -- maximum, minimum, and mins taken from fixed_pkg_c.vhd
  function maximum (
    l, r : integer)                    -- inputs
    return integer is
  begin  -- function max
    if l > r then return l;
    else return r;
    end if;
  end function maximum;
  function minimum (
    l, r : integer)                    -- inputs
    return integer is
  begin  -- function min
    if l > r then return r;
    else return l;
    end if;
  end function minimum;
  function mins (l, r : INTEGER)
    return INTEGER is
  begin  -- function mins
    if (L = INTEGER'low or R = INTEGER'low) then
      return 0;                         -- error condition, silent
    end if;
    return minimum (L, R);
  end function mins;


  procedure check_add_carry(
    a : in sfixed;
    b : in sfixed;
    c_in : in std_logic;
    expect_result : in sfixed;
    expect_c_out : in std_logic)
  is
    variable r : sfixed(maximum(a'high, b'high) downto mins(a'low, b'low));
    variable c : std_logic;
    --variable l : line;
    variable pass : boolean := true;
  begin
    add_carry(a, b, c_in, r, c);
    if expect_result /= r then
      pass := false;
      test_comment("next test result mismatch: expect "
                   & to_bstring(expect_result)
                   & " got " & to_bstring(r));
    end if;
    if expect_c_out /= c then
      pass := false;
      test_comment("next test carry out mismatch: expect "
                   & std_logic'image(expect_c_out)
                   & " got " & std_logic'image(c));
    end if;
    test_ok(pass, "signed add_carry " & to_bstring(a) & " + " & to_bstring(b) & " + "
            & std_logic'image(c_in)
            & " = " & to_bstring(expect_result) & " + " & std_logic'image(c));
  end procedure;


  function my_sfixed(x : std_logic_vector;
                    constant left_index : integer;
                    constant right_index : integer)
  return sfixed is
  begin
    return to_sfixed(x, left_index, right_index);
  end function;

  procedure check_add_carry(
    a : in ufixed;
    b : in ufixed;
    c_in : in std_logic;
    expect_result : in ufixed;
    expect_c_out : in std_logic)
  is
    variable r : ufixed(maximum(a'high, b'high) downto mins(a'low, b'low));
    variable c : std_logic;
    --variable l : line;
    variable pass : boolean := true;
  begin
    add_carry(a, b, c_in, r, c);
    if expect_result /= r then
      pass := false;
      test_comment("next test result mismatch: expect "
                   & to_bstring(expect_result)
                   & " got " & to_bstring(r));
    end if;
    if expect_c_out /= c then
      pass := false;
      test_comment("next test carry out mismatch: expect "
                   & std_logic'image(expect_c_out)
                   & " got " & std_logic'image(c));
    end if;
    test_ok(pass, "unsigned add_carry " & to_bstring(a) & " + " & to_bstring(b) & " + "
            & std_logic'image(c_in)
            & " = " & to_bstring(expect_result) & " + " & std_logic'image(c));
  end procedure;

  function my_ufixed(x : std_logic_vector;
                    constant left_index : integer;
                    constant right_index : integer)
  return ufixed is
  begin
    return to_ufixed(x, left_index, right_index);
  end function;

begin
  
  process
  begin
    test_plan(13, "add_carry_tb");

    check_add_carry(my_sfixed("000", 1, -1),
                    my_sfixed("000", 1, -1), '0',
                    my_sfixed("000", 1, -1), '0');

    check_add_carry(my_sfixed("001", 1, -1),
                    my_sfixed("000", 1, -1), '0',
                    my_sfixed("001", 1, -1), '0');

    check_add_carry(my_sfixed("001", 1, -1),
                    my_sfixed("000", 1, -1), '1',
                    my_sfixed("010", 1, -1), '0');

    test_comment("The carry out bit is set incorrectly in the signed case");
    check_add_carry(my_sfixed("111", 1, -1),
                    my_sfixed("000", 1, -1), '0',
                    my_sfixed("111", 1, -1), '0');

    check_add_carry(my_sfixed("110", 1, -1),
                    my_sfixed("000", 1, -1), '1',
                    my_sfixed("111", 1, -1), '0');
    
    check_add_carry(my_sfixed("111", 1, -1),
                    my_sfixed("001", 1, -1), '0',
                    my_sfixed("000", 1, -1), '1');

    check_add_carry(my_sfixed("111", 1, -1),
                    my_sfixed("000", 1, -1), '1',
                    my_sfixed("000", 1, -1), '1');

    check_add_carry(my_sfixed("111", 1, -1),
                    my_sfixed("001", 1, -1), '1',
                    my_sfixed("001", 1, -1), '1');

    test_comment("The carry out bit is set correctly in the unsigned case");
    check_add_carry(my_ufixed("111", 1, -1),
                    my_ufixed("000", 1, -1), '0',
                    my_ufixed("111", 1, -1), '0');

    check_add_carry(my_ufixed("110", 1, -1),
                    my_ufixed("000", 1, -1), '1',
                    my_ufixed("111", 1, -1), '0');
    
    check_add_carry(my_ufixed("111", 1, -1),
                    my_ufixed("001", 1, -1), '0',
                    my_ufixed("000", 1, -1), '1');

    check_add_carry(my_ufixed("111", 1, -1),
                    my_ufixed("000", 1, -1), '1',
                    my_ufixed("000", 1, -1), '1');

    check_add_carry(my_ufixed("111", 1, -1),
                    my_ufixed("001", 1, -1), '1',
                    my_ufixed("001", 1, -1), '1');
    
    wait;
  end process;
end architecture;
