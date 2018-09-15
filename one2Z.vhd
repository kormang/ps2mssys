library ieee;
use ieee.std_logic_1164.all;

-- za ulaz '1' daje izlaz 'Z'

entity one2Z is port (
	input : in std_logic;
	output : out std_logic
);
end entity;

architecture bahav of one2Z is

begin
	output <= 'Z' when input = '1' else '0';
end architecture;