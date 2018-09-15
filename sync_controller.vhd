library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_controller is
port (

	clk: in std_logic;
	px, py : in std_logic_vector(9 downto 0);
	redon, blueon, greenon : in std_logic;
	
	hsync, vsync: out std_logic;
	vga_red, vga_green, vga_blue: out std_logic_vector(3 downto 0)
);
end entity;

architecture behavior of sync_controller is
signal hposition: integer:= 0;
signal vposition: integer:= 0;

signal red: std_logic_vector(3 downto 0);
signal green: std_logic_vector(3 downto 0);
signal blue: std_logic_vector(3 downto 0);
begin

	update_position: process(clk)
	begin
		
		if rising_edge(clk) then
			if hposition < 800 then	
				hposition <= hposition + 1;
			else
				hposition <= 0;
				if vposition < 525 then
					vposition <= vposition + 1;
				else
					vposition <= 0;
				end if;
			end if;
		if hposition > 16 and hposition < 113 then
			hsync <= '0';
		else
			hsync <= '1';
		end if;
		if vposition > 10 and vposition < 13 then
			vsync <= '0';
		else
			vsync <= '1';
		end if;
		if hposition > 160 and vposition > 45 then
			vga_red <= red;
			vga_green <= green;
			vga_blue <= blue;
		else
			vga_red <= (others => '0');
			vga_green <= (others => '0');
			vga_blue <= (others => '0');
		end if;
	end if;
	end process;
				
	pixel: process(px, py, hposition, vposition, redon, greenon, blueon)
	variable phor: integer;
	variable pver: integer;
	begin
		phor := to_integer(unsigned(px) + 160);
		pver := to_integer(unsigned(py) + 45);
		--stavio sam da je radijus kruga 10px
		--ti mu samo saljes poziciju pixela ,horizontalno 0-640 ,vertikalno 0 - 480
		--if (hposition - phor)*(hposition - phor) + (vposition - pver) *(vposition - pver) < 100 then
		if abs(hposition - phor) < 10 and abs(vposition - pver) < 10 then
			red <= (others => not redon);
			green <= (others => not greenon);
			blue <= (others => not blueon);
		else
			red <= (others => '0');
			green <= (others => '0');
			blue <= (others => '0');
		end if;
	end process;
end architecture;