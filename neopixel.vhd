library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ws2812.all;

entity neopixel is
  port (
    clk : in std_logic;
    a : out std_logic_vector(0 downto 0)
  );
end neopixel;

architecture neopixel_arch of neopixel is
  constant BRIGHTNESS : natural := 16;

  signal led_address : unsigned(1 downto 0);
  signal led_data : unsigned(7 downto 0);
  signal output : std_logic;

begin
  led_driver: ws2812_LED_chain_driver
    generic map (SYS_CLK_RATE => 32000000.0,
                 ADR_BITS     => 2,
                 N_LEDS       => 1)

    port map (sys_rst_n  => '1',
              sys_clk    => clk,
              sys_clk_en => '1',
              c_adr_o    => led_address,
              c_dat_i    => led_data,
              sdat_o     => output);

  lookup_pixels: process(led_address)
  begin
    if led_address = "00" then
      led_data <= to_unsigned(BRIGHTNESS, led_data'length);
    else
      led_data <= to_unsigned(0, led_data'length);
    end if;
  end process;

  output_ports: process(clk, output)
  begin
    if rising_edge(clk) then
      a(0) <= output;
    end if;
  end process;
end neopixel_arch;
