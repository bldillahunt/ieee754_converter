library ieee;
use ieee.std_logic_1164.all;   
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;
use ieee.std_logic_textio.all;
use work.system_header.all;

entity top_level_testbench is
end entity top_level_testbench;

architecture behavioral of top_level_testbench is
	
	constant CLOCK_PERIOD			: time := 5.0 ns;
	constant BURST_SIZE				: integer := 2048;
	constant INTER_PACKET_GAP_TIME	: integer := 64;

	signal clock					: std_logic := '0';
	signal reset					: std_logic := '1';
	
	signal data_in_tready			: std_logic;
	signal data_in_tvalid			: std_logic;
	signal data_in_tdata			: std_logic_vector(31 downto 0);
	signal data_in_tlast			: std_logic;
	signal data_out_tready			: std_logic;
	signal data_out_tvalid			: std_logic;
	signal data_out_tdata			: std_logic_vector(31 downto 0);
	signal data_out_tlast			: std_logic;
	
	type emulation_state_machine is (START_TEST, CHECK_FOR_END_OF_DATA, INTER_PACKET_GAP);
	signal emulation_state			: emulation_state_machine;
	signal data_value				: unsigned(31 downto 0);
	signal word_counter				: integer;
	signal tdata_input_values		: std_logic_vector(31 downto 0);
	signal raw_input_tdata			: std_logic_vector(31 downto 0);
	signal ieee754_data_out			: std_logic_vector(31 downto 0);

begin
	
	clock <= not clock after CLOCK_PERIOD/2;
	reset <= '0' after 1.0 us;
	
	binary_converter : entity work.top_level_code
	port map (
		reset				=> reset			,		--: in 	std_logic;
		clock				=> clock			,		--: in 	std_logic;
		data_in_tready		=> data_in_tready	,		--: out	std_logic;
		data_in_tvalid		=> data_in_tvalid	,		--: in	std_logic;
		data_in_tdata		=> data_in_tdata	,		--: in	std_logic_vector(31 downto 0);
		data_in_tlast		=> data_in_tlast	,		--: in	std_logic;
		data_out_tready		=> data_out_tready	,		--: in	std_logic;
		data_out_tvalid		=> data_out_tvalid	,		--: out	std_logic;
		data_out_tdata		=> data_out_tdata	,		--: out	std_logic_vector(31 downto 0);
		data_out_tlast		=> data_out_tlast	,		--: out	std_logic;
		tdata_input_values	=> tdata_input_values,		--: out	std_logic_vector(31 downto 0);
		raw_input_tdata		=> raw_input_tdata	,		--: out	std_logic_vector(31 downto 0);
		ieee754_data_out	=> ieee754_data_out			--: out	std_logic_vector(31 downto 0)
	);

	data_input_emulation : process(clock, reset)
		variable ipg_counter	: integer;
		variable lfsr_data		: std_logic_vector(31 downto 0);
	begin
		if (reset = '1') then
			emulation_state		<= START_TEST;
			data_in_tvalid		<= '0';
			data_in_tdata		<= (others => '0');
			data_in_tlast		<= '0';
			data_out_tready		<= '0';
			data_value			<= to_unsigned(1, 32);
			word_counter		<= 0;
			ipg_counter			:= 0;
			lfsr_data			:= (others => '1');
		elsif (rising_edge(clock)) then
			data_out_tready		<= '1';
			
			case (emulation_state) is
				when START_TEST =>
					data_in_tvalid		<= '1';
					
					if (data_in_tready = '1') then
						lfsr_data			:= prbs_pattern_generator('1', lfsr_data);
						data_in_tdata		<= lfsr_data;	-- std_logic_vector(data_value);
						data_in_tlast		<= '0';
						data_value			<= data_value + 1;
						emulation_state		<= CHECK_FOR_END_OF_DATA;
					else
						word_counter		<= 1;	-- First beat is already loaded
					end if;
				when CHECK_FOR_END_OF_DATA =>
					if (word_counter = BURST_SIZE-2) then
						lfsr_data			:= prbs_pattern_generator('1', lfsr_data);
						data_in_tdata		<= lfsr_data;	-- std_logic_vector(data_value);
						data_in_tlast		<= '1';
						data_value			<= data_value + 1;
						word_counter		<= word_counter + 1;
					elsif (word_counter < BURST_SIZE-1) then
						lfsr_data			:= prbs_pattern_generator('1', lfsr_data);
						data_in_tdata		<= lfsr_data;	-- std_logic_vector(data_value);
						data_in_tlast		<= '0';
						data_value			<= data_value + 1;
						word_counter		<= word_counter + 1;
					else
						data_in_tvalid		<= '0';
						data_in_tlast		<= '0';
						word_counter		<= 0;
						ipg_counter			:= 0;
						emulation_state		<= INTER_PACKET_GAP;
					end if;
				when INTER_PACKET_GAP =>
					data_in_tvalid		<= '0';
					data_in_tlast		<= '0';
					word_counter		<= 0;
					
					if (ipg_counter < INTER_PACKET_GAP_TIME-1) then
						ipg_counter			:= ipg_counter + 1;
					else
						emulation_state		<= START_TEST;
					end if;
				when others => emulation_state		<= START_TEST;
			end case;
		end if;
	end process;
	
	msb_search_report : process (clock)
		file msb_search_output	: text open write_mode is "msb_search_file.txt";
		variable msb_search_line : line;
	begin
		if (rising_edge(clock)) then
			if (data_out_tvalid	= '1') and (data_out_tready = '1') then
				hwrite(msb_search_line, data_out_tdata);
				write(msb_search_line, string'(" "));
				write(msb_search_line, tdata_input_values);
				write(msb_search_line, string'(" "));
				hwrite(msb_search_line, raw_input_tdata);
				write(msb_search_line, string'(" "));
				hwrite(msb_search_line, ieee754_data_out);
				writeline(msb_search_output, msb_search_line);
			end if;
			
			if (data_out_tlast = '1') then
				write(msb_search_line, string'("End of data"));
				writeline(msb_search_output, msb_search_line);
			end if;
		end if;
	end process;
end behavioral;
