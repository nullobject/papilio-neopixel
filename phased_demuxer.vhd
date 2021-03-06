library ieee;

use ieee.std_logic_1164.all;

-- The phased demuxer converts two sequential data values of width n to one
-- data value of width 2n.
entity phased_demuxer is
  generic (
    DATA_WIDTH : natural := 8
  );

  port (
    clk  : in  std_logic;
    en   : in  std_logic;
    din  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    dout : out std_logic_vector(DATA_WIDTH*2-1 downto 0);
    rdy  : out std_logic
  );
end phased_demuxer;

architecture phased_demuxer_architecture of phased_demuxer is
  type data_type is array (0 to 1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal data : data_type;
begin
  process(clk, en, din, data)
    variable phase : std_logic;
  begin
    if rising_edge(clk) and en = '1' then
      -- Store the data value for the phase.
      if phase = '0' then
        data(0) <= din;
      else
        data(1) <= din;
      end if;

      -- Set the ready output to the phase.
      rdy <= phase;

      -- Invert the phase.
      phase := not phase;
    end if;
  end process;

  dout <= data(0) & data(1);
end phased_demuxer_architecture;
