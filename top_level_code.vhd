library ieee;
use ieee.std_logic_1164.all;   
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;
use ieee.std_logic_textio.all;

--pragma translate off
--library unisim;
--use unisim.vcomponents.all;
--pragma translate on

entity top_level_code is
port(
	reset				: in 	std_logic;
	clock				: in 	std_logic;
	-- External bus input
	data_in_tready		: out	std_logic;
	data_in_tvalid		: in	std_logic;
	data_in_tdata		: in	std_logic_vector(31 downto 0);
	data_in_tlast		: in	std_logic;
	-- External bus output
	data_out_tready		: in	std_logic;
	data_out_tvalid		: out	std_logic;
	data_out_tdata		: out	std_logic_vector(31 downto 0);
	data_out_tlast		: out	std_logic;
	tdata_input_values	: out	std_logic_vector(31 downto 0);
	raw_input_tdata		: out	std_logic_vector(31 downto 0);
	ieee754_data_out	: out	std_logic_vector(31 downto 0)
);
end entity top_level_code;

architecture struct of top_level_code is

begin
	
	binary_converter : entity work.binary_to_ieee754
	generic map (
		INTEGER_BITS		=> 16,						-- : integer := 16;
		FRACTIONAL_BITS		=> 16						-- : integer := 16
	)
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

end struct;
