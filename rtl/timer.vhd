library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
  generic (
    PULSE_DURATION_WIDTH : positive := 16
  );
  port (
    clk         : in std_logic;
    reset       : in std_logic;
    time_value  : in std_logic_vector(PULSE_DURATION_WIDTH - 1 downto 0);
    timer_start : in std_logic;
    timer_end   : out std_logic
  );
end entity;

architecture Behavioral of timer is
  -- segnali interni
  signal count    : unsigned(PULSE_DURATION_WIDTH - 1 downto 0);
  signal counting : std_logic;

begin

  p_timer : process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        count    <= (others => '0');
        counting <= '0';
      else
        if timer_start = '1' then
          count <= unsigned(time_value);
          if unsigned(time_value) = 0 then
            counting <= '0'; -- Non c'è bisogno di contare, evita latch
          else
            counting <= '1'; -- Inizia a contare
          end if;
        elsif counting = '1' then
          -- Se stiamo contando e il contatore è 1, al prossimo colpo di clock sarà 0
          if count = 1 then
            count    <= (others => '0');
            counting <= '0'; -- Smetti di contare, timer_end sarà attivo
          elsif count > 0 then -- basterebbe >1, ma non si sa mai
            count <= count - 1;
          else -- count è 0, ma counting era 1. Resetta counting.
            counting <= '0';
          end if;
        end if;
        -- Se timer_start non è attivo e non stiamo contando, non fare nulla
      end if;
    end if;
  end process;

  timer_end <= '1' when (timer_start = '1' and unsigned(time_value) = 0) or
    (counting = '1' and count = 1)
    else
    '0';

end architecture;