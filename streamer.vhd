library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity streamer is port (
	kb_interrupt, controller_error : in std_logic;
	old_kb_interrupt, old_controller_error : in std_logic;
	kbdata : in std_logic_vector (7 downto 0);
	enable : in std_logic;
	sys_clk, reset : in std_logic;
	
	interrupt : out std_logic := '0';
	left_click, right_click, middle_click : out std_logic := '0';
	dx, dy : out std_logic_vector (8 downto 0)
	
);
end streamer;


architecture sbeh of streamer is 

type state_t is (init, read_byte1, read_byte2, read_byte3, ignore2, ignore3, commit, set_interrupt);
attribute syn_encoding : string;
attribute syn_encoding of state_t: type is "sequential"; -- ili "one-hot", "gray", "johnson"


signal stanje : state_t := init;
signal bb : std_logic_vector (1 downto 0) := "00";
signal byte1, byte2, byte3 : std_logic_vector (7 downto 0) := "00000000";

begin
	
	glavonja: process (sys_clk, reset)
	variable temp : signed(10 downto 0);
	begin
		if reset = '0' then
			stanje <= init;
			byte1 <= "00000000";
			byte2 <= "00000000";
			byte3 <= "00000000";
			right_click <= '0';
			left_click <= '0';
			middle_click <= '0';
			interrupt <= '0';
			
		elsif rising_edge(sys_clk) then
			if enable = '1' then
				case stanje is
					when init =>
						stanje <= read_byte1;
						interrupt <= '0';
						
					when read_byte1 =>
						interrupt <= '0';
						if old_kb_interrupt = '0' and kb_interrupt = '1' then
								byte1 <= kbdata;
								stanje <= read_byte2;
						elsif old_controller_error = '0' and controller_error = '1' then
								stanje <= ignore2;
						else
								stanje <= read_byte1;
						end if;
				
				when read_byte2 =>
						interrupt <= '0';
						if old_kb_interrupt = '0' and kb_interrupt = '1' then
								byte2 <= kbdata;
								stanje <= read_byte3;
						elsif old_controller_error = '0' and controller_error = '1' then
								stanje <= ignore3;
						else
								stanje <= read_byte2;
						end if;
						
				when read_byte3 =>
					interrupt <= '0';
						if old_kb_interrupt = '0' and kb_interrupt = '1' then
								byte3 <= kbdata;
								stanje <= commit;
						elsif old_controller_error = '0' and controller_error = '1' then
								stanje <= read_byte1;
						else
								stanje <= read_byte3;
						end if;
						
				when ignore2 =>
						interrupt <= '0';
						if old_kb_interrupt = '0' and kb_interrupt = '1' then
								stanje <= ignore3;
						elsif old_controller_error = '0' and controller_error = '1' then
								stanje <= ignore3;
						else
								stanje <= ignore2;
						end if;
						
				when ignore3 =>
					interrupt <= '0';
						if old_kb_interrupt = '0' and kb_interrupt = '1' then
								stanje <= read_byte1;
						elsif old_controller_error = '0' and controller_error = '1' then
								stanje <= read_byte1;
						else
								stanje <= ignore3;
						end if;
				
				when commit =>
					left_click <= byte1(0);
					right_click <= byte1(1);
					middle_click <= byte1(2);
					
					if byte1(6) = '0' then
						dx <= byte1(4) & byte2;
					else
						-- ako je doslo do overflowa postavicu na najvecu ili najmanju vrijednost zavisno od znaka
						if byte1(4) = '0' then
							dx <= "011111111";
						else
							dx <= "100000000";
						end if;
					end if;
					
					if byte1(7) = '0' then
						dy <= byte1(5) & byte3;
					else
						-- ako je doslo do overflowa postavicu na najvecu ili najmanju vrijednost zavisno od znaka
						if byte1(5) = '0' then
							dy <= "011111111";
						else
							dy <= "100000000";
						end if;
					end if;
					
					interrupt <= '0';
					
					stanje <= set_interrupt;
					
				when set_interrupt =>
						interrupt <= '1';
						stanje <= read_byte1;
						
				end case;
			else
				stanje <= init;
				interrupt <= '0';
			end if;

		end if;
	
	end process;
	
end architecture;










