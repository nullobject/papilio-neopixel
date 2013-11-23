library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ws2812.all;

entity neopixel is
  port (
    clk : in std_logic;
    a   : out unsigned(0 downto 0)
  );
end neopixel;

architecture neopixel_arch of neopixel is
  constant ADDR_WIDTH : integer := 5;
  constant DATA_WIDTH : integer := 8;

  signal ram_we      : std_logic;
  signal ram_addr_a  : unsigned(ADDR_WIDTH-1 downto 0);
  signal ram_addr_b  : unsigned(ADDR_WIDTH-1 downto 0);
  signal ram_din_a   : unsigned(DATA_WIDTH-1 downto 0);
  signal ram_dout_a  : unsigned(DATA_WIDTH-1 downto 0);
  signal ram_dout_b  : unsigned(DATA_WIDTH-1 downto 0);

  signal led_address : unsigned(ADDR_WIDTH-1 downto 0);
  signal led_data    : unsigned(DATA_WIDTH-1 downto 0);
  signal led_output  : std_logic;

  signal        address : std_logic_vector(11 downto 0);
  signal    instruction : std_logic_vector(17 downto 0);
  signal    bram_enable : std_logic;
  signal        in_port : std_logic_vector(7 downto 0);
  signal       out_port : std_logic_vector(7 downto 0);
  signal        port_id : std_logic_vector(7 downto 0);
  signal   write_strobe : std_logic;
  signal k_write_strobe : std_logic;
  signal    read_strobe : std_logic;
  signal      interrupt : std_logic;
  signal  interrupt_ack : std_logic;
  signal   kcpsm6_sleep : std_logic;
  signal   kcpsm6_reset : std_logic;
begin
  ram: entity work.dual_port_async_ram(dual_port_async_ram_arch)
    generic map (ADDR_WIDTH => ADDR_WIDTH)
    port map (clk    => clk,
              we     => ram_we,
              addr_a => ram_addr_a,
              addr_b => ram_addr_b,
              din_a  => ram_din_a,
              dout_a => ram_dout_a,
              dout_b => ram_dout_b);

  led_driver: ws2812_LED_chain_driver
    generic map (SYS_CLK_RATE => 32000000.0,
                 ADR_BITS     => ADDR_WIDTH,
                 N_LEDS       => 8)
    port map (sys_rst_n  => '1',
              sys_clk    => clk,
              sys_clk_en => '1',
              c_adr_o    => led_address,
              c_dat_i    => led_data,
              sdat_o     => led_output);

  processor: entity work.kcpsm6(low_level_definition)
    port map(      address => address,
               instruction => instruction,
               bram_enable => bram_enable,
                   port_id => port_id,
              write_strobe => write_strobe,
            k_write_strobe => k_write_strobe,
                  out_port => out_port,
               read_strobe => read_strobe,
                   in_port => in_port,
                 interrupt => interrupt,
             interrupt_ack => interrupt_ack,
                     sleep => kcpsm6_sleep,
                     reset => kcpsm6_reset,
                       clk => clk);

  kcpsm6_sleep <= '0';
  interrupt <= interrupt_ack;

  program_rom: entity work.control(low_level_definition)
    generic map(C_JTAG_LOADER_ENABLE => 1)

    port map(address     => address,
             instruction => instruction,
             enable      => bram_enable,
             rdl         => kcpsm6_reset,
             clk         => clk);

  -- Reads the data requested by the LED driver at the LED address.
  read_led_data: process(clk, led_address, ram_dout_b)
  begin
    if rising_edge(clk) then
      ram_addr_b <= led_address;
      led_data <= ram_dout_b;
    end if;
  end process;

  -- Writes the LED output from the LED driver.
  write_led_output: process(clk, led_output)
  begin
    if rising_edge(clk) then
      a(0) <= led_output;
    end if;
  end process;

  -- Writes data from the processor output ports to the RAM.
  processor_output_ports: process(clk)
  begin
    if rising_edge(clk) then
      ram_we <= write_strobe;

      if port_id(0) = '1' then
        ram_addr_a <= to_unsigned(0, ram_addr_a'length);
        ram_din_a <= unsigned(out_port);
      end if;
    end if;
  end process;
end neopixel_arch;
