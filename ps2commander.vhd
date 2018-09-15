library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--	Ovaj entitet ce poslati zadanu komandu uredjaju. Procedura za slanje komande je sledeca:
--		1. Obezebjediti da je na "reset" visok nivo.
--		2. Postaviti kod komande na magistralu "command" i drzati je tu bar dok je "send_command" na visokom nivou.
--		3. Postaviti visok logicki novi na "send_command", u periodu od jedenog takta ili dok se istekne period od 100 mikrosekudni.
--		4. Nakon sto istekne period od 100 mikrosekundi postaviti visok nivo na "time_interval_over", i nizak nivo (ako vec nije) na "send_command".
--		5. Cekati visok nivo na "command_sended" ili "error_occured", sto znaci da je komanda poslana ili da se desila greska, respektivno.
		
--		Na ps2_clk, i ps2_dat potrebno je diktno povezati odgovarajuce PS/2 pinove.
--		Na sys_clk potreno je dovesti odgovarajuci takt, od barem 50 kHz. Ja korisitim od 27 MHz,
--		jer mi je potreban za VGA kontroler, pa ga korisite svi entiteti.

entity ps2commander is port (
	-- prema konektoru: --
	ps2_clk : inout std_logic;
	ps2_dat : inout std_logic;
	-- prema sistemu: --
	command_sended : out std_logic := '0';
	
	
	-- dovde : --
	reset : in std_logic;
	sys_clk : in std_logic;
	command : in std_logic_vector (7 downto 0);
	time_interval_over : in std_logic;
	error_occured : out std_logic := '0';
	send_command : in std_logic
	
);
end entity;


architecture behav of ps2commander is
 
 type state_t is (init, pulldown, pull_data_down, release_clock, shifting, stop_shift, wait_ack_bit, wait_final_release, success, error );
 signal cs : state_t := init; --trenutno stanje
 signal enable_shift : std_logic := '0';
 signal bitout : std_logic;
 signal data_output : std_logic := '1';
 signal shift_out : std_logic;
 signal shift_progress : std_logic_vector (9 downto 0) := "1000000000";
 signal old_tio, old_send_command : std_logic := '0';
 
COMPONENT outshifter IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		enable		: IN STD_LOGIC ;
		load		: IN STD_LOGIC ;
		shiftout		: OUT STD_LOGIC 
	);
END COMPONENT;

component one2Z is port (
	input : in std_logic;
	output : out std_logic
);
end component;

begin

	shifter : outshifter port map(
		clock => ps2_clk,
		data => command,
		enable => enable_shift,
		load => send_command,
		shiftout => shift_out
	);
	one_to_z : one2Z port map(
		input => bitout,
		output => ps2_dat
	);

	bitout <= shift_out when enable_shift = '1' else data_output;
	
	ctrl: process (reset, sys_clk)
	begin
		if reset = '0' then
			cs <= init;
			enable_shift <= '0';
			error_occured <= '0';
			command_sended <= '0';
			ps2_clk <= 'Z';
			data_output <= '1';
				
		elsif rising_edge(sys_clk) then
			case cs is
				when init =>
					enable_shift <= '0';
					error_occured <= '0';
					command_sended <= '0';
					ps2_clk <= 'Z';
					data_output <= '1';
					if send_command = '1' and old_send_command = '0' then -- ako je inicirano slanje
						cs <= pulldown; -- treba povuci takt na nulu
					else
						cs <= init; -- u suprotnom ostati u ovom stanju, mirovanja
					end if;
					
				when pulldown =>
					ps2_clk <= '0'; -- povlacim takt na nulu
					data_output <= '1';
					enable_shift <= '0';
					error_occured <= '0';
					command_sended <= '0';
					if time_interval_over = '1' and old_tio = '0' then -- cekam dok ostekne period za koji moram drzati takt na nuli
						cs <= pull_data_down;
					else
						cs <= pulldown;
					end if;
				
				when pull_data_down => -- malo prije nego sto otpustim takt, moram povuci podatke na nulu
					ps2_clk <= '0';
					data_output <= '0';
					enable_shift <= '0';
					error_occured <= '0';
					command_sended <= '0';
					cs <= release_clock;
				
				when release_clock => -- otpustam takt, sad ce uredjaj da ga pocne generisati
						ps2_clk <= 'Z';
						data_output <= '0';
						enable_shift <= '1';
						error_occured <= '0';
						command_sended <= '0';
						cs <= shifting;
				
				when shifting =>
					ps2_clk <= 'Z';
					data_output <= '0';
					enable_shift <= '1';
					error_occured <= '0';
					command_sended <= '0';
					if shift_progress = "0000000000" then -- ako je jedincica izsiftana skroz desno znaci da je citav bajt poslan (izsiftan)
						cs <= stop_shift;
					else
						cs <= shifting;
					end if;
			
				when stop_shift =>
					ps2_clk <= 'Z'; -- prepustam uradjaju da postavi ack bit
					data_output <= '1';
					enable_shift <= '0';
					error_occured <= '0';
					command_sended <= '0';
					cs <= wait_ack_bit;
				
				when wait_ack_bit => -- vrtim se u ovom stanju dok uredjaj ne postavi ACK-bit, 
											-- a to ce mi javiti ovaj proces ispod tako sto ce resetovati shift_progress
					ps2_clk <= 'Z';
					data_output <= '1';
					enable_shift <= '0';
					error_occured <= '0';
					command_sended <= '0';
					if shift_progress = "1000000000" then
						cs <= wait_final_release; -- primljen je ack bit
					elsif shift_progress = "1111111111" then
						cs <= error; -- sve jedinice u shift_progress znace gresku
					else
						cs <= wait_ack_bit;
					end if;
				
				when wait_final_release => -- ovde cekam dok uredjaj ne pusti takt i podatke na visok novo, onda je kraj
					ps2_clk <= 'Z';
					data_output <= '1';
					enable_shift <= '0';
					error_occured <= '0';
					command_sended <= '0';
					if ps2_clk = '1' and ps2_dat = '1' then  
						cs <= success;
					else
						cs <= wait_final_release;
					end if;
				
				when success => -- treba postaviti signal za uspjesno poslanu komandu
						ps2_clk <= 'Z';
						data_output <= '1';
						enable_shift <= '0';
						error_occured <= '0';
						command_sended <= '1';
						cs <= init;
						
				when error =>
						ps2_clk <= 'Z';
						data_output <= '1';
						enable_shift <= '0';
						error_occured <= '1';
						command_sended <= '0';
						cs <= init; -- poslije greske najbolje mi je da se vratim u init, samo sam u jednom takt periodu stavio error_occured = '1'
					
			end case;
			old_tio <= time_interval_over;
			old_send_command <= send_command;
		end if;
	end process;
	
	-- aktivan na opadajucu ivicu uredjajovog takta - ovaj proces ce izbrojati 8 bita koje treba poslati
	-- i to tako sto ce siftati jedinicu dok je ne izsifta skroz lijevo da ostanu samo nule. To znaci da je sve izsiftano/poslano uredjaju.
	slanje: process (ps2_clk)
	begin
		if falling_edge(ps2_clk) then
			if enable_shift = '1' then		
				shift_progress <= std_logic_vector(shift_right(unsigned(shift_progress),1));
			elsif cs = wait_ack_bit then
				if ps2_dat = '0' then
					shift_progress <= "1000000000"; -- resetuj vektor kao znak da je primljen ack bit
				else
					shift_progress <= "1111111111"; -- znak da je doslo do greske
				end if;
			else
				shift_progress <= "1000000000";
			end if;
		end if;
	end process;
	
end architecture;
