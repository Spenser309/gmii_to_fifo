----------------------------------------------------------------------------------
-- Engineer: Spenser Gilliland <Spenser309@gmail.com>
-- License: GPLv3
----------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY t_gmii_rx_to_fifo is
end t_gmii_rx_to_fifo;

architecture behavior of t_gmii_rx_to_fifo is 
	
	constant clk_period: time :=  13.333333 ns;

	-- Component Declaration for the Unit Under Test (UUT)
	component gmii_rx_to_fifo
	port(
		gmii_rx_clk : in std_logic;
		gmii_rxd : in std_logic_vector(7 downto 0);
		gmii_rx_dv : in std_logic;
		gmii_rx_er : in std_logic;
		fifo_almost_full : in std_logic;          
		fifo_din : out std_logic_vector(9 downto 0);
		fifo_wr_clk : out std_logic;
		fifo_wr_en : out std_logic
		);
	end component;

	--Inputs
	signal gmii_rx_clk :  std_logic := '0';
	signal gmii_rx_dv :  std_logic := '0';
	signal gmii_rx_er :  std_logic := '0';
	signal fifo_almost_full :  std_logic := '0';
	signal gmii_rxd :  std_logic_vector(7 downto 0) := (others=>'0');

	--Outputs
	signal fifo_din :  std_logic_vector(9 downto 0);
	signal fifo_wr_clk :  std_logic;
	signal fifo_wr_en :  std_logic;

	alias  fifo_dv: std_logic is fifo_din(9);
	alias  fifo_er: std_logic is fifo_din(8);
begin

	-- Instantiate the Unit Under Test (UUT)
	uut: gmii_rx_to_fifo port map(
		gmii_rx_clk => gmii_rx_clk,
		gmii_rxd => gmii_rxd,
		gmii_rx_dv => gmii_rx_dv,
		gmii_rx_er => gmii_rx_er,
		fifo_din => fifo_din,
		fifo_wr_clk => fifo_wr_clk,
		fifo_wr_en => fifo_wr_en,
		fifo_almost_full => fifo_almost_full
	);
	

	
	clock_gen: process is
	begin
		gmii_rx_clk <= '0'; 
		wait for 0.5*clk_period;
		gmii_rx_clk <= '1';
		wait for 0.5*clk_period;
	end process;
		
	tb : process
	begin
		-- Wait 100 ns for global reset to finish
		wait for 100 ns;


		wait; -- will wait forever
	end process;

end;
