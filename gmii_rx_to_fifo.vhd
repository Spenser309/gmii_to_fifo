----------------------------------------------------------------------------------
-- Engineer: Spenser Gilliland <Spenser309@gmail.com>
-- License: GPLv3
--
-- Description:
-- 	This module extracts the data from an ethernet packet and copies it to a fifo.
-- An ethernet packet comes in five sections in the follwing order.
--
--     enet_packet = <interframe_gap> & <preamble> & <sfd> & <data> & <efd> & <extend>
--
-- where,
--    sfd = start of frame delimeter, 
--    efd = end of frame delimeter.
-- 
-- For proper operation, when an sfd is detected the fifo enable is triggered high and when 
-- the efd occurs the fifo enable is triggered low.
-- 
-- The sfd occurs when data = "10101011" and valid = '1'
-- The efd occurs when valid = '0' but only after an sfd
--
-- It can be seen that the error and data valid signals are included in the input to
-- the fifo.  This allows the application on the other end of the fifo to make decisions 
-- based on packet faults and to know the beginning and end of a packet.
--
-- A state machine was chosen to implement the desired functionality.
-- 
-- State Mapping
--   INIT can be interframe gap, preamble, sfd, efd or extension.
--   RCV is the data section.
--   ERROR is a drop condition during the data section.  Used if FIFO is full.
-- 
-- RX_DV RX_ER  RXD<7:0>      Description            PLS_DATA.indication parameter
--  0     0   00 through FF Normal inter-frame       No applicable parameter
--  0     1         00      Normal inter-frame       No applicable parameter
--  0     1   01 through 0D Reserved                 
--  0     1         0E      False Carrier indication No applicable parameter
--  0     1         0F      Carrier Extend           EXTEND (eight bits)
--  0     1   10 through 1E Reserved                 
--  0     1         1F      Carrier Extend Error     ZERO, ONE (eight bits)
--  0     1   20 through FF Reserved                 
--  1     0   00 through FF Normal data reception    ZERO, ONE (eight bits)
--  1     1   00 through FF Data reception error     ZERO, ONE (eight bits)
--  (from page 15 of IEEE 802.3 section 3 table 35-2)
--
-- Further reading reveals that each of these can be related to a transisitions in state.
--  S    S*    RX_DV RX_ER  RXD<7:0>      Description              PLS_DATA.indication parameter
-- INIT INIT     0     0   00 through FF Normal inter-frame       No applicable parameter
-- INIT INIT     0     1         00      Normal inter-frame       No applicable parameter
--  X    X       0     1   01 through 0D Reserved                 
-- EXT  EXT_D    0     1         0E      False Carrier indication No applicable parameter
-- RCV  EXT      0     1         0F      Carrier Extend           EXTEND (eight bits)
--  X    X       0     1   10 through 1E Reserved                 
-- EXT  EXT_D    0     1         1F      Carrier Extend Error     ZERO, ONE (eight bits)
--  X    X       0     1   20 through FF Reserved                 
-- INIT RCV      1     0   00 through FF Normal data reception    ZERO, ONE (eight bits)  (also requires an sfd)
-- RCV  DROP     1     1   00 through FF Data reception error     ZERO, ONE (eight bits)
--
-- Ignoring Carrier Extensions and therefore half-duplex operation we get the following state diagram. 
--
--  S     S*     Condition                         Output (associated with state)
-- INIT  INIT  no SFD detected                     enable ='0'
-- INIT  RCV   SFD is detected                     enable ='0'
-- INIT  DROP  almost_full or error = '1'          enable ='0'
-- RCV   INIT  when EFD is detected (valid ='0')   enable ='1'
-- RCV   RCV   when valid '1'                      enable ='1'
-- RCV   DROP  almost_full or error = '1'          enable ='1'
-- DROP  INIT  when EFD is detected (valid = '0')  enable ='0'
-- DROP  RCV   never                               enable ='0'
-- DROP  DROP  when valid '1'                      enable ='0'
--
--
-- Notes:  This implementation completely ignores the idea that carrier extensions
--         exist or the ability of gmii to work in half-duplex operation. 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity gmii_rx_to_fifo is
Port (
      ------------------------------------------------------------------
      -- GMII Interface
      ------------------------------------------------------------------
      gmii_rx_clk          : in    std_logic;									-- Receive clock to client MAC.
      gmii_rxd             : in    std_logic_vector(7 downto 0);		-- Received Data to client MAC.
      gmii_rx_dv           : in    std_logic;									-- Received control signal to client MAC.
      gmii_rx_er           : in    std_logic;									-- Received control signal to client MAC.
      ------------------------------------------------------------------
      -- FIFO Interface
      ------------------------------------------------------------------		
		fifo_din					: out   std_logic_VECTOR(9 downto 0);
		fifo_wr_clk				: out   std_logic;
		fifo_wr_en				: out   std_logic;
		fifo_almost_full		: in    std_logic
 );
end gmii_rx_to_fifo;

architecture Behavioral of gmii_rx_to_fifo is

type df_states is ( INIT,   -- This is the idle state. Used for the interframe gap and preamble. 
						  RCV,    -- This is the recieve state.  Used for the reception of good data.
						  DROP ); -- This is the drop packet state.  Used when an error occurs in good data.

alias clock						: std_logic is gmii_rx_clk;

alias data						: std_logic_vector(7 downto 0) is gmii_rxd(7 downto 0);
alias valid						: std_logic is gmii_rx_dv;
alias error						: std_logic is gmii_rx_er;
alias almost_full				: std_logic is fifo_almost_full;
alias enable					: std_logic is fifo_wr_en;

signal state 					: df_states := INIT;

begin
	-- Connect recovered clock to fifo
	fifo_wr_clk <= gmii_rx_clk;
	-- Connect data lines
	
	fifo_din(7 downto 0) <= data;
	fifo_din(8) <= error;
	fifo_din(9) <= valid;
	
	-- State machine that does the deframing
	NEXT_STATE_LOGIC: process(clock,data,valid,error,almost_full,state)
	begin
		if rising_edge(clock) then
			case state is
				when INIT =>
					if (data = "10101011") and (valid = '1') then
						if (almost_full = '0') then
							state <= RCV;
						else
							state <= DROP;  -- If the FIFO is full I have to drop the entire packet
						end if;
					else
						state <= INIT;
					end if;
				when RCV  =>
					if (valid = '0') then
					   -- carrier extenstion logic would go here
						state <= INIT;
					else 
						if(almost_full = '1') or (error = '1') then
							state <= DROP; -- If the fifo becomes full mid packet then I have to drop
							               -- the remainder of the packet.  The packet should be errored out due
										   -- to its lack of an FCS and should be dropped by the MAC layer.
							report "DROP: Dropping packet with error= " & error & " and almost_full= " & almost_full severity NOTE;
						else
							state <= RCV;
						end if;
					end if;
				when DROP => 
					if (valid = '0') then
						state <= INIT;
					else
						state <= DROP; 
					end if;
				when others =>
					state <= INIT; -- Uhh ohh.  Seriously there was a bad bit flip here.
		            report  "FAIL: Reached Error State" severity FAILURE;
			end case;
		end if;
	end process;

	OUTPUT_LOGIC: process(state)
	begin
		case state is
			when RCV 	=> enable <= '1';
			when others => enable <= '0';
		end case;
	end process;

end Behavioral;

