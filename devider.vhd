library ieee;
use ieee.std_logic_1164.all;

entity devider is port ( 
	clkin : in std_logic;
	clkout : buffer std_logic := '0'
);
end entity;

architecture behav of devider is 
signal count : integer := 0;
begin

process (clkin)
begin
	if(rising_edge(clkin)) then
		if count < 135 then
			count <= count + 1;
		else
			count <= 0;
			clkout <= not clkout;
		end if;
	
	end if;
end process;

	
end architecture;