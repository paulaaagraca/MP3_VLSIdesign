----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Paula Graca
-- 
-- Create Date:    13:58:41 07/10/2019 
-- Design Name: 
-- Module Name:    monitorfsm - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.all;
use work.system_constants_pkg.all;


entity monitorfsm is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           enable_mon : in  STD_LOGIC;
           file_size : in  STD_LOGIC_vector (31 downto 0); -- 4 bytes
           busy : in  STD_LOGIC;
           dbuf_almost_full : in  STD_LOGIC;
	   busov: in STD_LOGIC;
           gnt : in  STD_LOGIC;
	   dec_status : in std_logic;
	   sbuf_full : in std_logic;
	   forward : in std_logic;
	   backward : in std_logic;
	   forward_lcd : out std_logic;
	   backward_lcd : out std_logic;
	   percent_num : out STD_LOGIC_VECTOR(31 downto 0);
           req : out  STD_LOGIC;
           busiv : out  STD_LOGIC;
           busi : out  STD_LOGIC_VECTOR (7 downto 0);
           ctrl : out  STD_LOGIC;
	   dbuf_wr : out STD_LOGIC;
	   playfile_end : out STD_LOGIC
	   );
end monitorfsm;

architecture Behavioral of monitorfsm is

type state is (IDLE, DBUF_STATUS, WAIT_GNT, SENT_PARAM, INTERVAL, SENT_CMD, FIO_STATUS);
signal next_state : state := IDLE;
signal aux_filend : std_logic := '0';
signal request_data : STD_LOGIC_VECTOR (7 downto 0) ;
signal total_counter : unsigned(32 downto 0) := x"00000000" & '0'; -- max 
signal cycle_counter : unsigned(32 downto 0) := x"00000000" & '0'; -- max 
signal dword_size : unsigned (32 downto 0) := "000000000000000000000000000000100";
signal forward_cmd : std_logic := '0';
signal backward_cmd : std_logic := '0';
signal read_cmd : std_logic := '0';

begin

playfile_end <= aux_filend;
percent_num <= std_logic_vector(total_counter(31 downto 0));

monitor_control : process (clk, reset)
begin

		if reset = reset_state then
			next_state <= IDLE;
			req <= '0';
			busiv <= '0';
			busi <= x"00";
			dbuf_wr <= '0';
			cycle_counter <= x"00000000" & '0'; 
			
		elsif clk'event AND clk = clk_polarity then
			
			if enable_mon = '0' OR dec_status = '1' then
				next_state <= IDLE;
			else 
				next_state <= next_state;
			end if;	
			
			-------------------- MONITOR FSM --------------------------
			case next_state is
				when IDLE =>
									-- A1
									if enable_mon = '1' then
										next_state <= DBUF_STATUS;
										req <= '0';
										busiv <= '0';
										dbuf_wr <= '0'; -- cannot write
										forward_lcd <= '0';
										backward_lcd <= '0';
										
									-- A2
									else
										next_state <= IDLE;
										req <= '0';
										busiv <= '0';
										dbuf_wr <= '0'; -- cannot write
										aux_filend <= '0';		
										cycle_counter <= x"00000000" & '0';										
										forward_lcd <= '0';
										backward_lcd <= '0';
									end if;
									
				when DBUF_STATUS => 
									
									-- A3
									if dbuf_almost_full = '0' AND aux_filend = '0' AND sbuf_full = '0' then
										next_state <= WAIT_GNT;
										req <= '1';
										busiv <= '0'; -- cannot have a valid busi
										dbuf_wr <= '0'; -- cannot write
										
									-- A4
									elsif enable_mon = '0' OR aux_filend = '1' then
										next_state <= IDLE;
										req <= '0';
										busiv <= '0';
										dbuf_wr <= '0'; -- cannot write

									-- A5
									else -- enable_mon = '1' OR dbuf_almost_full = ''
										next_state <= DBUF_STATUS;
										req <= '0';
										busiv <= '0';
										dbuf_wr <= '0'; -- cannot write

									end if;
									
				when WAIT_GNT =>
									
									-- A6
									if busy = '0' AND gnt = '1' AND dec_status = '0' then
										next_state <= SENT_PARAM;		
										req <= '1';
										ctrl <= '0';
										busiv <= '1';
										busi <= request_data;
										dbuf_wr <= '0'; -- cannot write		
									
									-- A7
									else 
										next_state <= WAIT_GNT;
										req <= '1';
										busiv <= '0'; -- cannot have a valid busi
										dbuf_wr <= '0'; -- cannot write
										
									end if;
									
				when SENT_PARAM => 
				
									-- A8
									if busy = '0' AND gnt = '1' then
										next_state <= INTERVAL;
										req <= '1';
										busiv <= '0';

									-- A9
									else
										next_state <= SENT_PARAM;
										req <= '1';
										busiv <= '0'; ------------------------------------- changed busiv 16/07
										busi <= request_data;
										dbuf_wr <= '0'; -- cannot write				
									end if;
									
				when INTERVAL => 
				
									-- A10
									if busy = '0' AND gnt = '1' then
										if read_cmd = '1' then
											next_state <= SENT_CMD;
											req <= '1';
											ctrl <= '1';
											busiv <= '1';
											busi <= x"02"; --READ
											dbuf_wr <= '0';
											read_cmd <= '0';
										elsif forward_cmd = '1' then
											next_state <= IDLE;
											forward_lcd <= '1';
											req <= '1';
											ctrl <= '1';
											busiv <= '1';
											busi <= x"04"; --FFSEEK
											dbuf_wr <= '0';
											forward_cmd <= '0';
										elsif backward_cmd = '1' then
											next_state <= IDLE;
											backward_lcd <= '1';
											req <= '1';
											ctrl <= '1';
											busiv <= '1';
											busi <= x"05"; --FFSEEK
											dbuf_wr <= '0';
											backward_cmd <= '0';
										else 
											busiv <= '0';
										end if;
									-- A11
									else
										next_state <= INTERVAL;
										req <= '1';
										busiv <= '0';
									end if;
									
				when SENT_CMD =>
									-- A12
									if cycle_counter >= ((unsigned(request_data)+1)*4) then
										next_state <= IDLE;
										req <= '0';
										busiv <= '0';
										dbuf_wr <= '0'; -- cannot write
										total_counter <= total_counter + cycle_counter; -- update global counter
										cycle_counter <= x"00000000" & '0'; -- reset cycle counter

									-- A14
									elsif busov = '1' then	
										next_state <= FIO_STATUS;
										dbuf_wr <= '1';
										busiv <= '0';
										
									else
										next_state <= SENT_CMD;
										req <= '0';
										busiv <= '0'; -------------------------------------changed busiv 16/07
										dbuf_wr <= '0';
									
									end if;
									
				when FIO_STATUS =>
									
									-- A15
									if busy = '1' AND busov = '0' then
										next_state <= SENT_CMD;
										busiv <= '0';
										dbuf_wr <= '0';			
										cycle_counter <= cycle_counter + dword_size;
										
									-- A17
									else 
										next_state <= FIO_STATUS;
										cycle_counter<= cycle_counter + dword_size;
										dbuf_wr <= '1';
										busiv <= '0';
									end if;
									
				when others => 
									next_state <= IDLE;	
				end case;
		
			-------------------- Check end of file --------------------------
			if total_counter >= unsigned(file_size) then
				aux_filend <= '1';
				total_counter <= x"00000000" & '0';
			else
				aux_filend <= '0';
			end if;
		
			-------------------- FORWARD/BACKWARD LOGIC --------------------------
			if forward = '1' then
				request_data <= "00100000"; 	-- 64 KDWORDS : FFSEEK
				forward_cmd <= '1';
				read_cmd <= '0';
				next_state <= DBUF_STATUS;
			
			elsif backward = '1' then
				request_data <= "01010000"; 	-- 96 KDWORDS : BFSEEK
				backward_cmd <= '1';
				read_cmd <= '0';
				next_state <= DBUF_STATUS;
			
			elsif forward_cmd = '0' AND backward_cmd = '0' then 
				request_data <= x"01"; 	-- 16 dwords : READ
				read_cmd <= '1';
				
			end if;
		end if;
end process;
	
end Behavioral;
