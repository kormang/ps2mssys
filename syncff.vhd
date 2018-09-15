library ieee;
use ieee.std_logic_1164.all;

entity syncff is port (
	clock : in std_logic;
	reset : in std_logic;
	input : in std_logic;
	output_prev : out std_logic;
	output_curr : out std_logic
);
end entity;

architecture behav of syncff is

signal syn, c1, c2 : std_logic := '0';

begin

	output_curr <= c1;
	output_prev <= c2;

	process (clock, reset)
	begin
		if reset = '0' then
			syn <= '0';
			c1 <= '0';
			c2 <= '0';
		elsif rising_edge(clock) then
			c2 <= c1;
			c1 <= syn;
			syn <= input;
		end if;	
	end process;

end architecture;