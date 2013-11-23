library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dual_port_async_ram is
  generic(
    ADDR_WIDTH : natural := 8;
    DATA_WIDTH : natural := 8
  );
  port (
    clk    : in std_logic;
    we     : in std_logic;
    addr_a : in unsigned(ADDR_WIDTH-1 downto 0);
    addr_b : in unsigned(ADDR_WIDTH-1 downto 0);
    din_a  : in unsigned(DATA_WIDTH-1 downto 0);
    dout_a : out unsigned(DATA_WIDTH-1 downto 0);
    dout_b : out unsigned(DATA_WIDTH-1 downto 0)
  );
end dual_port_async_ram;

architecture dual_port_async_ram_arch of dual_port_async_ram is
  type ram_type is array (0 to 2**ADDR_WIDTH-1) of unsigned(DATA_WIDTH-1 downto 0);
  signal ram : ram_type;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        ram(to_integer(addr_a)) <= din_a;
      end if;
    end if;
  end process;

  dout_a <= ram(to_integer(addr_a));
  dout_b <= ram(to_integer(addr_b));
end dual_port_async_ram_arch;
