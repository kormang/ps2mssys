library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

entity ps2mssys is port (
	-- inouts: ---
	ps2_clk : inout std_logic;
	ps2_dat : inout std_logic;
	
	-- ins: ---
	
	clk_27 : in std_logic;
	reset : in std_logic;
	
	--- outs: ------
	left_click, middle_click, right_click: buffer std_logic; -- indikatori klika
	error_out : out std_logic := '0'; -- indikator da je doslo do greske
	hsync, vsync: out std_logic; -- izlazi za monitor
	vga_red, vga_green, vga_blue: out std_logic_vector(3 downto 0) -- takodje

);
end entity;


architecture behav of ps2mssys is
 
signal xp, yp : std_logic_vector (9 downto 0) := "0000000000"; -- pozicije kursora na ekranu
signal pxp, pyp : std_logic_vector (10 downto 0) := "00000000000";
signal dx, dy : std_logic_vector (8 downto 0) := "000000000"; -- promjena pozicije
signal miinterrupt : std_logic;
signal controlled_clock : std_logic;    -- naparvio Vukotic, potrebno za prikazivanje slike
signal not_reset : std_logic; -- clock_controlleru je potreban invertovani reset signal

component mouse_interface is port (
	-- inouts: ---
	ps2_clk : inout std_logic;
	ps2_dat : inout std_logic;
	
	-- ins: ---
	
	clk_27 : in std_logic;
	reset : in std_logic;
	
	--- outs: ------
	left_click, middle_click, right_click: buffer std_logic; -- indikatori klika
	error_out : out std_logic := '0'; -- indikator da je doslo do greske
	dx, dy : out std_logic_vector(8 downto 0) := "000000000";
	interrupt : out std_logic := '0'
	
);
end component;

component sync_controller is
port (

	clk: in std_logic;
	px, py : in std_logic_vector(9 downto 0);
	redon, blueon, greenon : in std_logic;
	
	hsync, vsync: out std_logic;
	vga_red, vga_green, vga_blue: out std_logic_vector(3 downto 0)
);
end component;

COMPONENT clock_controller IS
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC 
	);
END COMPONENT;

begin
	
	xp <= pxp(9 downto 0);
	yp <= pyp(9 downto 0);
	not_reset <= not reset;

	clock_controller_inst : clock_controller port map(
		areset => not_reset,
		inclk0 => clk_27,
		c0 => controlled_clock
	);

	sync_controller_inst : sync_controller port map (
		clk => controlled_clock,
		px => xp,
		py => yp,
		redon => left_click,
		greenon => middle_click,
		blueon => right_click,
		hsync => hsync,
		vsync => vsync,
		vga_green => vga_green,
		vga_blue => vga_blue,
		vga_red => vga_red
	);
	
	mi: mouse_interface port map (
	-- inouts: ---
	ps2_clk => ps2_clk,
	ps2_dat => ps2_dat,
	
	-- ins: ---
	
	clk_27 => clk_27,
	reset => reset,
	
	--- outs: ------
	left_click => left_click,
	middle_click => middle_click,
	right_click => right_click,
	error_out => error_out,
	dx => dx,
	dy => dy,
	interrupt => miinterrupt
	
);

	
	process (miinterrupt)
	variable temp : signed(10 downto 0);
	begin
		if (rising_edge(miinterrupt)) then
					temp := signed(pxp) + signed(dx);
					if temp < 0 then
						pxp <= "00000000000"; 
					elsif temp >= 640 then
						pxp <= "01001111111"; -- 639 signed 11-bit
					else
						pxp <= std_logic_vector(temp(10 downto 0));
					end if;
					
					temp := signed(pyp) - signed(dy);
					if temp < 0 then
						pyp <= "00000000000"; 
					elsif temp >= 480 then
						pyp <= "00111011111"; -- 479 signed 11-bit
					else
						pyp <= std_logic_vector(temp(10 downto 0));
					end if;
		end if;
	end process;
end architecture;

--if kb_interrupt = '1' and old_kb_interrupt = '0' then
--				--y
--				yp <= signed(yp) + signed(kbdata(7) & kbdata(7) & kbdata);
--				stanje <= process_stream1;
--			end if;