library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity RAM is
  generic (
    DATA_WIDTH : positive := 64; -- Larghezza della parola di dati
    ADDR_WIDTH : positive := 8 -- Larghezza dell'indirizzo
  );
  port (
    clk   : in std_logic;
    reset : in std_logic;
    -- Scrittura
    en_w   : in std_logic;
    addr_w : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    data_w : in std_logic_vector(DATA_WIDTH - 1 downto 0);
    -- Lettura
    addr_r : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
    data_r : out std_logic_vector(DATA_WIDTH - 1 downto 0)
    -- potrei aggiungere enable per la lettura per risparmiare potenza, ma non lo faccio per evitare la complessità aggiuntiva
  );
end entity;

architecture behavioral of RAM is
  -- creo le allocazioni per la memoria RAM
  type RAM_t is array (natural range 0 to 2 ** ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  -- segnale per la memoria RAM
  signal ram_memory : RAM_t;
begin

  -- process per la scrittura
  p_write : process (clk)
  begin
    if rising_edge(clk) then
      if en_w = '1' then
        --converto prima in unsigned e poi in integer per accedere all'array
        ram_memory(to_integer(unsigned(addr_w))) <= data_w;
      end if;
    end if;
  end process;

  -- process per la lettura
  p_read : process (clk) 
  begin
    if rising_edge(clk) then
      if reset = '1' then
        data_r <= (others => '0');
      else
        data_r <= ram_memory(to_integer(unsigned(addr_r)));
      end if;
    end if;
  end process;
end architecture;