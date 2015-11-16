library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity training is
  Port ( clk : in  STD_LOGIC; -- FPGA's external oscillator
    enable: in std_logic;
	done : out std_logic;
   f0, f2, f3, f4, f5 : out  STD_LOGIC_VECTOR (99 downto 0)
 ); 
end training;

architecture Structural of training is

  component train0 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;

  component train2 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;
  
  component train3 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;

  component train4 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;
  
  component train5 IS
  PORT (
    a : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
  END component;

  constant MAX_VALUE: STD_LOGIC_VECTOR(23 downto 0):= x"95FFFF"; --38400x256
  signal my_addr_counter : STD_LOGIC_VECTOR (15 downto 0) := x"0000";
  signal dout_rom0, dout_rom2, dout_rom3, dout_rom4, dout_rom5: STD_LOGIC_VECTOR(7 downto 0);
  signal doing: std_logic:='0';
  signal d_sum0, d_sum2, d_sum3, d_sum4, d_sum5: std_logic_vector(23 downto 0):=x"000000";
  signal train_flag, avg_flag, th_flag, th_flag2, th_flag3, th_flag4, th_flag5: std_logic:='0';
  
  --registered outputs
  signal d_sum0_new, d_sum2_new, d_sum3_new, d_sum4_new, d_sum5_new: std_logic_vector(23 downto 0);
  signal divided_new, divided_new2, divided_new3, divided_new4, divided_new5: std_logic_vector(7 downto 0);
  
  constant n_features: std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(99, 9));
  
  signal features0, features2, features3, features4, features5 : std_logic_vector(99 downto 0); -- we are convolving boxes of 24x16 pixels 
  signal holder0, holder2, holder3, holder4, holder5 : std_logic_vector(383 downto 0); 
  signal position, f_position, ones: STD_LOGIC_VECTOR(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  signal position2, f_position2, ones2: STD_LOGIC_VECTOR(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  signal position3, f_position3, ones3: STD_LOGIC_VECTOR(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  signal position4, f_position4, ones4: STD_LOGIC_VECTOR(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  signal position5, f_position5, ones5: STD_LOGIC_VECTOR(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  constant max_level : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(383, 9));
  constant weight_level : std_logic_vector(8 downto 0) := std_logic_vector(to_unsigned(192, 9));
  
begin
  memory0 : train0 port map (a => my_addr_counter, spo => dout_rom0); 
  memory2 : train2 port map (a => my_addr_counter, spo => dout_rom2); 
  memory3 : train3 port map (a => my_addr_counter, spo => dout_rom3); 
  memory4 : train4 port map (a => my_addr_counter, spo => dout_rom4); 
  memory5 : train5 port map (a => my_addr_counter, spo => dout_rom5); 
  --Lower section of FSM

  addr: process (clk, train_flag, th_flag, enable)
  begin
    if (clk'event and clk = '1') then
      if ( ((train_flag='0' and th_flag='0') or (train_flag='1' and th_flag='0')) and enable ='0') then
        my_addr_counter <= std_logic_vector( unsigned(my_addr_counter) + 1);
		else
		  my_addr_counter<=x"0000";  
		end if;
	 end if;
  end process;
  
  avg : process (clk, train_flag, enable) is
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='0' and enable ='0') then
	    d_sum0 <= std_logic_vector(unsigned(d_sum0) + unsigned("00000000" & dout_rom0));
		d_sum2 <= std_logic_vector(unsigned(d_sum2) + unsigned("00000000" & dout_rom2));
		d_sum3 <= std_logic_vector(unsigned(d_sum3) + unsigned("00000000" & dout_rom3));
		d_sum4 <= std_logic_vector(unsigned(d_sum4) + unsigned("00000000" & dout_rom4));
		d_sum5 <= std_logic_vector(unsigned(d_sum5) + unsigned("00000000" & dout_rom5));
	    if(my_addr_counter =x"95FF") then
	      train_flag<='1';      
		 end if;
	  end if;  
	  d_sum0_new<=d_sum0;
	  d_sum2_new<=d_sum2;
	  d_sum3_new<=d_sum3;
	  d_sum4_new <=d_sum4;
	  d_sum5_new<=d_sum5;
    end if;
  end process; 
  
  div : process(clk, train_flag, avg_flag, enable)
    variable d_sum01, d_sum21, d_sum31, d_sum41, d_sum51: std_logic_vector(23 downto 0);
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='1' and avg_flag='0' and enable ='0') then
	    d_sum01 :=  std_logic_vector( unsigned(d_sum0)/38400);
		d_sum21 := std_logic_vector( unsigned(d_sum2)/38400);
		d_sum31 := std_logic_vector( unsigned(d_sum3)/38400);
		d_sum41 := std_logic_vector( unsigned(d_sum4)/38400);
		d_sum51 := std_logic_vector( unsigned(d_sum5)/38400);
		
		divided_new <= d_sum01(7 downto 0);
		divided_new2 <= d_sum21(7 downto 0);
		divided_new3 <= d_sum31(7 downto 0);
		divided_new4 <= d_sum41(7 downto 0);
		divided_new5 <= d_sum51(7 downto 0);
		
		avg_flag<='1';
	  end if;  
    end if;    
  end process;
  
  thr_train0 : process(clk, train_flag, avg_flag, th_flag, enable)
    variable summer0: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='1' and th_flag='0' and enable ='0') then
	    if(unsigned(position) /= unsigned(max_level)) then
	      if(unsigned(divided_new) > unsigned(dout_rom0)) then
		     holder0(to_integer(unsigned(position))) <= '0'; --black pixel
         else
           holder0(to_integer(unsigned(position))) <= '1';	
			  ones<= std_logic_vector(unsigned(ones) +1);
         end if;
         position <= std_logic_vector(unsigned(position) +1);
       else
         position <= std_logic_vector(to_unsigned(0, 9));
         if(unsigned(ones) > unsigned(weight_level))	then
           features0(to_integer(unsigned(f_position)))<='1';
         else
           features0(to_integer(unsigned(f_position)))<='0';		
         end if;
         f_position<= std_logic_vector(unsigned(f_position) +1);	
			ones <= std_logic_vector(to_unsigned(0, 9));
       end if;	
       if(unsigned(f_position) = unsigned(n_features)) then
         th_flag <='1';
       end if;			
	  end if;
	end if;
  end process;
  
  thr_train3 : process(clk, train_flag, avg_flag, th_flag3, enable)
    variable summer3: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='1' and th_flag3='0' and enable ='0') then
	    if(unsigned(position3) /= unsigned(max_level)) then
	      if(unsigned(divided_new3) > unsigned(dout_rom3)) then
		     holder3(to_integer(unsigned(position3))) <= '0'; --black pixel
         else
           holder3(to_integer(unsigned(position3))) <= '1';	
			  ones3<= std_logic_vector(unsigned(ones3) +1);
         end if;
         position3 <= std_logic_vector(unsigned(position3) +1);
       else
         position3 <= std_logic_vector(to_unsigned(0, 9));
         if(unsigned(ones3) > unsigned(weight_level))	then
           features3(to_integer(unsigned(f_position3)))<='1';
         else
           features3(to_integer(unsigned(f_position3)))<='0';		
         end if;
         f_position3<= std_logic_vector(unsigned(f_position3) +1);	
			ones3 <= std_logic_vector(to_unsigned(0, 9));
       end if;	
       if(unsigned(f_position3) = unsigned(n_features)) then
         th_flag3 <='1';
       end if;			
	  end if;
	end if;
  end process;
  
   thr_train2 : process(clk, train_flag, avg_flag, th_flag2, enable)
    variable summer2: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='1' and th_flag2='0' and enable ='0') then
	    if(unsigned(position2) /= unsigned(max_level)) then
	      if(unsigned(divided_new2) > unsigned(dout_rom2)) then
		     holder2(to_integer(unsigned(position2))) <= '0'; --black pixel
         else
           holder2(to_integer(unsigned(position2))) <= '1';	
			  ones2<= std_logic_vector(unsigned(ones2) +1);
         end if;
         position2 <= std_logic_vector(unsigned(position2) +1);
       else
         position2 <= std_logic_vector(to_unsigned(0, 9));
         if(unsigned(ones2) > unsigned(weight_level))	then
           features2(to_integer(unsigned(f_position2)))<='1';
         else
           features2(to_integer(unsigned(f_position2)))<='0';		
         end if;
         f_position2<= std_logic_vector(unsigned(f_position2) +1);	
			ones2 <= std_logic_vector(to_unsigned(0, 9));
       end if;	
       if(unsigned(f_position2) = unsigned(n_features)) then
         th_flag2 <='1';
       end if;			
	  end if;
	end if;
  end process;
  
     thr_train4 : process(clk, train_flag, avg_flag, th_flag4, enable)
    variable summer4: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='1' and th_flag4='0' and enable ='0') then
	    if(unsigned(position4) /= unsigned(max_level)) then
	      if(unsigned(divided_new4) > unsigned(dout_rom4)) then
		     holder4(to_integer(unsigned(position4))) <= '0'; --black pixel
         else
           holder4(to_integer(unsigned(position4))) <= '1';	
			  ones4<= std_logic_vector(unsigned(ones4) +1);
         end if;
         position4 <= std_logic_vector(unsigned(position4) +1);
       else
         position4 <= std_logic_vector(to_unsigned(0, 9));
         if(unsigned(ones4) > unsigned(weight_level))	then
           features4(to_integer(unsigned(f_position4)))<='1';
         else
           features4(to_integer(unsigned(f_position4)))<='0';		
         end if;
         f_position4<= std_logic_vector(unsigned(f_position4) +1);	
			ones4 <= std_logic_vector(to_unsigned(0, 9));
       end if;	
       if(unsigned(f_position4) = unsigned(n_features)) then
         th_flag4 <='1';
       end if;			
	  end if;
	end if;
  end process;
  
     thr_train5 : process(clk, train_flag, avg_flag, th_flag5, enable)
    variable summer5: std_logic_vector(8 downto 0):=std_logic_vector(to_unsigned(0, 9));
  begin
    if (clk'event and clk = '1') then
	  if (train_flag='1' and th_flag5='0' and enable ='0') then
	    if(unsigned(position5) /= unsigned(max_level)) then
	      if(unsigned(divided_new5) > unsigned(dout_rom5)) then
		     holder5(to_integer(unsigned(position5))) <= '0'; --black pixel
         else
           holder5(to_integer(unsigned(position5))) <= '1';	
			  ones5<= std_logic_vector(unsigned(ones5) +1);
         end if;
         position5 <= std_logic_vector(unsigned(position5) +1);
       else
         position5 <= std_logic_vector(to_unsigned(0, 9));
         if(unsigned(ones5) > unsigned(weight_level))	then
           features5(to_integer(unsigned(f_position5)))<='1';
         else
           features5(to_integer(unsigned(f_position5)))<='0';		
         end if;
         f_position5<= std_logic_vector(unsigned(f_position5) +1);	
			ones5 <= std_logic_vector(to_unsigned(0, 9));
       end if;	
       if(unsigned(f_position5) = unsigned(n_features)) then
         th_flag5 <='1';
       end if;			
	  end if;
	end if;
  end process;
  -- register outputs
  process(clk, th_flag3, th_flag2, th_flag4, th_flag5, th_flag, enable)
  begin
    if (clk'event and clk = '1') then
	  if(th_flag3='1' and th_flag2='1' and th_flag4='1' and th_flag5='1' and th_flag='1' and enable ='0') then
	    done <= '1';
		f0 <= features0; f2 <= features2; f3 <= features3;  f4 <= features4;  f5 <= features5;
	  else
	    done <= '0';
	  end if;
    end if;
  end process;
  
end Structural;