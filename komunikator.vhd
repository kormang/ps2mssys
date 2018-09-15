library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity komunikator is port
(
		-- inouts: ---
	ps2_clk : inout std_logic;
	ps2_dat : inout std_logic;
	
	clk_27 : in std_logic;
);
end entity;

