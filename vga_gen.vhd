----------------------------------------------------------------------------------
-- Engineer: Mike Field <hamster@snap.net.nz>
-- 
-- Description: Generates a test 1280x720 signal 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
-- library declaration if instantiating any Xilinx primitives
library UNISIM;
use UNISIM.VComponents.all;

entity vga_gen is
    Port ( clk75 : in  STD_LOGIC;
			  choice : in STD_LOGIC_VECTOR(3 downto 0);
           pclk  : out STD_LOGIC;
           red   : out STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
           green : out STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
           blue  : out STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
           blank : out STD_LOGIC := '0';
           hsync : out STD_LOGIC := '0';
           vsync : out STD_LOGIC := '0');
end vga_gen;

architecture Behavioral of vga_gen is

component test_features is
  Port ( clk : in  STD_LOGIC; -- FPGA's external oscillator
         switches: in STD_LOGIC_VECTOR(3 downto 0);
--   display_enabled: in STD_LOGIC;
--	done_: out STD_LOGIC;
 --  switch : in  STD_LOGIC_VECTOR(3 downto 0); -- hooked to slide switch SW(0) on Atlys board
   --red_out, green_out, blue_out: out  STD_LOGIC_VECTOR (7 downto 0)
   are_these_glasses : out std_logic
 ); 
end component;

component train0 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;
  
  component im_test1 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;
  
  component im_test3 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;  
  
   constant h_rez        : natural := 1280;
   constant h_sync_start : natural := 1280+72;
   constant h_sync_end   : natural := 1280+80;
   constant h_max        : natural := 1647;
   signal   h_count      : unsigned(11 downto 0) := (others => '0');

   constant v_rez        : natural := 720;
   constant v_sync_start : natural := 720+3;
   constant v_sync_end   : natural := 720+3+5;
   constant v_max        : natural := 749;
   signal   v_count      : unsigned(11 downto 0) := (others => '0');
	
	------------changes
   signal rom_addr: std_logic_vector(15 downto 0):=x"0000";
	signal dout, dout0, dout1, dout3: std_logic_vector(7 downto 0);
	signal xpix, ypix: std_logic_vector(8 downto 0);
	constant h_limit: natural := 496;--540
	constant v_limit: natural := 160;--460
	constant h_bporch: natural := 256;
	constant v_bporch: natural := 0;
	constant max_pixels: STD_Logic_vector(15 downto 0):= std_logic_vector(to_unsigned(38400, 16));
	
	constant h_limit2: natural := 1024;--540
	constant v_limit2: natural := 512;--460
	constant h_bporch2: natural := 768;
	constant v_bporch2: natural := 256;
	----------
	signal success: std_logic;
begin
   pclk <= clk75;
   train0_inst: train0 port map(a => rom_addr, spo => dout0);
	imtest1_inst: im_test1 port map(a => rom_addr, spo => dout1);
	imtest3_inst: im_test3 port map(a => rom_addr, spo => dout3);
	test_features_inst: test_features port map(clk => clk75, switches => choice, are_these_glasses => success);
--  ypix<= std_logic_vector( unsigned(v_count) - h_bporch);
--  xpix <= std_logic_vector( unsigned(h_count) - v_bporch);
--	

  mux : process(clk75)
  begin
      if rising_edge(clk75) then
        case choice is
		    when "0000" => dout <= dout0;
			 when "0001" => dout <= dout1;
			 when others => dout <= dout3;
		  end case;
		end if;
	end process;
  addresser: process(clk75)
    variable rom_addr1, rom_addr2, yline: STD_LOGIC_VECTOR (15 downto 0);
  begin
    rom_addr1 := std_logic_vector(unsigned(v_count(8 downto 0) & "0000000") + unsigned('0' & v_count(8 downto 0) & "000000") + unsigned("00" & v_count(8 downto 0) & "00000") + unsigned("000" & v_count(8 downto 0) & "0000"));
	 rom_addr2:=std_logic_vector( unsigned(rom_addr1) + unsigned("0000" & h_count) - h_bporch);
	 rom_addr <= rom_addr2;
  end process;

process(clk75)
   begin
      if rising_edge(clk75) then
         if ((h_count < h_rez) and  (v_count < v_rez)) then
			  --Test image
			  if(h_count < h_limit  and (h_count >h_bporch) and (v_count < v_limit) and (v_count > v_bporch)) then
            red   <= dout;
            green <= dout;
            blue  <= dout;--std_logic_vector(h_count(7 downto 0)+v_count(7 downto 0));
--				if(unsigned(rom_addr) = unsigned(max_pixels) ) then
--				  rom_addr<= x"0000";
--				else
--				  rom_addr <= std_logic_vector( unsigned(rom_addr)+1);
--			   end if;
           elsif(h_count < h_limit2  and (h_count >h_bporch2) and (v_count < v_limit2) and (v_count > v_bporch2)) then
             if(success = '1') then
					red   <= x"00";
					green <= x"FF";
					blue  <= x"00";
				 else
				   red   <= x"FF";
					green <= x"00";
					blue  <= x"00";
				 end if;
			  else
				  red   <= std_logic_vector(h_count(7 downto 0));
				  green <= std_logic_vector(v_count(7 downto 0));
				  blue  <= std_logic_vector(h_count(7 downto 0)+v_count(7 downto 0));
			  end if;
			  blank <= '0';
			else 
				red   <= (others => '0');
            green <= (others => '0');
            blue  <= (others => '0');
            blank <= '1';
         end if;

         if h_count >= h_sync_start and h_count < h_sync_end then
            hsync <= '1';
         else
            hsync <= '0';
         end if;
         
         if v_count >= v_sync_start and v_count < v_sync_end then
            vsync <= '1';
         else
            vsync <= '0';
         end if;
         
         if h_count = h_max then
            h_count <= (others => '0');
            if v_count = v_max then
               v_count <= (others => '0');
            else
               v_count <= v_count+1;
            end if;
         else
            h_count <= h_count+1;
         end if;

      end if;
   end process;

end Behavioral;

