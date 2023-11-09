-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2023 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
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
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
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

  signal cnt_data : std_logic_vector(7 downto 0);
  signal cnt_inc : std_logic;
  signal cnt_dec : std_logic;

  signal mux1 : std_logic;
  signal mux2 : std_logic_vector(1 downto 0);
    
  type fsm_s is ( s_init, s_again, s_init2,
  s_fetch, s_decode,
  s_inc_data, s_inc_data2, s_inc_data3,
  s_dec_data, s_dec_data2, s_dec_data3,
  s_ptr_inc, s_ptr_dec,
  s_print, s_print2, s_print3,
  s_input, s_input2, s_input_write,
  s_while, s_while2, s_while3, s_while4, s_while5,
  s_while_end, s_while_end2, s_while_end3, s_while_end4, s_while_end5,
  s_break, s_break2,
  s_stop);
  
  signal s_now : fsm_s := s_init;
  signal s_next : fsm_s;

begin

 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --      - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --      - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly. 

 pc: process(RESET, CLK) 
  begin
      if( RESET='1') then
        pc_data <= "0000000000000";
      elsif (CLK'event) and (CLK='1') then
        if (pc_inc = '1') then
          pc_data <= pc_data+1; --inc
        elsif (pc_dec = '1') then
          pc_data <= ptr_data-1; --dec
        end if;
      end if;
  end process pc;

ptr: process(RESET, CLK) --DATA
begin
  if (RESET='1') then
    ptr_data <= "0000000000000" ;
  elsif (CLK'event and CLK='1') then
      if (ptr_inc = '1') then
        ptr_data <= ptr_data + 1;
      elsif (ptr_dec = '1') then
        ptr_data <= ptr_data - 1;
      end if;
  end if;
end process ptr;

MUX: process(RESET, CLK)  --READ
begin
  case(mux1) is
    when '0' => 
    DATA_ADDR <= pc_data;
    when '1' => 
    DATA_ADDR <= ptr_data;
    when others => 
      null;
  end case;
end process;

MUXF: process(RESET, CLK) 
begin
  case(mux2) is
    when "00" => 
    DATA_WDATA <= IN_DATA;
    when "01" => 
    DATA_WDATA <= DATA_RDATA+1; --Inc wdata
    when "10" => 
    DATA_WDATA <= DATA_RDATA-1; --Dec wdata
    when others => 
      null;
  end case;
end process;

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

fsm_iterator: process (RESET, CLK)
begin
  if (RESET = '1') then
    s_now <= s_init;
  elsif (CLK'event) and (CLK = '1') then
    if (EN = '1') then
      s_now <= s_next;
    end if;		
  end if;
end process;

fsm: process(s_now)
  begin
    OUT_WE <= '0';
		IN_REQ <= '0';
		DATA_EN <= '1';
    DATA_RDWR <= '0';
    OUT_DATA <= DATA_RDATA;

    DONE <= '0';
		READY <= '0';

    ---CNT
		cnt_inc <= '0';
		cnt_dec <= '0';

    ---PC
		pc_inc <= '0';
		pc_dec <= '0';

    ---PTR
		ptr_inc <= '0';
		ptr_dec <= '0';

    ---MUX1/2
    mux1 <= '0';
    mux2 <= "00";

    s_next <= s_init;

    case s_now is
      when s_init =>
        mux1 <= '1';
        s_next <= s_init2;

      when s_init2 =>
        mux1 <= '1';
        if( DATA_RDATA = X"40") then
          READY <= '1';
          s_next <= s_decode;
        else
          ptr_inc <= '1';
          s_next <= s_init; 
        end if;
      when s_fetch =>
        mux1 <= '1';
        s_next <= s_decode;

      when s_decode =>
        READY <= '1';
        case DATA_RDATA is
          when X"40" => 
            DONE <= '1';
            mux1 <= '0';
            s_next <= s_stop;
          
          when X"3E" =>
            --inkrement ptr
            pc_inc <= '1';
            ptr_inc <= '1';
            s_next <= s_ptr_inc;
          
          when X"3C" => 
            --dekrement ptr
            ptr_dec <= '1';
            pc_dec <= '1';
            s_next <= s_ptr_dec;

          when X"2B" =>
            s_next <= s_inc_data;
            null;
          when X"2D" => 
            s_next <= s_dec_data;
            --dekrement data ig

          when X"5B" => 
            --aktualni hodnota je nulova, skoc za prikaz ] (dalsi case)
            s_next <= s_while;
           

          when X"5D" =>
            --hodnota nenulova skoc za [ jinak nasledujici znak
            mux1 <= '1';
            s_next <= s_while_end;
          
          when X"7E" => 
            s_next <= s_break;

          when X"2E" =>
            --vytiskni hodnotu aktualni bunky
            s_next <= s_print;


          when X"2C" =>
            --nacti hodnotu a uloz ji do aktualni bunky
            s_next <= s_input;

          when others =>
            s_next <= s_again;
        end case;

------------------------------------------------------------------
      when s_while =>
        pc_inc <= '1';
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        mux1 <= '1';
        s_next <= s_while2;
        

      when s_while2 =>
          if( DATA_RDATA = "00000000") then
            s_next <= s_while3;
          else
            s_next <= s_fetch;
          end if;

      when s_while3 => 
          if (DATA_RDATA = X"5D") then
            s_next <= s_fetch;
          else
            s_next <= s_while4;
          end if;

      when s_while4 =>
        pc_inc <= '1';
        s_next <= s_while3;

        
      when s_while_end =>
          s_next <= s_while_end2;


      when s_while_end2 =>
        if( DATA_RDATA /= "00000000") then
          s_next <= s_fetch;
        else
          s_next <= s_while_end3;
        end if;

      when s_while_end3 =>
        if( DATA_RDATA = X"5B") then
            s_next <= s_fetch;
          else
            pc_dec <= '1';
            s_next <= s_while_end;
          end if;

      when s_while_end4 =>
          s_next <= s_while_end2;

------------------------------------------------------------------
      when s_break =>
        s_next <= s_break2;

      when s_break2 =>
        mux1 <= '0';
        if( DATA_RDATA = X"5D") then
          s_next <= s_fetch;
        else
          pc_inc <= '1';
          s_next <= s_break;
        end if;


------------------------------------------------------------------
      when s_input => 
          IN_REQ <= '1';
          DATA_RDWR <= '0';
          mux1 <= '1';
          s_next <= s_input2;

      when s_input2 =>
          if ( IN_VLD = '1' ) then
            DATA_RDWR <= '1';
            mux1 <= '1';
            s_next <= s_input_write;
          else
            IN_REQ <= '1';
            mux1 <= '1';
            DATA_RDWR <= '0';
            s_next <= s_input;

          end if;

      when s_input_write =>
          mux1 <= '1';
          pc_inc <= '1';
          s_next <= s_fetch;

------------------------------------------------------------------
      when s_print =>
        if ( OUT_BUSY = '1' ) then
          mux1 <= '1';
          s_next <= s_print2;
        else
          mux1 <= '1';
          OUT_WE <= '1';
          OUT_DATA <= DATA_RDATA;
          s_next <= s_print3;
          pc_inc <= '1';
        end if;

      when s_print2 =>
          OUT_WE <= '0';
          s_next <= s_print;

      when s_print3 =>
          OUT_WE <= '1';
          OUT_DATA <= DATA_RDATA;
          s_next <= s_decode;

------------------------------------------------------------------
      when s_ptr_inc =>
        s_next <= s_fetch;

      when s_ptr_dec =>
        s_next <= s_fetch;

------------------------------------------------------------------
      when s_inc_data =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        mux1 <= '1';
        s_next <= s_inc_data2;

      when s_inc_data2 =>
        mux1 <= '1';
        mux2 <= "01";
        DATA_EN <= '1';
        DATA_RDWR <= '1';
        pc_inc <= '1';
        s_next <= s_inc_data3;

      when s_inc_data3 =>
        DATA_EN <= '1';
        DATA_RDWR <= '0';
        s_next <= s_fetch;

------------------------------------------------------------------
      when s_dec_data =>
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          mux1 <= '1';
          s_next <= s_dec_data2;
        
      when s_dec_data2 =>
          mux1 <= '1';
          mux2 <= "10";
          DATA_EN <= '1';
          DATA_RDWR <= '1';
          pc_inc <= '1';
          s_next <= s_dec_data3;

      when s_dec_data3 =>
          DATA_EN <= '1';
          DATA_RDWR <= '0';
          s_next <= s_fetch;

------------------------------------------------------------------

      when s_again =>
          --pc_inc <= '1';
          s_next <= s_fetch;

      when s_stop =>
        s_next <= s_stop;
      when others =>
        null;
    end case;
  end process;
 
end behavioral;