library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

entity mouse_interface is port (
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
	interrupt : out std_logic
	
);
end entity;

architecture behav of mouse_interface is 

type state_t is ( reseting, send_reset, wait_reset_csed, read_reset_ack, -- stanja kroz koja prolazi prilokom reseta, zavrsava stanjem koje ceka na potvrdu o resetu od misa
						read_selftest, read_deviceid, -- poslije reseta mis ce poslati SEFT TEST RESULT, i DEVICE ID
						send_enable_reporting, wait_enable_reporting_csed, read_enable_reporting_ack, -- stanja kroz koja prolazi da bi misu rekao da moze poceti slati podatke
						streaming,  -- stanje u kom top-level entity ne radi nista, vec se "streamer" vrti kroz svoja stanja kupeci i obradjujuci podatke od misa
						error); -- stanju u koje uredjaj udje ukoliko je doslo do greske prije ulaska u streaming stanje.
						
signal stanje : state_t := reseting;    -- stanje masine stanja, krece sa resetom
signal kbdata : std_logic_vector (7 downto 0); -- bajt primljen od ps2kbcontrollera
signal kb_interrupt, kb_interrupt_async : std_logic;        -- signal od ps2kbcontrollera koji oznacava da li je baj spreman za preuzimanje
signal old_kb_interrupt, old_controller_error : std_logic := '0'; -- registi u kojima cuvam stara stanja signala kako bih mogao odrediti da li se desila rastuca ivica
signal command : std_logic_vector (7 downto 0); -- komanda koju dajem ps2commanderu na slanje misu
signal time_interval_over :  std_logic; -- signal od timera da je proslo dovoljno vremena od kako je ps2 takt povucen na nulu prije slanja komande
signal send_command : std_logic := '0'; -- signal ps2commanderu da pocne sa slanjem komande
signal enable_timer : std_logic := '0'; -- ukljucenje timera, mora biti istovremeno sa iniciranjem slanja komande, ali se iskljucuje kasnije
signal enable_read : std_logic := '0';  -- prikadac koji dozvoljava da ps2kbcontroller cita podatke sa ps2 porta (kad ps2commmander salje, onda on ne treba da cita)
signal command_sended, command_sended_async :  std_logic;     -- signal od ps2commandera da je zavrsio sa slanjem komande
signal commander_error, commander_error_async, controller_error, controller_error_async : std_logic; -- signali od enititeta za slanje i primanje podataka da je doslo do greske

signal enable_streaming : std_logic := '0';  -- signal streameru da moze poceti sa citanjem tro-bajtnih sekvenci

signal ps2_clk_in, ps2_dat_in : std_logic; -- ulazi za ps2kbcontroller, samo proslidjeno sa ps2_clk i ps2_dat
signal old_tio, old_command_sended, old_commander_error : std_logic := '0'; -- ponovo neki registri koji sluze za detektovanje rastuce ivice drugis signala u procesu aktovnom na takt oscilatora

signal sys_clk : std_logic;

---- KOMPONENTE: ----------------
--detaljnije su opisane u svojim fajlovima

component ps2kbcontroller is port (
	-- prema konektoru: --
	ps2_clk : in std_logic;
	ps2_dat : in std_logic;
	-- prema sistemu: --
	reset : in std_logic := '1';
	kbdata : buffer std_logic_vector (7 downto 0) := "00000000";
	error_occured : out std_logic := '0';
	data_ready : out std_logic := '0'
);
end component;


component thetimer is port (
	time_interval_over: out std_logic;
	enable : in std_logic;
	sys_clk : in std_logic
);
end component;


component ps2commander is port (
	-- prema konektoru: --
	ps2_clk : inout std_logic;
	ps2_dat : inout std_logic;
	-- prema sistemu: --
	command_sended : out std_logic := '0';
	
	reset : in std_logic;
	sys_clk : in std_logic;
	command : in std_logic_vector (7 downto 0);
	time_interval_over : in std_logic;
	error_occured : out std_logic := '0';
	send_command : in std_logic := '0'
	
	
);
end component;


component streamer is port (
	kb_interrupt, controller_error : in std_logic;
	old_kb_interrupt, old_controller_error : in std_logic;
	kbdata : in std_logic_vector (7 downto 0);
	enable : in std_logic;
	sys_clk, reset : in std_logic;
	
	interrupt : out std_logic := '0';
	left_click, right_click, middle_click : out std_logic := '0';
	dx, dy : out std_logic_vector (8 downto 0)
	
);
end component;

component devider is port ( 
	clkin : in std_logic;
	clkout : buffer std_logic := '0'
);
end component;

component syncff is port (
	clock : in std_logic;
	reset : in std_logic;
	input : in std_logic;
	output_prev : out std_logic;
	output_curr : out std_logic
);
end component;

begin
	
	ps2_clk_in <= ps2_clk when enable_read = '1' else '1';
	ps2_dat_in <= ps2_dat when enable_read = '1' else '1';


	command_sended <= command_sended_async;
	commander_error <= commander_error_async;
	-- INSTNCE KOMPONENTI: ---
	-- koponente i signali prikaceni na njih su vec opisani tamo gdje su definisani
	
	kbisff : syncff port map (
		clock => sys_clk,
		reset => reset,
		input => kb_interrupt_async,
		output_prev => old_kb_interrupt,
		output_curr => kb_interrupt
	);

--	cmisff : syncff port map (
--		clock => sys_clk,
--		reset => reset,
--		input => command_sended_async,
--		output_prev => old_command_sended,
--		output_curr => command_sended
--	);
	
	kbesff : syncff port map (
		clock => sys_clk,
		reset => reset,
		input => controller_error_async,
		output_prev => old_controller_error,
		output_curr => controller_error
	);
	
--	cmesff : syncff port map (
--		clock => sys_clk,
--		reset => reset,
--		input => commander_error_async,
--		output_prev => old_commander_error,
--		output_curr => commander_error
--	);
	
	devider_inst: devider port map (
		clkin => clk_27,
		clkout => sys_clk
	);
	
	streamer_inst : streamer port map (
		kb_interrupt => kb_interrupt,
		controller_error => controller_error,
		old_kb_interrupt => old_kb_interrupt,
		old_controller_error => old_controller_error,
		kbdata => kbdata,
		enable => enable_streaming,
		sys_clk => sys_clk,
		reset => reset,
		interrupt => interrupt,
		left_click => left_click,
		right_click => right_click,
		middle_click => middle_click,
		dx => dx,
		dy => dy
	);
	
	ps2commander_inst : ps2commander port map(
		ps2_clk => ps2_clk,
		ps2_dat => ps2_dat,
		command_sended => command_sended_async,
		reset => reset,
		sys_clk => sys_clk,
		command => command,
		time_interval_over => time_interval_over,
		error_occured => commander_error_async,
		send_command => send_command
	);
	

	timer : thetimer port map (
		time_interval_over => time_interval_over,
		enable => enable_timer,
		sys_clk => clk_27
	);

	controller : ps2kbcontroller port map (
		ps2_clk => ps2_clk_in,
		ps2_dat => ps2_dat_in,
		kbdata => kbdata,
		data_ready => kb_interrupt_async,
		error_occured => controller_error_async,
		reset => reset
	);


main:	process (sys_clk, reset)

begin
	if reset = '0' then
		-- ovih 7 signala dobija vrijednost u svakom stanju kako bi maksimalno smanjio mogucnost implicitne memorije
		stanje <= reseting;
		enable_read <= '0';
		error_out <= '0';
		enable_timer <= '0';
		send_command <= '0';
		command <= "01011010"; -- ovo mogu biti i sve nule, nije ni bitno
		enable_streaming <= '0';
		
	elsif rising_edge(sys_clk) then
	-- sta koje stanje radi vec je opisano, ovde cu samo komentarisati neke detalje --
		case stanje is
			when reseting =>
				enable_read <= '0';
				error_out <= '0';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010";
				enable_streaming <= '0';
				stanje <= send_reset;
			
			when send_reset =>
				enable_read <= '0';
				error_out <= '0';
				enable_timer <= '1'; -- pokrecem tajmer
				send_command <= '1'; -- i iniciram slanje komande
				command <= "11111111"; -- FF - reset
				enable_streaming <= '0';
				-- sad ceka da prodje vrijeme potrebno za pocetak slanja (clock pulldown), 100 mikrosekundi
				if time_interval_over = '1' and old_tio = '0' then
					stanje <= wait_reset_csed; -- ako je prosao vremenski interval onda treba cekati da se posalje komande
																	-- nisam stavio da odmah predje u to stanje jer treba poslije vremenskog intervala iskljuciti
																	-- send_command
				else
					stanje <= send_reset; -- ostajem u ovom stanju dok se ne desi da time_interval_over postane 1
				end if;
					
			when wait_reset_csed => -- ovde cekam da se komanda posalje
				enable_read <= '0';
				error_out <= '0';
				enable_timer <= '1'; -- timer ce zadrzati znak da je odbrojao dok se komande skroz ne posalje
				send_command <= '0';
				command <= "01011010"; -- beze da vidim nesto, inace mogu sve nule
				enable_streaming <= '0';
				if command_sended = '1' and old_command_sended = '0' then
					stanje <= read_reset_ack; -- kad je komanda poslana, treba cekati odgovor
				elsif commander_error = '1' and old_commander_error = '0' then
					stanje <= error; -- ako se deslia greska pri slanju
				else
					stanje <= wait_reset_csed; --dok se komanda ne poslje ostajem u ovom stanju
				end if;
					
			when read_reset_ack =>
				enable_read <= '1'; -- omogucavam ps2kbcontrolleru da procita odgovor
				error_out <= '0';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010"; -- ne bitno sta je
				enable_streaming <= '0';
				if old_kb_interrupt = '0' and kb_interrupt = '1' then
					if kbdata = "11111010" then -- FA - ACK
						stanje <= read_selftest; -- ako je mis prihvatio komandu i odgovorio sa FAh treba procitati rezultat samotestiranja
					else
						stanje <= error; -- ako mis nije razumio komandu onda nema smisla nastaviti dalje
					end if;
				elsif old_controller_error = '0' and controller_error = '1' then 
					stanje <= error;-- ako se desila greska pri slanju nema smisla nastaviti dalje
				else
					stanje <= read_reset_ack;
				end if;
				
			when read_selftest =>
				enable_read <= '1';
				error_out <= '0';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010"; -- beze da vidim nesto, inace mogu sve nule
				enable_streaming <= '0';
				if old_kb_interrupt = '0' and kb_interrupt = '1' then
					if kbdata = "10101010" then -- AA - ako je self test uspjesan
						stanje <= read_deviceid; -- sad treba procitati device id
					else
						stanje <= error;
					end if;
				elsif old_controller_error = '0' and controller_error = '1' then
					stanje <= error;
				else
					stanje <= read_selftest;
				end if;
				
			when read_deviceid =>
				enable_read <= '1'; -- procedure kod citanja su jendostavne i uvijek iste
				error_out <= '0';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010"; -- beze da vidim nesto, inace mogu sve nule
				enable_streaming <= '0';
				if old_kb_interrupt = '0' and kb_interrupt = '1' then
					if kbdata = "00000000" then
						stanje <= send_enable_reporting; -- ne provjeravam koji je deviceID
					else
						stanje <= error;
					end if;
				elsif old_controller_error = '0' and controller_error = '1' then
					stanje <= error;
				else
					stanje <= read_deviceid;
				end if;
					
			when send_enable_reporting => -- postupak slanja komde je vec objasnjen kod reseta
				command <= "11110100"; -- F4 - enable data reporting
				enable_read <= '0';
				error_out <= '0';
				enable_timer <= '1';
				send_command <= '1';
				enable_streaming <= '0';
				if time_interval_over = '1' and old_tio = '0' then
					stanje <= wait_enable_reporting_csed; -- ako je prosao vremenski interval onda treba cekati da se posalje komande
																	-- nisam stavio da odmah predje u to stanje jer treba poslije vremenskog intervala iskljuciti
																	-- send_command
				else
					stanje <= send_enable_reporting;
				end if;
			
			when wait_enable_reporting_csed =>
				enable_read <= '0';
				error_out <= '0';
				enable_timer <= '1';
				send_command <= '0';
				command <= "01011010"; -- beze da vidim nesto, inace mogu sve nule
				enable_streaming <= '0';
				if command_sended = '1' and old_command_sended = '0' then
					stanje <= read_enable_reporting_ack;
				elsif commander_error = '1' and old_commander_error = '0' then
					stanje <= error;
				else
					stanje <= wait_enable_reporting_csed;
				end if;
					
			when read_enable_reporting_ack =>
				enable_read <= '1';
				error_out <= '0';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010"; -- beze da vidim nesto, inace mogu sve nule
				enable_streaming <= '0';
				if old_kb_interrupt = '0' and kb_interrupt = '1' then
					if kbdata = "11111010" then -- FA - ACK
						stanje <= streaming;
					else
						stanje <= error;
					end if;
				elsif old_controller_error = '0' and controller_error = '1' then
					stanje <= error;
				else
					stanje <= read_enable_reporting_ack;
				end if;				
					
			
			when error => -- stanje greske
				enable_read <= '0';
				error_out <= '1';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010"; -- beze da vidim nesto, inace mogu sve nule
				enable_streaming <= '0';
				stanje <= error;
			
			when streaming => -- u ovom stanju ostaje do reseta, streamer ce dalje obavljati posao
				enable_read <= '1';
				error_out <= '0';
				enable_timer <= '0';
				send_command <= '0';
				command <= "01011010";
				enable_streaming <= '1';
				stanje <= streaming;
				
			end case;
			-- pamtim prosla stanja neopohodnih signala --
			old_tio <= time_interval_over;
			old_command_sended <= command_sended;
			old_commander_error <= commander_error;
	end if;

	
end process;

end architecture;