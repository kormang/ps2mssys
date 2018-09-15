library ieee;
use ieee.std_logic_1164.all;

entity parity_checker is port (
	input_vec : in std_logic_vector (7 downto 0);
	result : out std_logic
);
end entity;

architecture behav of parity_checker is 
signal ls_nibl : std_logic;
signal ms_nibl : std_logic;
begin
	ls_nibl <= (input_vec(0) xor input_vec(1)) xor (input_vec(2) xor input_vec(3));
	ms_nibl <= (input_vec(4) xor input_vec(5)) xor (input_vec(6) xor input_vec(7));
	result <= ls_nibl xor ms_nibl;
end architecture;