----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz<
-- 
-- Module Name:    dvid_serdes - Behavioral 
-- Description: Generating a DVI-D 720p signal using the OSERDES2 serialisers
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity dvid_serdes is
    Port ( clk: in  STD_LOGIC;
			  switches: in STD_LOGIC_VECTOR(3 downto 0);
           tmds_out_p : out  STD_LOGIC_VECTOR(3 downto 0);
           tmds_out_n : out  STD_LOGIC_VECTOR(3 downto 0));
end dvid_serdes;

architecture Behavioral of dvid_serdes is

	signal pixel_clock     : std_logic;
	signal data_load_clock : std_logic;
	signal ioclock         : std_logic;
   signal serdes_strobe   : std_logic;

	signal red   : std_logic_vector(7 downto 0);
	signal green : std_logic_vector(7 downto 0);
	signal blue  : std_logic_vector(7 downto 0);
	signal blank : std_logic;
	signal hsync : std_logic;
	signal vsync : std_logic;

   signal tmds_out_red   : std_logic;
   signal tmds_out_green : std_logic;
   signal tmds_out_blue  : std_logic;
   signal tmds_out_clock : std_logic;
  COMPONENT vga_gen
	PORT(
		clk75 : IN std_logic;   
		choice : in STD_LOGIC_VECTOR(3 downto 0);		
		red   : OUT std_logic_vector(7 downto 0);
		green : OUT std_logic_vector(7 downto 0);
		blue  : OUT std_logic_vector(7 downto 0);
		blank : OUT std_logic;
		hsync : OUT std_logic;
		vsync : OUT std_logic
		);
	END COMPONENT;

	COMPONENT clocking
	PORT(
		clk50m          : IN  std_logic;          
		pixel_clock     : OUT std_logic;
		data_load_clock : OUT std_logic;
		ioclock         : OUT std_logic;
		serdes_strobe   : OUT std_logic
		);
	END COMPONENT;

	COMPONENT dvid_out
	PORT(
		pixel_clock     : IN std_logic;
		data_load_clock : IN std_logic;
		ioclock         : IN std_logic;
		serdes_strobe   : IN std_logic;
		red_p : IN std_logic_vector(7 downto 0);
		green_p : IN std_logic_vector(7 downto 0);
		blue_p : IN std_logic_vector(7 downto 0);
		blank : IN std_logic;
		hsync : IN std_logic;
		vsync : IN std_logic;          
		red_s : OUT std_logic;
		green_s : OUT std_logic;
		blue_s : OUT std_logic;
		clock_s : OUT std_logic
		);
	END COMPONENT;

signal clk50, sysclk: std_logic;
begin

sysclk_buf : IBUF port map(I=>clk, O=>sysclk);

-- instance of I/O Clock Buffer used as divider
sysclk_div : BUFIO2
	generic map (
		DIVIDE_BYPASS=>FALSE, 
		DIVIDE=>2)
	port map (
		DIVCLK=>clk50,
		I=>sysclk);

Inst_clocking: clocking PORT MAP(
		clk50m          => clk50,
		pixel_clock     => pixel_clock,
		data_load_clock => data_load_clock,
		ioclock         => ioclock,
		serdes_strobe   => serdes_strobe
	);

   
i_vga_gen: vga_gen PORT MAP(
		clk75 => pixel_clock,
		choice => switches,
		red   => green,
		green => red,
		blue  => blue,
		blank => blank,
		hsync => hsync,
		vsync => vsync
	);


i_dvid_out: dvid_out PORT MAP(
		pixel_clock     => pixel_clock,
		data_load_clock => data_load_clock,
		ioclock         => ioclock,
		serdes_strobe   => serdes_strobe,

		red_p           => red,
		green_p         => green,
		blue_p          => blue,
		blank           => blank,
		hsync           => hsync,
		vsync           => vsync,
      
		red_s           => tmds_out_red,
		green_s         => tmds_out_green,
		blue_s          => tmds_out_blue,
		clock_s         => tmds_out_clock
	);
   
  
OBUFDS_blue  : OBUFDS port map ( O  => tmds_out_p(0), OB => tmds_out_n(0), I  => tmds_out_blue);
OBUFDS_red   : OBUFDS port map ( O  => tmds_out_p(1), OB => tmds_out_n(1), I  => tmds_out_green);
OBUFDS_green : OBUFDS port map ( O  => tmds_out_p(2), OB => tmds_out_n(2), I  => tmds_out_red);
OBUFDS_clock : OBUFDS port map ( O  => tmds_out_p(3), OB => tmds_out_n(3), I  => tmds_out_clock);

end Behavioral;