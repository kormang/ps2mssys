library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

-- Ova komponenta prihvata bitove preko serijske komunikacije i stavlja ih u registar da bi se bajt mogao citav procitati
-- Provjerava i parnost, i ako nije dobra postavice signal za gresku.
-- Kada primi podatak postavice signal da se moze procitati i drazati ga aktivnim dok ne pocne citati drugi podatak.

entity ps2kbcontroller is port (
	-- prema konektoru: --
	ps2_clk : in std_logic;
	ps2_dat : in std_logic;
	
	-- prema sistemu: --
	reset : in std_logic;
	kbdata : buffer std_logic_vector (7 downto 0) := "00000000"; -- ucitani podatak, bajt
	error_occured : out std_logic := '0'; -- signal za gresku
	data_ready : out std_logic := '0'  -- signal da se bajt moze procitati

);
end entity;


architecture behav of ps2kbcontroller is
 type state is (idle, shifting, parity, stop);
 signal cst : state := idle; -- trenutno stanje 
 signal enable_shift : std_logic := '0'; -- da li da pocne sa usiftavanjem, od drugog do 9 bita treba usiftavati ostali su kontrolne informacije
 signal shift_progress : std_logic_vector(6 downto 0) := "1000000"; -- neka vrsta brojaca
 signal parity_checked : std_logic;  -- signal iz komponente za provjeru parnosti
 --signal parity_received : std_logic;
 signal parity_ok : std_logic := '0'; -- pamti da li je parnost ispravna
 
 COMPONENT inshifter IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		enable		: IN STD_LOGIC ;
		shiftin		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END COMPONENT;
 
component parity_checker is port (
	input_vec : in std_logic_vector (7 downto 0);
	result : out std_logic
);
end component;
 
begin
	
	preg : inshifter port map ( 
		clock => ps2_clk,
		enable => enable_shift,
		shiftin => ps2_dat,
		q => kbdata
	);
		
	pcheck : parity_checker port map (
		input_vec => kbdata,
		result => parity_checked
	);
	
acceptkey:	process  (ps2_clk, reset)
	begin
		if reset = '0' then
		-- ovim signalima dodjeljujem vrijednosti u svakom stanju kako bi izbjegao ne definisane situacije i implicitne memorije
			data_ready <= '0';
			error_occured <= '0';
			enable_shift <= '0';
			parity_ok <= '0';
			cst <= idle;
			shift_progress <= "1000000";
		elsif falling_edge(ps2_clk) then
		
			case cst is
				when idle => -- u stanju je idle, treba preci u stanje shifting
					if ps2_dat <= '0' then -- ako je nizak nivo, tj. generisan shifting signal
						enable_shift <= '1'; -- ukljucujem usiftavanje
						cst <= shifting;
					else
						enable_shift <= '0';
						cst <= idle;
					end if;
					data_ready <= '0';
					error_occured <= '0';
					parity_ok <= '0';
					shift_progress <= "1000000";
					
				when shifting =>
					shift_progress <= std_logic_vector(shift_right(unsigned(shift_progress),1)); -- ova promjena ce se desiti u sledecem taktu
					if shift_progress = "0000000" then -- ako je jedinica sa sedmog bita izsiftana skroz desno onda se usiftava i poslednji bit pa treba prekinuti
						enable_shift <= '0';
						cst <= parity;
					else
						enable_shift <= '1';
						cst <= shifting;
					end if;
					data_ready <= '0';
					error_occured <= '0';
					parity_ok <= '0';
			
				when parity =>
					cst <= stop; -- sad treba provjeriti parnost, pa onda ocekivati stop
					-- provjera , da li se parity bit slaze:
					if ps2_dat = not parity_checked then -- greskom sam napravio da daje invertovanu parnost
						parity_ok <= '1';
					else
						parity_ok <= '0';
					end if;
					data_ready <= '0';
					error_occured <= '0';
					shift_progress <= "1000000";
					enable_shift <= '0';
					
				when stop =>
				-- ovde citam stop bit: --
				-- ako je procitan stop bit i ako je parnost dobra treba dati signal da se moze bajt procitati
					if parity_ok = '1' and ps2_dat = '1' then
						data_ready <= '1';
						error_occured <= '0';
					else
						error_occured <= '1';
						data_ready <= '0';
					end if;
					cst <= idle;
					parity_ok <= '0';
					shift_progress <= "1000000";
					enable_shift <= '0';
					
				end case;
		end if;
	end process acceptkey;

end architecture behav;