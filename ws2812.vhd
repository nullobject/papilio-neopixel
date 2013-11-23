--------------------------------------------------------------------------
-- Package of dds components
--
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ws2812 is
  component ws2812_LED_chain_driver
    generic (
      SYS_CLK_RATE : real; -- underlying clock rate
      ADR_BITS     : natural; -- Must equal or exceed BIT_WIDTH(N_LEDS)+2.
      N_LEDS       : natural  -- Number of LEDs in chain
    );
    port (

      -- System Clock, Reset and Clock Enable
      sys_rst_n  : in  std_logic;
      sys_clk    : in  std_logic;
      sys_clk_en : in  std_logic;

      -- Selection of color information
      c_adr_o    : out unsigned(ADR_BITS-1 downto 0);
      c_dat_i    : in  unsigned(7 downto 0);

      -- Output
      sdat_o     : out std_logic
    );
  end component;
end ws2812;

package body ws2812 is
end ws2812;

-------------------------------------------------------------------------------
-- WS2812 "GRB" LED chain driver module
-------------------------------------------------------------------------------
--
-- Author: John Clayton
-- Update: Oct. 19, 2013 Started Coding, wrote description.
--
-- Description
-------------------------------------------------------------------------------
-- This module outputs a serial stream of NRZ data pulses which
-- are intended for driving a chain of WS2812 LED PWM driver ICs.
-- Actually, the WS2811 is the driver as a separate IC, and the WS2812 is
-- a complete RGB LED pixel with the driver built right in.  As costs drop
-- the popularity of this device is rising.
--
-- The datasheet seems to indicate some very specific timing requirements.
--
-- A '1' bit is apparently 0.35us high, followed by 0.8us low.
-- A '0' bit is apparently 0.7us high, followed by 0.6us low.
--
-- The datasheet also states that Th+Tl = 1.25us +/- 600 ns.
--
-- Well, based on that, this module chooses to use 1.25 microseconds
-- per bit time, which corresponds to 800kbps.  Internally, the system clock
-- rate is divided by 800000, and the result is the number of clock cycles
-- per bit available for creating the serial bitstream.
--
-- Then, constants are determined based on CLKS_PER_BIT according to the
-- following formulae:
--
--   CLKS_T0h = 0.28*CLKS_PER_BIT
--   CLKS_T1h = 0.54*CLKS_PER_BIT
--
-- This means that the timing will be closer or farther from ideal,
-- depending on the SYS_CLK_RATE.  For example:
--
--   Fsys_clk = 50 MHz
--   CLKS_PER_BIT = 62.5 which is rounded down to 62.
--   CLKS_T0h = 17.36 which is rounded down to 17.
--   CLKS_T1h = 33.48 which is rounded down to 33.
--   This leaves 45 clocks for the T0l time.
--   This leaves 29 clocks for the T1l time.
--
--   For this example, the bit time is 1.24us.
--   The T0h is 0.34us and T0l is 0.9us.
--   The T1h is 0.66us and T1l is 0.58us.
--
-- The lower the SYS_CLK_RATE, the tougher it is to meet the stated timing
-- requirements of the WS2812 device.  Using this scheme, the lowest clock
-- rate supported is 20 MHz.
--
-- The LEDs are driven with 24-bit color, that is 8 bits for red
-- intensity, 8 bits for green intensity and 8 bits for blue intensity.
--
-- I stopped short of calling it an "RGB LED driver" since WS2811/WS2812
-- receives the data in the order "GRB."  The ordering of the color
-- bits should not really matter anyway, so let's just be very accepting,
-- shall we not?
--
-- After the entire sequence of serial bits is driven out for updating the
-- GRB colors of the LEDs, then a reset interval of RESET_CLKS is given,
-- where RESET_CLKS is set by constants.
--
-- Interestingly, it seems that sending extra color information will not
-- affect the LED string in a negative way.  So, for example, if there
-- are only eight devices in the string, and the module is configured to
-- send out data for 10 devices, then the first eight devices will run
-- just fine.
--
-- Yes, that is correct, the LEDs closest to the source of sdat_o get lit
-- first, then they become "passthrough" so that the next one gets lit, and
-- so forth.
--
-- This module latches color information from an external source.
-- It provides the c_adr_o signal to specify which information
-- should be selected.  In this way, the module can be used with a variable
-- numbers of WS2811/WS2812 devices in the chain.
--
-- Just to keep things on an even keel, the c_adr_o address
-- advances according to the following pattern:
--
-- 0,1,2,4,5,6,8,9,A,C,D,E...
--
-- What is happening is that one address per LED is getting skipped
-- or "wasted" in order to start with each LEDs green value on an
-- even multiple N*4, where N is the LED number, beginning with zero
-- for the "zeroth" LED.  Then the red values are at N*4+1, while
-- the blue values are at N*4+2.  The N*4+3 values are simply skipped.
-- Isn't that super organized?
--
-- This unit runs continuously, the only way to stop it is to lower
-- the sys_clk_en input.
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;

entity ws2812_LED_chain_driver is
  generic (
    SYS_CLK_RATE : real := 50000000.0; -- underlying clock rate
    ADR_BITS     : natural := 8; -- Must equal or exceed BIT_WIDTH(N_LEDS)+2.
    N_LEDS       : natural := 8  -- Number of LEDs in chain
  );
  port (
    -- System Clock, Reset and Clock Enable
    sys_rst_n  : in  std_logic;
    sys_clk    : in  std_logic;
    sys_clk_en : in  std_logic;

    -- Selection of color information
    c_adr_o    : out unsigned(ADR_BITS-1 downto 0);
    c_dat_i    : in  unsigned(7 downto 0);

    -- Output
    sdat_o     : out std_logic
  );
end ws2812_LED_chain_driver;

architecture beh of ws2812_LED_chain_driver is
  function timer_width (maxval : integer) return integer is
    variable w : integer;
  begin
    if (maxval < 2) then
      w := 1;
    else
      w := integer(ceil(log2(real(maxval+1))));
    end if;

    return  w;
  end timer_width;

  function bit_width (maxval : integer) return integer is
    variable w : integer;
  begin
    if (maxval < 2) then
      w := 1;
    else
      w := integer(ceil(log2(real(maxval))));
    end if;

    return  w;
  end bit_width;

  -- Constants
  constant LED_BIT_RATE   : real := 800000.0;
  constant CLKS_PER_BIT   : natural := integer(floor(SYS_CLK_RATE/LED_BIT_RATE));
  constant CLKS_T0_H      : natural := integer(floor(0.28*SYS_CLK_RATE/LED_BIT_RATE));
  constant CLKS_T1_H      : natural := integer(floor(0.54*SYS_CLK_RATE/LED_BIT_RATE));
  constant SUB_COUNT_BITS : natural := bit_width(CLKS_PER_BIT);
  constant STRING_BYTES   : natural := 3*N_LEDS;
  constant RESET_TIME     : real := 0.000050; -- "time" data type could have been used...
  constant RESET_BCOUNT   : natural := integer(floor(RESET_TIME*LED_BIT_RATE));
  constant RESET_BITS     : natural := timer_width(RESET_BCOUNT);

  -- Signals
  signal reset_count : unsigned(RESET_BITS-1 downto 0);
  signal sub_count   : unsigned(SUB_COUNT_BITS-1 downto 0);
  signal bit_count   : unsigned(2 downto 0);
  signal byte_count  : unsigned(bit_width(STRING_BYTES)-1 downto 0);
  signal c_adr       : unsigned(ADR_BITS-1 downto 0);
  signal c_dat       : unsigned(7 downto 0);
begin
  c_adr_proc: Process(sys_rst_n, sys_clk)
  begin
    if (sys_rst_n = '0') then
      reset_count <= to_unsigned(RESET_BCOUNT,reset_count'length);
      sub_count  <= (others=>'0');
      byte_count <= (others=>'0');
      c_adr      <= (others=>'0');
      c_dat      <= (others=>'0');
      bit_count  <= (others=>'0');
    elsif (sys_clk'event and sys_clk='1') then
      if (sys_clk_en='1') then
        -- Sub count just keeps going all the time, during reset
        -- and during data transition.
        sub_count <= sub_count+1;
        if (sub_count=CLKS_PER_BIT-1) then
          sub_count <= (others=>'0');
        end if;

        -- Reset count decrements until reaching one, then
        -- it is set to zero while data is shifted out.
        -- It decrements once for each bit time.
        if (reset_count>0) then
          if (sub_count=CLKS_PER_BIT-1) then
            reset_count <= reset_count-1;
          end if;
        end if;

        -- When reset count reaches zero, color data shifting occurs
        if (reset_count>0) then
          c_adr <= (others=>'0');
          if (reset_count=1 and sub_count=CLKS_PER_BIT-1) then
            c_adr <= c_adr+1; -- Data from first address is loaded during reset time...
          end if;
          c_dat <= c_dat_i;
        else
          if (sub_count=CLKS_PER_BIT-1) then
            c_dat <= c_dat(c_dat'length-2 downto 0) & '0'; -- shift
            bit_count <= bit_count+1;
            if (bit_count=7) then
              c_dat <= c_dat_i;
              if (c_adr(1 downto 0)="10") then
                c_adr <= c_adr+2;
                if (byte_count=STRING_BYTES-1) then
                  byte_count <= (others=>'0');
                  reset_count <= to_unsigned(RESET_BCOUNT,reset_count'length);
                else
                  byte_count <= byte_count+1;
                end if;
              else
                c_adr <= c_adr+1;
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process;

  sdat_o <= '0' when (reset_count>0) else
            '1' when (c_dat(7)='1') and (sub_count<CLKS_T1_H) else
            '1' when (sub_count<CLKS_T0_H) else
            '0';

  c_adr_o <= c_adr;
end beh;
