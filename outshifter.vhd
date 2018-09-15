LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Ova koponenta radi. Mozda na malo cudan nacin ali radi. Stvar je u tome da sam morao smisliti neki nacin da
-- zaobicem ogranicenja Cyclone II kola koje ne moze imati registre koji se asinhrono pune ulaznim podacima.

ENTITY outshifter IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		enable		: IN STD_LOGIC ;
		load		: IN STD_LOGIC ;
		shiftout		: OUT STD_LOGIC := '0' 
	);
END outshifter;

architecture syn of outshifter is

signal storage : std_logic_vector (9 downto 0) := "1100000000";
signal bit_pointer : std_logic_vector (9 downto 0) := "0000000001";
signal result : std_logic;

begin


result <=  '0' when (storage and bit_pointer) = "0000000000" else '1';

load_process: process (load)
begin
	if rising_edge(load) then
			storage(7 downto 0) <= data;
			storage(8) <= not (((data(0) xor data(1)) xor (data(2) xor data(3))) xor ( (data(4) xor data(5)) xor (data(6) xor data(7)) ));
			storage(9) <= '1';
	end if;
end process;

shift_out_process: process (clock, load)
begin
	if load = '1' then
			shiftout <= '0'; -- ovo je mozda malo cudno odradjeno, ali treba mi ovde nula da bi nakon reseta i ukljucivanja enable_shift
								-- linija podataka ostala na nula, tj. da bi start bit ostao.
			bit_pointer <= "0000000001";
	elsif falling_edge(clock) then
		if enable = '1' then
			shiftout <= result;
			bit_pointer <= std_logic_vector(shift_left(unsigned(bit_pointer),1));
		else
			bit_pointer <= bit_pointer;
		end if;
	end if;
end process;

end architecture;












--LIBRARY ieee;
--USE ieee.std_logic_1164.all;
--
--
--ENTITY outshifter IS
--	PORT
--	(
--		parity : out std_logic;
--		storage_out : out std_logic_vector(7 downto 0);
--		clock		: IN STD_LOGIC ;
--		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
--		enable		: IN STD_LOGIC ;
--		load		: IN STD_LOGIC ;
--		shiftout		: OUT STD_LOGIC := '0' 
--	);
--END outshifter;
--
--architecture syn of outshifter is
--
--signal storage : std_logic_vector (9 downto 0) := "1100000000";
--
--begin
--
--
--parity <= storage(8);
--storage_out <= storage(7 downto 0);
--
--shift_out_process: process (clock, load)
--begin
--	if load = '1' then
--		storage(7 downto 0) <= data;
--		storage(8) <= not (((data(0) xor data(1)) xor (data(2) xor data(3))) xor ( (data(4) xor data(5)) xor (data(6) xor data(7)) ));
--		storage(9) <= '1';
--		shiftout <= '0'; -- ovo je mozda malo cudno odradjeno, ali treba mi ovde nula da bi nakon reseta i ukljucivanja enable_shift
--							-- linija podataka ostala na nula, tj. da bi start bit ostao.
--	elsif falling_edge(clock) then
--		if enable = '1' then
--			shiftout <= storage(0);
--			storage(0) <= storage(1);
--			storage(1) <= storage(2);
--			storage(2) <= storage(3);
--			storage(3) <= storage(4);
--			storage(4) <= storage(5);
--			storage(5) <= storage(6);
--			storage(6) <= storage(7);
--			storage(7) <= storage(8);
--			storage(8) <= storage(9);
--			storage(9) <= '0';
--		end if;
--	end if;
--end process;
--
--end architecture;