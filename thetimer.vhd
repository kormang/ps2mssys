library ieee;
use ieee.std_logic_1164.all;

entity thetimer is port (
	time_interval_over: out std_logic;
	enable : in std_logic;
	sys_clk : in std_logic
);
end entity;


architecture behav of thetimer is

signal count : integer := 0;

begin

counter: process (sys_clk, enable)
--moguc izvor problema
begin
		if enable = '0' then
			count <= 0;
			time_interval_over <= '0';
	
		elsif rising_edge(sys_clk) then
				if count <  2900 then --2700 (100 micro sec) + mali dodatak, ovde od viska glava ne boli
					count <= count + 1;
					time_interval_over <= '0';
				else
					time_interval_over <= '1'; -- kad izbroji postavice signal da je izbrojio i drazti ga aktivnim sve dok se tajmer ne iskljuci
				end if;
		end if;
end process;

end architecture;