-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Martin Soukup <xsouku15@stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
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


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

signal pc_data : std_logic_vector(12 downto 0);
signal pc_inc : std_logic;
signal pc_dec : std_logic;

signal ptr_data : std_logic_vector(12 downto 0);
signal ptr_inc : std_logic;
signal ptr_dec : std_logic;

signal mux0 : std_logic;
signal mux1 : std_logic_vector(1 downto 0);

signal cnt_data : std_logic_vector(7 downto 0);
signal cnt_inc : std_logic;
signal cnt_dec : std_logic;

signal test : std_logic;
signal test2 : std_logic;

type fsm_state is (state_while_end33,state_while_end4,state_while_end3,state_while_end2,
state_while_end,state_while33,state_while4,state_while3,state_while2,state_while,
state_read_w, state_read_r2,state_read_r,state_print3,state_print2, state_print,state_jump,state_inc_data,state_inc_data_w,state_dec_data,
state_dec_data_w,state_dec_ptr, state_init, state_fetch, 
state_inc_ptr,state_decode, state_stop);

signal state_present : fsm_state := state_init;
signal state_next : fsm_state;
begin

pc: process(RESET, CLK) --INSTRUKCE
	begin
		if (RESET='1') then
			pc_data <= "0000000000000";
		elsif (CLK'event) and (CLK='1') then
			if (pc_inc = '1') then
				pc_data <= pc_data+1;
			elsif (pc_dec = '1') then
				pc_data <= pc_data-1;
			end if;
		end if;
	end process pc;

----TAKŽE VŠECHNO IGNORUJU A JAKMILE JE READY JEDNA TAK JE ZAČNU VYKONÁVAT TEPRVE EZ

ptr: process(RESET, CLK) --DATA
	begin
		if (RESET='1') then
			ptr_data <= "1000000000000" ;
		elsif (CLK'event) and (CLK='1') then
			if (ptr_inc = '1') then
				ptr_data <= ptr_data+1;
			elsif (ptr_dec = '1') then
				ptr_data <= ptr_data-1;
			end if;
		end if;
	end process ptr;

cnt: process(RESET, CLK)
	begin
	if (RESET='1') then
		cnt_data <= (others => '0');
	elsif (CLK'event) and (CLK='1') then
		if (cnt_inc = '1') then
			cnt_data <= cnt_data+1;
		elsif (cnt_dec = '1') then
			cnt_data <= cnt_data-1;
		end if;
	end if;
end process cnt;

MUX: process(RESET, CLK)  --READ
	begin
	case(mux0) is
		when '0' => 
		DATA_ADDR <= pc_data;
		when '1' => 
		DATA_ADDR <= ptr_data;
		when others => NULL;
	end case;
	end process;

MUXF: process(RESET, CLK) 
	begin
	case(mux1) is
		when "00" => 
		DATA_WDATA <= IN_DATA;
		when "01" => 
		DATA_WDATA <= DATA_RDATA+1; --Inc wdata
		when "10" => 
		DATA_WDATA <= DATA_RDATA-1; --Dec wdata
		when others => NULL;
	end case;
end process;

fsm_iterator: process (RESET, CLK)
	begin
		if (RESET = '1') then
			state_present <= state_init;
		elsif (CLK'event) and (CLK = '1') then
			if (EN = '1') then
				state_present <= state_next;
			end if;		
		end if;
	end process;

fsm: process(state_present)
	begin
		OUT_WE <= '0';
		IN_REQ <= '0';
		DATA_EN <= '0';
		

		cnt_inc <= '0';
		cnt_dec <= '0';

		pc_inc <= '0';
		pc_dec <= '0';

		ptr_inc <= '0';
		ptr_dec <= '0';

		state_next <= state_init;

		case state_present is
			when state_init =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mux0 <= '0';
				state_next <= state_fetch;

			when state_fetch =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mux0 <= '0';
				state_next <= state_decode;

			
			when state_decode =>
				case DATA_RDATA is
					when X"2B" =>
						state_next <= state_inc_data;

					when X"2D" =>
						state_next <= state_dec_data;

					when X"2E" =>
						DATA_EN <= '1';
						OUT_WE <= '0';
						mux0 <= '1';
						state_next <= state_print;

					when X"2C" =>
						DATA_EN <= '1';
						DATA_RDWR <= '0';
						state_next <= state_read_r;

					when X"3E" =>
						state_next <= state_inc_ptr;
					
					when X"3C" =>
						state_next <= state_dec_ptr;

					when X"5B" =>
						state_next <= state_while;
					
					when X"5D" =>
						state_next <= state_while_end;

					when X"28" =>
						null;
					
					when X"29" =>
						null;
					
					when X"00" =>
						state_next <= state_stop;

					when others =>
						state_next <= state_jump;

				end case;

			when state_while_end => 
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux0 <= '1';
					state_next <= state_while_end2;
			
			when state_while_end2 =>
					if DATA_RDATA = "00000000" then
						pc_inc <= '1';
						state_next <= state_init;
					else
						state_next <= state_while_end33;
						pc_dec <= '1';
						cnt_inc <= '1';
						mux0 <= '0';
					end if;

			when state_while_end33 =>
						DATA_EN <= '1';
						state_next <= state_while_end3;
				
			when state_while_end3 =>
					if cnt_data = "00000000" then
						state_next <= state_init;
					else
						mux0 <= '0';
						if DATA_RDATA = X"5B" then
							cnt_dec <= '1';
						elsif DATA_RDATA = X"5D" then
							cnt_inc <= '1';
						end if;
						state_next <= state_while_end4;
					end if;
				
			when state_while_end4 =>
					if cnt_data = "00000000" then
						pc_inc <= '1';
					else
						pc_dec <= '1';
					end if;
					state_next <= state_while_end33;
						

			when state_while =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux0 <= '1';
					pc_inc <= '1';
					state_next <= state_while2;
			
			when state_while2 =>
					if( DATA_RDATA = "00000000") then
						state_next <= state_init;
					else
						cnt_inc <= '1';
						DATA_EN <= '1';
						mux0 <= '0';
						state_next <= state_while33;
					end if;

			when state_while33 =>
				DATA_EN <= '1';
					state_next <= state_while3;

			when state_while3 =>
					if( cnt_data = "00000000") then
						state_next <= state_init;
					else
						mux0 <= '0';
						if DATA_RDATA = X"5B" then
							cnt_inc <= '1';
						elsif DATA_RDATA = X"5D" then
							cnt_dec <= '1';
						end if;
						pc_inc <= '1';
						DATA_EN <= '1';
						state_next <= state_while33;
					end if;
	

			when state_read_r =>
					IN_REQ <= '1';
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux0 <= '0';
					mux1 <= "00";
					state_next <= state_read_r2;

			when state_read_r2 =>
					if IN_VLD = '1' then
						DATA_EN <= '1';
						DATA_RDWR <= '1';
						mux0 <= '1';
						mux1 <= "00";
						state_next <= state_read_w;
					else
						IN_REQ <= '1';
						DATA_EN <= '1';
						mux0 <= '1';
						mux1 <= "00";
						DATA_RDWR <= '0';
						state_next <= state_read_r;
					end if;

			when state_read_w =>
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					mux0 <= '1';
					mux1 <= "00";
					pc_inc <= '1';
					state_next <= state_init;

			when state_print =>
					DATA_EN <= '1';
					OUT_WE <= '0';
					mux0 <= '1';
					test <= '1';
					state_next <= state_print2;
					

			when state_print2 =>
					if OUT_BUSY = '0' then
						OUT_WE <= '1';
						mux0 <= '1';
						pc_inc <= '1';
						OUT_DATA <= DATA_RDATA;
						test <= '0';
						state_next <= state_init;
					else
						state_next <= state_print;
						pc_inc <= '0';
					end if;
					
			when state_inc_data =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux0 <= '1';
					state_next <= state_inc_data_w;

			when state_inc_data_w =>
					mux1 <= "01";
					mux0 <= '1';
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					pc_inc <= '1';
					state_next <= state_init;

			when state_dec_data => --zpracovani
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux0 <= '1';
					state_next <= state_dec_data_w;

			when state_dec_data_w =>
					mux1 <= "10"; --dec
					mux0 <= '1';
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					pc_inc <= '1';
					state_next <= state_init;

			when state_dec_ptr =>
					ptr_dec <= '1';
					pc_inc <= '1';
					state_next <= state_init;

			when state_inc_ptr =>
					ptr_inc <= '1';
					pc_inc <= '1';
					state_next <= state_init;

			when state_jump =>
					pc_inc <= '1';
					state_next <= state_init;
			
			when state_stop =>
					state_next <= state_stop;

			when others =>
					null;

		end case;
	end process;
end behavioral;

