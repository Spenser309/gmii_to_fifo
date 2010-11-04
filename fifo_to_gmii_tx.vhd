----------------------------------------------------------------------------------
-- Engineer: Spenser Gilliland <Spenser309@gmail.com>
-- License: GPLv3
--
-- Description:
-- 	This module extracts the data from a fifo and transmits it as an ethernet packet.
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity fifo_to_gmii_tx is
Port (
		brefclk					: in    std_logic;									-- Very low jitter transmission clock
      ------------------------------------------------------------------
      -- GMII Interfaces
      ------------------------------------------------------------------
      gmii_tx_clk          : out   std_logic;                     		-- Transmit clock from client MAC.
		gmii_txd             : out   std_logic_vector(7 downto 0);			-- Transmit data from client MAC.
      gmii_tx_en           : out   std_logic;									-- Transmit control signal from client MAC.
      gmii_tx_er           : out   std_logic;									-- Transmit control signal from client MAC.
     ------------------------------------------------------------------
      -- FIFO Interface
      ------------------------------------------------------------------		
		fifo_dout				: in   std_logic_VECTOR(9 downto 0);			-- Data out from the FIFO
		fifo_rd_clk				: out  std_logic;										-- FIFO Read clock (will be assigned to brefclk)
		fifo_rd_en				: out  std_logic;										-- FIFO Read Enable
		fifo_empty				: in   std_logic										-- FIFO Empty
);
end fifo_to_gmii_tx;

architecture Behavioral of fifo_to_gmii_tx is

begin


end Behavioral;

