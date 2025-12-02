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

entity binary_to_ieee754 is
generic(
	INTEGER_BITS		: integer := 16;
	FRACTIONAL_BITS		: integer := 16
);
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
end entity binary_to_ieee754;

architecture struct of binary_to_ieee754 is

-- CONSTANTS

	constant BIT_DEPTH			: integer := INTEGER_BITS + FRACTIONAL_BITS;

-- TYPES

	type tdata_register_array is array (0 to BIT_DEPTH-1) of std_logic_vector(BIT_DEPTH-1 downto 0);
	type index_array is array (0 to BIT_DEPTH-1) of integer;
	type mantissa_register_array is array (0 to BIT_DEPTH-1) of std_logic_vector(22 downto 0);

-- SIGNALS

	-- First stage
	signal tdata_in_pipe0			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal sign_bit_pipe0			: std_logic;
	signal tready_in_pipe0			: std_logic;
	signal tvalid_in_pipe0			: std_logic;
	signal tlast_in_pipe0			: std_logic;
	signal raw_input_pipe0			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal tdata_in_pipe1			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal tready_in_pipe1			: std_logic;
	signal tvalid_in_pipe1			: std_logic;
	signal tlast_in_pipe1			: std_logic;
	signal sign_bit_pipe1			: std_logic;
	signal raw_input_pipe1			: std_logic_vector(BIT_DEPTH-1 downto 0);
	
	signal tvalid_register			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal tdata_register			: tdata_register_array;
	signal tlast_register			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal data_shift_register		: tdata_register_array;
	signal sign_bit_register		: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal raw_input_register		: tdata_register_array;
	signal mantissa_register		: mantissa_register_array;
	signal input_side_tready		: std_logic;
	signal msb_found_shift_reg		: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal msb_index_shift_reg		: index_array;
	
	-- Second stage				
	signal tdata_msb_value			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal tvalid_msb_value			: std_logic;
	signal tlast_msb_value			: std_logic;
	signal tdata_msb_pipe			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal sign_bit_value			: std_logic;
	signal raw_input_value			: std_logic_vector(BIT_DEPTH-1 downto 0);
	signal mantissa_value			: std_logic_vector(22 downto 0);
	signal ieee754_sign_bit			: std_logic;
	signal ieee754_exponent			: std_logic_vector(7 downto 0);
	signal ieee754_mantissa			: std_logic_vector(22 downto 0);
	
begin

	data_in_tready	<= input_side_tready;
	
	data_registers : process (reset, clock)
	begin
		if (reset = '1') then
			input_side_tready	<= '0';
		elsif (rising_edge(clock)) then
			input_side_tready	<= data_out_tready;
		end if;
	end process;

----------<<<<<<<<<< FIRST STAGE >>>>>>>>>----------

	determine_exponent : process (clock)
	begin
		if (rising_edge(clock)) then
			-- First, check for a negative number and then invert if needed
			if (data_in_tvalid = '1') and (input_side_tready = '1') then
				if (data_in_tdata(data_in_tdata'high) = '1') then
					tdata_in_pipe0	<= not data_in_tdata;
					sign_bit_pipe0	<= '1';
				else
					tdata_in_pipe0	<= data_in_tdata;
					sign_bit_pipe0	<= '0';
				end if;
			end if;
				
			tready_in_pipe0	<= input_side_tready;
			tvalid_in_pipe0	<= data_in_tvalid;
			tlast_in_pipe0	<= data_in_tlast;
			raw_input_pipe0	<= data_in_tdata;
			
			-- Perform the addition to get the twos-complement value
			if (sign_bit_pipe0 = '1') then
				tdata_in_pipe1		<= std_logic_vector(unsigned(tdata_in_pipe0) + to_unsigned(1, BIT_DEPTH));
			else
				tdata_in_pipe1		<= tdata_in_pipe0;
			end if;
			
			tready_in_pipe1			<= tready_in_pipe0;	
			tvalid_in_pipe1			<= tvalid_in_pipe0;	
			tlast_in_pipe1			<= tlast_in_pipe0;	
			sign_bit_pipe1			<= sign_bit_pipe0;
			raw_input_pipe1			<= raw_input_pipe0;
			
			-- Create a pipeline that is the size of the number of bits
			tvalid_register(0)		<= tvalid_in_pipe1;
			tdata_register(0)		<= tdata_in_pipe1;
			tlast_register(0)		<= tlast_in_pipe1;
			data_shift_register(0)	<= tdata_in_pipe1;
			sign_bit_register(0)	<= sign_bit_pipe1;
			raw_input_register(0)	<= raw_input_pipe1;
			mantissa_register(0)	<= (others => '0');
			
			if (tvalid_in_pipe1 = '1') and (tdata_in_pipe1 = (tdata_in_pipe1'high downto 0 => '0')) and (tready_in_pipe1 = '1') then
				msb_found_shift_reg(0)	<= '1';
				msb_index_shift_reg(0)	<= -1;
			else
				msb_found_shift_reg(0)	<= '0';
				msb_index_shift_reg(0)	<= 0;
			end if;

			if ((tvalid_in_pipe1 = '1') and (tready_in_pipe1 = '1')) or (tvalid_register(BIT_DEPTH-1) = '1') then			
				for i in 1 to BIT_DEPTH-1 loop
					tvalid_register(i)		<= tvalid_register(i-1);	
					tdata_register(i)		<= tdata_register(i-1);	
					tlast_register(i)		<= tlast_register(i-1);	
					data_shift_register(i)	<= data_shift_register(i-1)(BIT_DEPTH-2 downto 0) & '0';
					sign_bit_register(i)	<= sign_bit_register(i-1);
					raw_input_register(i)	<= raw_input_register(i-1);
				end loop;
			end if;

			for i in 0 to BIT_DEPTH-2 loop
				if (data_shift_register(i)(BIT_DEPTH-1) = '1') and (msb_found_shift_reg(i) = '0') then
					msb_found_shift_reg(i+1)	<= '1';
					msb_index_shift_reg(i+1)	<= (BIT_DEPTH-1) - i;
					mantissa_register(i+1)		<= data_shift_register(i)(BIT_DEPTH-2 downto 8);
				else
					msb_found_shift_reg(i+1)	<= msb_found_shift_reg(i);
					msb_index_shift_reg(i+1)	<= msb_index_shift_reg(i);
					mantissa_register(i+1)		<= mantissa_register(i);
				end if;
			end loop;
		end if;
	end process;

----------<<<<<<<<<< SECOND STAGE >>>>>>>>>----------

	gather_exponent_values : process (clock)
	begin
		if (rising_edge(clock)) then
			-- Sample the data coming from the shift registers
			tvalid_msb_value	<= tvalid_register(BIT_DEPTH-1);
			tlast_msb_value		<= tlast_register(BIT_DEPTH-1);
			tdata_msb_value		<= std_logic_vector(to_signed(msb_index_shift_reg(BIT_DEPTH-1), BIT_DEPTH));
			tdata_msb_pipe		<= tdata_register(BIT_DEPTH-1);
			sign_bit_value		<= sign_bit_register(BIT_DEPTH-1);
			raw_input_value		<= raw_input_register(BIT_DEPTH-1);
			mantissa_value		<= mantissa_register(BIT_DEPTH-1);
		end if;
	end process;
			
	-- Calculate the IEEE754 value
	ieee754_sign_bit	<= sign_bit_value;
	ieee754_exponent	<= std_logic_vector(unsigned(tdata_msb_value(7 downto 0)) + to_unsigned(127-FRACTIONAL_BITS, 8));
	ieee754_mantissa	<= mantissa_value;

	output_registers : process (clock)
	begin
		if (rising_edge(clock)) then
			data_out_tvalid		<= tvalid_msb_value;	
			data_out_tdata		<= tdata_msb_value;  	
			data_out_tlast		<= tlast_msb_value;
			tdata_input_values	<= tdata_msb_pipe;
			raw_input_tdata		<= raw_input_value;
			ieee754_data_out	<= ieee754_sign_bit & ieee754_exponent & ieee754_mantissa;
		end if;				   	
	end process;
end struct;
