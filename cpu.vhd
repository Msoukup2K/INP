library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity cpu is
port (
		CLK   : in std_logic;  -- hodinovy signal
		RESET : in std_logic;  -- asynchronni reset procesoru
		EN    : in std_logic;  -- povoleni cinnosti procesoru

		-- stavove signaly
		READY : out std_logic; -- inicializace ptr
		DONE  : out std_logic; -- po vykonání instrukcí
		
		-- synchronni pamet RAM
		DATA_ADDR  : out std_logic_vector(9 downto 0); -- adresa do pameti
		DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
		DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
		DATA_RDWR  : out std_logic;                    -- cteni (1) / zapis (0)
		DATA_EN    : out std_logic;                    -- povoleni cinnosti
		
		-- vstupni port
		IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
		IN_VLD    : in std_logic;                      -- data platna
		IN_REQ    : out std_logic;                     -- pozadavek na vstup data
		
		-- vystupni port
		OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
		OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
		OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
	);
end cpu;


architecture behavioral of cpu is

signal pc_data : std_logic_vector(12 downto 0);
signal pc_inc : std_logic;
signal pc_dec : std_logic;

signal ptr_data : std_logic_vector(12 downto 0);
signal ptr_inc : std_logic;
signal ptr_dec : std_logic;

signal test : std_logic;

type fsm_s is ( s_init, 
s_test, 
s_stop)

signal s_now : fsm_s := s_init;
signal s_next : fsm_s;
begin

	fsm: process(s_now)
		begin
			test <= '0'

			s_next <= s_test;

			case s_now is
				when s_init =>
					test <= '1'

					s_next <= s_stop;

				when s_stop;
					s_next <= s_stop;

				when others =>
					null;
			end case;

		end process;

end behavioral;
