library ieee;
use ieee.std_logic_1164.all;   
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;
use ieee.std_logic_textio.all;

package system_header is

	function prbs_pattern_generator(data_enable : std_logic; seed_value : std_logic_vector(31 downto 0)) return std_logic_vector;
	
end package system_header;

package body system_header is
	
	-- Polynomial = x^32 + x^22 + x^2 + x^1 + 1
	function prbs_pattern_generator(data_enable : std_logic; seed_value : std_logic_vector(31 downto 0)) return std_logic_vector is
		variable lfsr_data	: std_logic_vector(31 downto 0);
		variable lfsr_bit 	: std_logic;
	begin
		if (data_enable = '1') then
			lfsr_bit	:= seed_value(0) xor (seed_value(1) xor (seed_value(21) xor seed_value(31)));
			lfsr_data	:= seed_value(30 downto 0) & lfsr_bit;
		end if;

		return lfsr_data;
	end function;
end package body system_header;

