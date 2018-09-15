LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;


ENTITY inshifter IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		enable		: IN STD_LOGIC ;
		shiftin		: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
END ENTITY;

architecture syn of inshifter is

signal storage : std_logic_vector(7 downto 0) := "00000000";

begin 

q <= storage;


process (clock)

-- na opadajucu ivici takta koji stize iz uradjaja on usiftava bitove
-- bajt mora ostati ne dirnut dok se ne pocne usiftavati novi
begin
	if falling_edge(clock) then
		if enable = '1' then
			storage(0) <= storage(1);
			storage(1) <= storage(2);
			storage(2) <= storage(3);
			storage(3) <= storage(4);
			storage(4) <= storage(5);
			storage(5) <= storage(6);
			storage(6) <= storage(7);
			storage(7) <= shiftin;
		else
			storage <= storage;
		end if;
	end if;

end process;


end architecture;