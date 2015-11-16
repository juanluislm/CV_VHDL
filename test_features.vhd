library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity test_features is
  Port ( clk : in  STD_LOGIC; -- FPGA's external oscillator
         switches: in STD_LOGIC_VECTOR(3 downto 0);
--   display_enabled: in STD_LOGIC;
--	done_: out STD_LOGIC;
 --  switch : in  STD_LOGIC_VECTOR(3 downto 0); -- hooked to slide switch SW(0) on Atlys board
   --red_out, green_out, blue_out: out  STD_LOGIC_VECTOR (7 downto 0)
   are_these_glasses : out std_logic
 ); 
end test_features;

architecture Structural of test_features is

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
  
  component train0 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;
  
  component training is
  Port ( clk : in  STD_LOGIC; -- FPGA's external oscillator
	enable: in std_logic;
	done : out std_logic;
   f0, f2, f3, f4, f5 : out  STD_LOGIC_VECTOR (99 downto 0)
  ); 
  end component;
  
  constant MAX_VALUE: STD_LOGIC_VECTOR(23 downto 0):= x"95FFFF"; --38400x256
  signal my_addr_counter  : STD_LOGIC_VECTOR (15 downto 0) := x"0000";
  signal dout_rom0, dout_rom2, dout_rom3, img_pix: STD_LOGIC_VECTOR(7 downto 0);
  
  signal d_sum0, d_sum2, d_sum3, d_sum4, d_sum5: std_logic_vector(23 downto 0):=x"000000";
  signal train_flag, avg_flag, th_flag, th_flag2, th_flag3, th_flag4, th_flag5: std_logic:='0';
  
  --registered outputs
  signal d_sum0_new, d_sum2_new, d_sum3_new, d_sum4_new, d_sum5_new: std_logic_vector(23 downto 0);
  signal divided_new, divided2_new, divided3_new, divided4_new, divided5_new: std_logic_vector(7 downto 0);
  
  constant n_features: std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(99, 9));
  constant tolerance: natural := 85;
  
  signal features0, features2, features3, features4, features5, features_test : std_logic_vector(99 downto 0); -- we are convolving boxes of 24x16 pixels 
  signal holder0, holder2, holder3, holder4, holder5 : std_logic_vector(383 downto 0); 
  signal position, f_position, ones0: STD_LOGIC_VECTOR(8 downto 0):="000000000";
 
  constant max_level : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(383, 9));
  constant weight_level : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(192, 9));
  
  signal ena: std_logic:='0';
  signal is_trained: std_logic;
  signal matches0, matches2, matches3, matches4, matches5: std_logic_vector(8 downto 0):= std_logic_vector(to_unsigned(0, 9));
  signal compare0, compare2, compare3, compare4, compare5: std_logic:='0';
  signal counter0, counter2, counter3, counter4, counter5: std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(0, 9));
  signal success, success2, success3, success4, success5: std_logic;
  signal ones: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  signal first_time: std_logic := '0';
  signal prev_switch: std_logic_vector(3 downto 0);
  signal reset: std_logic:= '0'; 
begin
  memory0 : im_test1 port map (a => my_addr_counter, spo => dout_rom0); 
  memory2 : im_test3 port map (a => my_addr_counter, spo => dout_rom2); 
  memory3 : train0 port map (a => my_addr_counter, spo => dout_rom3);
  train_instance: training port map(clk => clk, enable => '0', done => is_trained, f0 => features0, f2 => features2, f3 => features3, f4 => features4, f5 => features5);
	
--  train_once: process(clk, is_trained)
--  begin
--    if (clk'event and clk = '1') then
--	  if(is_trained='1' or switches = "0000") then
--	    ena <= '1';
--	  else
--	    ena <= '0';
--	  end if;
--	end if;
--  end process;
  
  choose_test_image: process(clk, switches)
  begin
    if (clk'event and clk = '1') then
	   if(first_time = '0') then
	     prev_switch <= switches;
		  first_time<= '1';
		  reset <= '1';
	   else
	     if(prev_switch /= switches) then
		    prev_switch <= switches;
		    reset <='0';
		  else
		    reset <= '1';
		  end if;
	   end if;
	  case switches is
	    when "0000" => img_pix <= dout_rom3;
		 when "0001" => img_pix <= dout_rom0;
		when others => img_pix <= dout_rom2;
	  end case;
	end if;
  end process;
  
  addr: process (clk, train_flag, th_flag, is_trained, reset)
  begin
    if (clk'event and clk = '1') then
      if ( ((train_flag='0' and th_flag='0') or (train_flag='1' and th_flag='0') or (train_flag='1' and th_flag='1' and compare0='0')) and is_trained='1' and reset ='1') then
        my_addr_counter <= std_logic_vector( unsigned(my_addr_counter) + 1);
		else
		  my_addr_counter<=x"0000";  
		end if;
	 end if;
  end process;
  
  -- average pixel value
  avg : process (clk, train_flag, is_trained, reset) is
  begin
    if (clk'event and clk = '1') then
	  if(reset = '0') then
	    train_flag<='0';   
	  else
		  if (train_flag='0' and is_trained='1') then
			 d_sum0 <= std_logic_vector(unsigned(d_sum0) + unsigned("00000000" & img_pix));
			 if(my_addr_counter = x"95FF") then
				train_flag<='1';      
			 end if;
		  end if;  
	   d_sum0_new<=d_sum0;
		end if;
    end if;
  end process; 
  
  div : process(clk, train_flag, avg_flag, is_trained, reset)
    variable d_sum01: std_logic_vector(23 downto 0);
  begin
    if (clk'event and clk = '1') then
	   if(reset='0') then
		  avg_flag<='0';
		else
			if (train_flag='1' and avg_flag='0' and is_trained='1') then
			  d_sum01 :=  std_logic_vector( unsigned(d_sum0)/38400);
			  divided_new <= d_sum01(7 downto 0);		
			  avg_flag<='1';
			end if;  
		 end if;
    end if;    
  end process;
  
  --apply threshold and create the vector of features
  thr_features : process(clk, train_flag, avg_flag, th_flag, is_trained, reset)
    variable summer0: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  begin
    if (clk'event and clk = '1') then
	  if(reset = '0') then
	    th_flag<='0';
		  if (train_flag='1' and th_flag='0' and is_trained='1') then
			 if(position /= max_level) then
				if(divided_new > dout_rom0) then
				  holder0(to_integer(unsigned(position))) <= '0'; --black pixel
				else
				  holder0(to_integer(unsigned(position))) <= '1';	
				  ones<= std_logic_vector(unsigned(ones) +1);
				end if;
				position <= std_logic_vector(unsigned(position) +1);
			 else
				position <= std_logic_vector(to_unsigned(0, 9));
				if(ones0 > weight_level)	then
				  features_test(to_integer(unsigned(f_position)))<='1';
				else
				  features_test(to_integer(unsigned(f_position)))<='0';		
				end if;
				f_position<= std_logic_vector(unsigned(f_position) +1);	
				ones0 <= std_logic_vector(to_unsigned(0, 9));
			 end if;	
			 if(f_position = n_features) then
				th_flag <='1';
			 end if;			
		  end if;
		end if;
	end if;
  end process;
  
  -- Compare with first vector of images
  check_vector_1 : process(clk,  th_flag, compare0, reset) 
  begin
    if (clk'event and clk = '1') then
	   if(reset = '0') then
		  compare0 <= '0';
		else
		  if (train_flag='1' and th_flag='1' and compare0='0') then
			if(features_test(to_integer(unsigned(counter0))) = features0(to_integer(unsigned(counter0)))) then
			  matches0 <= std_logic_vector( unsigned(matches0) + 1);
			end if;
			
			if(unsigned(counter0) = unsigned(n_features)) then
			  if(unsigned(matches0) = tolerance) then
				 success <= '1';
				 else
					success <= '0';
				 end if;			
			  compare0 <= '1';
			end if;
		  end if;
		end if;
	end if;
  end process;
  
  check_vector_2 : process(clk,  th_flag, compare2, reset) 
  begin
    if (clk'event and clk = '1') then
	   if(reset = '0') then
		  compare2<='0';
		else
			if (train_flag='1' and th_flag='1' and compare2='0') then
				if(features_test(to_integer(unsigned(counter2))) = features2(to_integer(unsigned(counter2)))) then
			  matches2 <= std_logic_vector( unsigned(matches2) + 1);
			end if;
			
			if(unsigned(counter2) = unsigned(n_features)) then
			  if(unsigned(matches2) = tolerance) then
				 success <= '1';
				 else
					success2 <= '0';
				 end if;			
			  compare2 <= '1';
			end if;
		  end if;
		end if;
	end if;
  end process;
  
  check_vector_3 : process(clk,  th_flag, compare3) 
  begin
    if (clk'event and clk = '1') then
	   if(reset = '0') then
		  compare3<='0';
		else
			if (train_flag='1' and th_flag='1' and compare3='0') then
				if(features_test(to_integer(unsigned(counter3))) = features3(to_integer(unsigned(counter3)))) then
			  matches3 <= std_logic_vector( unsigned(matches3) + 1);
			end if;
			
			if(unsigned(counter3) = unsigned(n_features)) then
			  if(unsigned(matches3) = tolerance) then
				 success3 <= '1';
				 else
					success3 <= '0';
				 end if;			
			  compare3 <= '1';
			end if;
		  end if;
		end if;
	end if;
  end process;
  
  check_vector_4 : process(clk,  th_flag, compare4) 
  begin
    if (clk'event and clk = '1') then
	   if(reset = '0') then
		  compare4<='0';
		else
			if (train_flag='1' and th_flag='1' and compare4='0') then
				if(features_test(to_integer(unsigned(counter4))) = features4(to_integer(unsigned(counter4)))) then
			  matches4 <= std_logic_vector( unsigned(matches4) + 1);
			end if;
			
			if(unsigned(counter4) = unsigned(n_features)) then
			  if(unsigned(matches4) = tolerance) then
				 success4 <= '1';
				 else
					success4 <= '0';
				 end if;			
			  compare4 <= '1';
			end if;
		  end if;
		end if;
	end if;
  end process;
  
  check_vector_5 : process(clk,  th_flag, compare5) 
  begin
    if (clk'event and clk = '1') then
	   if(reset = '0') then
		  compare5<='0';
		else
			if (train_flag='1' and th_flag='1' and compare5='0') then
				if(features_test(to_integer(unsigned(counter5))) = features0(to_integer(unsigned(counter5)))) then
			  matches5 <= std_logic_vector( unsigned(matches5) + 1);
			end if;
			
			if(unsigned(counter5) = unsigned(n_features)) then
			  if(unsigned(matches5) = tolerance) then
				 success5 <= '1';
				 else
					success5 <= '0';
				 end if;			
			  compare5 <= '1';
			end if;
		  end if;
		end if;
	end if;
  end process;
  
  to_vga: process(clk, compare5, compare4, compare3, compare2, compare0)
  begin
    if (clk'event and clk = '1') then
      if (compare5 = '1' and compare4 = '1' and compare3 = '1' and compare2 = '1' and compare0 = '1' ) then
        are_these_glasses <= success5 or success4 or success3 or success2 or success;
	  end if;
	end if;
  end process;
end Structural;