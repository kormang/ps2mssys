library ieee;
use ieee.std_logic_1164.all;

library ieee;
use ieee.std_logic_1164.all;

ENTITY soutshifter IS
	PORT
	(
		clock		: IN STD_LOGIC ;
		data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
		enable		: IN STD_LOGIC ;
		load		: IN STD_LOGIC ;
		shiftout		: OUT STD_LOGIC 
	);
END outshifter;


architecture behav of outshifter is 

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

signal bitout : std_logic;

begin
	outshifter_inst : outshifter PORT MAP (
		clock	 => ps2_clk,
		data	 => command,
		enable => oenable_shift,
		load	 => send_command,
		shiftout	 => bitout
	);

	shiftout <= 'Z' when bitout = '1' else '0';
	
	
end architecture;