// ============================================================================
// B. Joly, Laboratoire de Physique de Clermont
//
//-------------------------------------------------------------------
// 					TIME TAGGER, version 21.03.18 (dd.mm.yy)
//-------------- ----------------------------------------------------
// * program targeting a DE0-nano-Soc board
// equipped with the "Multiconnector" mezzanine (LPC).
// * use cases: 
//		1. record the timestamp of detector events in the time referential		 
//			of Tomuvol electronics (counter on a 5 MHz clock)
//		2. "send" the timestamp continuously, in a serial way, 
//			to an oscilloscope, to correlate captured RPC pulses with 
//			traces acquired by Tomuvol chambers (test bench)
// * functionality (in brief):
//		- receives and executes synchronisation commands from DCC
// 		- handles a coarse timestamp counter, reset by a DCC command, and 
//	incremented on 5 MHz clk from DCC
//		- handles a fine timestamp counter (clock 250 MHz)
//		- receives 2 discriminator signals from scintillator planes 
//		("single_L1", "single_L2")
//		- receives 1 trigger (coinc of the 2 above)
//		- when a trigger occurs, stores in registers
//			- the coarse timestamp of "trigger"
//			- the fine timestamp of "single_L1", "single_L2" and "trigger"
//		- implements a handshaking mechanism with the HPS for data transfer
//			event per event
//		- encodes serially the timestamp, every 5MHz clk cycle, 
//		using the 250 MHz clock, to view/save on an oscilloscope
//
//
//
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Tue Dec  2 09:28:38 2014
// ============================================================================


//`define ENABLE_ADC
//`define ENABLE_ARDUINO
//`define ENABLE_CLK
`define ENABLE_GPIO_0
//`define ENABLE_GPIO_1
`define ENABLE_HPS

module ghrd(
`ifdef ENABLE_ADC
      ///////// ADC /////////
      output             ADC_CONVST,
      output             ADC_SCK,
      output             ADC_SDI,
      input              ADC_SDO,
`endif
`ifdef ENABLE_ARDUINO
      ///////// ARDUINO /////////
      inout       [15:0] ARDUINO_IO,
      inout              ARDUINO_RESET_N,
`endif

`ifdef ENABLE_CLK
      ///////// CLK /////////
      output             CLK_I2C_SCL,
      inout              CLK_I2C_SDA,
`endif /*ENABLE_CLK*/

      ///////// FPGA /////////
      input              FPGA_CLK1_50,
      input              FPGA_CLK2_50,
      input              FPGA_CLK3_50,

      ///////// GPIO /////////
`ifdef ENABLE_GPIO_0
      inout       [35:0] GPIO_0,
`endif		
`ifdef ENABLE_GPIO_1		
      inout       [35:0] GPIO_1,
`endif

`ifdef ENABLE_HPS
      ///////// HPS /////////
      inout              HPS_CONV_USB_N,
      output      [14:0] HPS_DDR3_ADDR,
      output      [2:0]  HPS_DDR3_BA,
      output             HPS_DDR3_CAS_N,
      output             HPS_DDR3_CKE,
      output             HPS_DDR3_CK_N,
      output             HPS_DDR3_CK_P,
      output             HPS_DDR3_CS_N,
      output      [3:0]  HPS_DDR3_DM,
      inout       [31:0] HPS_DDR3_DQ,
      inout       [3:0]  HPS_DDR3_DQS_N,
      inout       [3:0]  HPS_DDR3_DQS_P,
      output             HPS_DDR3_ODT,
      output             HPS_DDR3_RAS_N,
      output             HPS_DDR3_RESET_N,
      input              HPS_DDR3_RZQ,
      output             HPS_DDR3_WE_N,
      output             HPS_ENET_GTX_CLK,
      inout              HPS_ENET_INT_N,
      output             HPS_ENET_MDC,
      inout              HPS_ENET_MDIO,
      input              HPS_ENET_RX_CLK,
      input       [3:0]  HPS_ENET_RX_DATA,
      input              HPS_ENET_RX_DV,
      output      [3:0]  HPS_ENET_TX_DATA,
      output             HPS_ENET_TX_EN,
      inout              HPS_GSENSOR_INT,
      inout              HPS_I2C0_SCLK,
      inout              HPS_I2C0_SDAT,
      inout              HPS_I2C1_SCLK,
      inout              HPS_I2C1_SDAT,
      inout              HPS_KEY,
      inout              HPS_LED,
      inout              HPS_LTC_GPIO,
      output             HPS_SD_CLK,
      inout              HPS_SD_CMD,
      inout       [3:0]  HPS_SD_DATA,
      output             HPS_SPIM_CLK,
      input              HPS_SPIM_MISO,
      output             HPS_SPIM_MOSI,
      inout              HPS_SPIM_SS,
      input              HPS_UART_RX,
      output             HPS_UART_TX,
      input              HPS_USB_CLKOUT,
      inout       [7:0]  HPS_USB_DATA,
      input              HPS_USB_DIR,
      input              HPS_USB_NXT,
      output             HPS_USB_STP,
`endif /*ENABLE_HPS*/

      ///////// KEY /////////
      input       [1:0]  KEY,

      ///////// LED /////////
      output      [7:0]  LED,

      ///////// SW /////////
      input       [3:0]  SW
);


//=======================================================
// 					TERASIC WIRES
//=======================================================
wire  hps_fpga_reset_n;
wire 		  fpga_clk_50;

`ifdef ENABLE_HPS
wire [1:0] fpga_debounced_buttons;
wire [6:0]  fpga_led_internal;
wire [2:0]  hps_reset_req;
wire        hps_cold_reset;
wire        hps_warm_reset;
wire        hps_debug_reset;
wire [27:0] stm_hw_events;
`endif


//=======================================================
//  				USER WIRES		
//=======================================================

wire clk_5, clk_250;
wire cmd_reset, reset_all;
wire pll_lock;

wire [31:0] data[7:0];
wire [31:0] command[7:0];

wire single_L1_test, single_L2_test, trigger_test;
wire dcc_test;
reg single_L1, single_L2, trigger;
reg dcc_data_in; 


//=======================================================
// 					SOC
//=======================================================
`ifdef ENABLE_HPS
 soc_system u0 (
		//Clock&Reset
	  .clk_clk                               (FPGA_CLK1_50 ),                               //                            clk.clk
	  .reset_reset_n                         (hps_fpga_reset_n ),                         //                          reset.reset_n
	  //HPS ddr3
	  .memory_mem_a                          ( HPS_DDR3_ADDR),                       //                memory.mem_a
	  .memory_mem_ba                         ( HPS_DDR3_BA),                         //                .mem_ba
	  .memory_mem_ck                         ( HPS_DDR3_CK_P),                       //                .mem_ck
	  .memory_mem_ck_n                       ( HPS_DDR3_CK_N),                       //                .mem_ck_n
	  .memory_mem_cke                        ( HPS_DDR3_CKE),                        //                .mem_cke
	  .memory_mem_cs_n                       ( HPS_DDR3_CS_N),                       //                .mem_cs_n
	  .memory_mem_ras_n                      ( HPS_DDR3_RAS_N),                      //                .mem_ras_n
	  .memory_mem_cas_n                      ( HPS_DDR3_CAS_N),                      //                .mem_cas_n
	  .memory_mem_we_n                       ( HPS_DDR3_WE_N),                       //                .mem_we_n
	  .memory_mem_reset_n                    ( HPS_DDR3_RESET_N),                    //                .mem_reset_n
	  .memory_mem_dq                         ( HPS_DDR3_DQ),                         //                .mem_dq
	  .memory_mem_dqs                        ( HPS_DDR3_DQS_P),                      //                .mem_dqs
	  .memory_mem_dqs_n                      ( HPS_DDR3_DQS_N),                      //                .mem_dqs_n
	  .memory_mem_odt                        ( HPS_DDR3_ODT),                        //                .mem_odt
	  .memory_mem_dm                         ( HPS_DDR3_DM),                         //                .mem_dm
	  .memory_oct_rzqin                      ( HPS_DDR3_RZQ),                        //                .oct_rzqin                                  
	  //HPS ethernet		
	  .hps_0_hps_io_hps_io_emac1_inst_TX_CLK ( HPS_ENET_GTX_CLK),       //                             hps_0_hps_io.hps_io_emac1_inst_TX_CLK
	  .hps_0_hps_io_hps_io_emac1_inst_TXD0   ( HPS_ENET_TX_DATA[0] ),   //                             .hps_io_emac1_inst_TXD0
	  .hps_0_hps_io_hps_io_emac1_inst_TXD1   ( HPS_ENET_TX_DATA[1] ),   //                             .hps_io_emac1_inst_TXD1
	  .hps_0_hps_io_hps_io_emac1_inst_TXD2   ( HPS_ENET_TX_DATA[2] ),   //                             .hps_io_emac1_inst_TXD2
	  .hps_0_hps_io_hps_io_emac1_inst_TXD3   ( HPS_ENET_TX_DATA[3] ),   //                             .hps_io_emac1_inst_TXD3
	  .hps_0_hps_io_hps_io_emac1_inst_RXD0   ( HPS_ENET_RX_DATA[0] ),   //                             .hps_io_emac1_inst_RXD0
	  .hps_0_hps_io_hps_io_emac1_inst_MDIO   ( HPS_ENET_MDIO ),         //                             .hps_io_emac1_inst_MDIO
	  .hps_0_hps_io_hps_io_emac1_inst_MDC    ( HPS_ENET_MDC  ),         //                             .hps_io_emac1_inst_MDC
	  .hps_0_hps_io_hps_io_emac1_inst_RX_CTL ( HPS_ENET_RX_DV),         //                             .hps_io_emac1_inst_RX_CTL
	  .hps_0_hps_io_hps_io_emac1_inst_TX_CTL ( HPS_ENET_TX_EN),         //                             .hps_io_emac1_inst_TX_CTL
	  .hps_0_hps_io_hps_io_emac1_inst_RX_CLK ( HPS_ENET_RX_CLK),        //                             .hps_io_emac1_inst_RX_CLK
	  .hps_0_hps_io_hps_io_emac1_inst_RXD1   ( HPS_ENET_RX_DATA[1] ),   //                             .hps_io_emac1_inst_RXD1
	  .hps_0_hps_io_hps_io_emac1_inst_RXD2   ( HPS_ENET_RX_DATA[2] ),   //                             .hps_io_emac1_inst_RXD2
	  .hps_0_hps_io_hps_io_emac1_inst_RXD3   ( HPS_ENET_RX_DATA[3] ),   //                             .hps_io_emac1_inst_RXD3		  
	  //HPS SD card 
	  .hps_0_hps_io_hps_io_sdio_inst_CMD     ( HPS_SD_CMD    ),           //                               .hps_io_sdio_inst_CMD
	  .hps_0_hps_io_hps_io_sdio_inst_D0      ( HPS_SD_DATA[0]     ),      //                               .hps_io_sdio_inst_D0
	  .hps_0_hps_io_hps_io_sdio_inst_D1      ( HPS_SD_DATA[1]     ),      //                               .hps_io_sdio_inst_D1
	  .hps_0_hps_io_hps_io_sdio_inst_CLK     ( HPS_SD_CLK   ),            //                               .hps_io_sdio_inst_CLK
	  .hps_0_hps_io_hps_io_sdio_inst_D2      ( HPS_SD_DATA[2]     ),      //                               .hps_io_sdio_inst_D2
	  .hps_0_hps_io_hps_io_sdio_inst_D3      ( HPS_SD_DATA[3]     ),      //                               .hps_io_sdio_inst_D3
	  //HPS USB 		  
	  .hps_0_hps_io_hps_io_usb1_inst_D0      ( HPS_USB_DATA[0]    ),      //                               .hps_io_usb1_inst_D0
	  .hps_0_hps_io_hps_io_usb1_inst_D1      ( HPS_USB_DATA[1]    ),      //                               .hps_io_usb1_inst_D1
	  .hps_0_hps_io_hps_io_usb1_inst_D2      ( HPS_USB_DATA[2]    ),      //                               .hps_io_usb1_inst_D2
	  .hps_0_hps_io_hps_io_usb1_inst_D3      ( HPS_USB_DATA[3]    ),      //                               .hps_io_usb1_inst_D3
	  .hps_0_hps_io_hps_io_usb1_inst_D4      ( HPS_USB_DATA[4]    ),      //                               .hps_io_usb1_inst_D4
	  .hps_0_hps_io_hps_io_usb1_inst_D5      ( HPS_USB_DATA[5]    ),      //                               .hps_io_usb1_inst_D5
	  .hps_0_hps_io_hps_io_usb1_inst_D6      ( HPS_USB_DATA[6]    ),      //                               .hps_io_usb1_inst_D6
	  .hps_0_hps_io_hps_io_usb1_inst_D7      ( HPS_USB_DATA[7]    ),      //                               .hps_io_usb1_inst_D7
	  .hps_0_hps_io_hps_io_usb1_inst_CLK     ( HPS_USB_CLKOUT    ),       //                               .hps_io_usb1_inst_CLK
	  .hps_0_hps_io_hps_io_usb1_inst_STP     ( HPS_USB_STP    ),          //                               .hps_io_usb1_inst_STP
	  .hps_0_hps_io_hps_io_usb1_inst_DIR     ( HPS_USB_DIR    ),          //                               .hps_io_usb1_inst_DIR
	  .hps_0_hps_io_hps_io_usb1_inst_NXT     ( HPS_USB_NXT    ),          //                               .hps_io_usb1_inst_NXT
		//HPS SPI 		  
	  .hps_0_hps_io_hps_io_spim1_inst_CLK    ( HPS_SPIM_CLK  ),           //                               .hps_io_spim1_inst_CLK
	  .hps_0_hps_io_hps_io_spim1_inst_MOSI   ( HPS_SPIM_MOSI ),           //                               .hps_io_spim1_inst_MOSI
	  .hps_0_hps_io_hps_io_spim1_inst_MISO   ( HPS_SPIM_MISO ),           //                               .hps_io_spim1_inst_MISO
	  .hps_0_hps_io_hps_io_spim1_inst_SS0    ( HPS_SPIM_SS   ),             //                               .hps_io_spim1_inst_SS0
		//HPS UART		
	  .hps_0_hps_io_hps_io_uart0_inst_RX     ( HPS_UART_RX   ),          //                               .hps_io_uart0_inst_RX
	  .hps_0_hps_io_hps_io_uart0_inst_TX     ( HPS_UART_TX   ),          //                               .hps_io_uart0_inst_TX
		//HPS I2C1
	  .hps_0_hps_io_hps_io_i2c0_inst_SDA     ( HPS_I2C0_SDAT  ),        //                               .hps_io_i2c0_inst_SDA
	  .hps_0_hps_io_hps_io_i2c0_inst_SCL     ( HPS_I2C0_SCLK  ),        //                               .hps_io_i2c0_inst_SCL
		//HPS I2C2
	  .hps_0_hps_io_hps_io_i2c1_inst_SDA     ( HPS_I2C1_SDAT  ),        //                               .hps_io_i2c1_inst_SDA
	  .hps_0_hps_io_hps_io_i2c1_inst_SCL     ( HPS_I2C1_SCLK  ),        //                               .hps_io_i2c1_inst_SCL
		//GPIO 
	  .hps_0_hps_io_hps_io_gpio_inst_GPIO09  ( HPS_CONV_USB_N ),  //                               .hps_io_gpio_inst_GPIO09
	  .hps_0_hps_io_hps_io_gpio_inst_GPIO35  ( HPS_ENET_INT_N ),  //                               .hps_io_gpio_inst_GPIO35
	  .hps_0_hps_io_hps_io_gpio_inst_GPIO40  ( HPS_LTC_GPIO   ),  //                               .hps_io_gpio_inst_GPIO40
	  .hps_0_hps_io_hps_io_gpio_inst_GPIO53  ( HPS_LED   ),  //                               .hps_io_gpio_inst_GPIO53
	  .hps_0_hps_io_hps_io_gpio_inst_GPIO54  ( HPS_KEY   ),  //                               .hps_io_gpio_inst_GPIO54
	  .hps_0_hps_io_hps_io_gpio_inst_GPIO61  ( HPS_GSENSOR_INT ),  //                               .hps_io_gpio_inst_GPIO61
		//FPGA Partion	  
	  .dipsw_pio_external_connection_export  ( SW	),  //  dipsw_pio_external_connection.export
	  .button_pio_external_connection_export ( fpga_debounced_buttons	), // button_pio_external_connection.export
	  .hps_0_h2f_reset_reset_n               ( hps_fpga_reset_n ),                //                hps_0_h2f_reset.reset_n
	  .hps_0_f2h_cold_reset_req_reset_n      (~hps_cold_reset ),      //       hps_0_f2h_cold_reset_req.reset_n
     .hps_0_f2h_debug_reset_req_reset_n     (~hps_debug_reset ),     //      hps_0_f2h_debug_reset_req.reset_n
     .hps_0_f2h_stm_hw_events_stm_hwevents  (stm_hw_events ),  //        hps_0_f2h_stm_hw_events.stm_hwevents
     .hps_0_f2h_warm_reset_req_reset_n      (~hps_warm_reset ),      //       hps_0_f2h_warm_reset_req.reset_n
	  //slave template
	  .slave_interface_dataout_8             (command[0]),            
     .slave_interface_dataout_9             (command[1]),          
     .slave_interface_dataout_10            (command[2]),            
     .slave_interface_dataout_11            (command[3]),           
     .slave_interface_dataout_12            (command[4]),           
     .slave_interface_dataout_13            (command[5]),            
     .slave_interface_dataout_14            (command[6]),            
     .slave_interface_dataout_15            (command[7]),           
     .slave_interface_datain_0              (data[0]),             
     .slave_interface_datain_1              (data[1]),         
     .slave_interface_datain_2              (data[2]),
     .slave_interface_datain_3              (data[3]),        
     .slave_interface_datain_4              (data[4]),
     .slave_interface_datain_5              (data[5]),
     .slave_interface_datain_6              (data[6]),
     .slave_interface_datain_7              (data[7])

 );
`endif
 
 
 
//=======================================================
// 					TERASIC CODE / ARCHITECTURE
//=======================================================   
 
 // connection of internal logics  
assign fpga_clk_50=FPGA_CLK1_50;

`ifdef ENABLE_HPS
assign stm_hw_events    = {{15{1'b0}}, SW, fpga_led_internal, fpga_debounced_buttons};


// Debounce logic to clean out glitches within 1ms
debounce debounce_inst (
  .clk                                  (fpga_clk_50),
  .reset_n                              (hps_fpga_reset_n),  
  .data_in                              (KEY),
  .data_out                             (fpga_debounced_buttons)
);
defparam debounce_inst.WIDTH = 2;
defparam debounce_inst.POLARITY = "LOW";
defparam debounce_inst.TIMEOUT = 50000;               // at 50Mhz this is a debounce time of 1ms
defparam debounce_inst.TIMEOUT_WIDTH = 16;            // ceil(log2(TIMEOUT))
  
// Source/Probe megawizard instance
hps_reset hps_reset_inst (
  .source_clk (fpga_clk_50),
  .source     (hps_reset_req)
);

altera_edge_detector pulse_cold_reset (
  .clk       (fpga_clk_50),
  .rst_n     (hps_fpga_reset_n),
  .signal_in (hps_reset_req[0]),
  .pulse_out (hps_cold_reset)
);
defparam pulse_cold_reset.PULSE_EXT = 6;
defparam pulse_cold_reset.EDGE_TYPE = 1;
defparam pulse_cold_reset.IGNORE_RST_WHILE_BUSY = 1;

altera_edge_detector pulse_warm_reset (
  .clk       (fpga_clk_50),
  .rst_n     (hps_fpga_reset_n),
  .signal_in (hps_reset_req[1]),
  .pulse_out (hps_warm_reset)
);
defparam pulse_warm_reset.PULSE_EXT = 2;
defparam pulse_warm_reset.EDGE_TYPE = 1;
defparam pulse_warm_reset.IGNORE_RST_WHILE_BUSY = 1;
  
altera_edge_detector pulse_debug_reset (
  .clk       (fpga_clk_50),
  .rst_n     (hps_fpga_reset_n),
  .signal_in (hps_reset_req[2]),
  .pulse_out (hps_debug_reset)
);
defparam pulse_debug_reset.PULSE_EXT = 32;
defparam pulse_debug_reset.EDGE_TYPE = 1;
defparam pulse_debug_reset.IGNORE_RST_WHILE_BUSY = 1;
`endif

//=======================================================
// 					USER CODE / ARCHITECTURE
//=======================================================     

/* inputs */ 
  
assign clk_5=GPIO_0[2];

	/* switch between test mode or normal mode */

always@(*) begin
	if (SW[0]==1) begin //test mode		
		single_L1=single_L1_test;
		single_L2=single_L2_test;
		trigger=trigger_test;		
		dcc_data_in=dcc_test;
	end
	else begin	//normal mode
		single_L1=GPIO_0[3]; //from 3ct-connector
		single_L2=GPIO_0[4];	//from 3ct-connector
		trigger=~GPIO_0[35];	//gpio close to hdmi
		dcc_data_in=GPIO_0[1]; //from hdmi
	end
end

	/* 
	* Note : in test mode, the clk_5 *must* be injected, not generated by a PLL. 
	* This is necessary to validate the tagger block (driven by 2 independent clocks).
	*/




/* outputs */

assign GPIO_0[24]=clk_5;
assign GPIO_0[25]=dcc_data_in;
assign GPIO_0[29:26]=data[6][3:0]; //maps to {enable_acq,reset_time,f2h_notify_cmd,f2h_notify_evt}

assign LED[7:0]=data[6][15:8]; //maps to cnt_clk_5[29:22]


/* interface registers */


assign cmd_reset=command[0][0];
assign reset_all=~hps_fpga_reset_n|cmd_reset|~KEY[0];  
assign data[7]=32'b0;
 
/* architecture */ 
 
 
pll_250 pll_250_inst(
	.refclk(fpga_clk_50), 
	.rst(reset_all),
	.outclk_0(clk_250),
	.locked(pll_lock)
);


/* test bench: generate event pulses */

frame_gen #(.WIDTH(32)) frame_gen_L1(
	.clk(fpga_clk_50),
	.ena(command[0][1]),
	.frame(command[1]),
	.rotate(1'b0),
	.pulse(single_L1_test)
);

frame_gen #(.WIDTH(32)) frame_gen_L2(
	.clk(fpga_clk_50),
	.ena(command[0][1]),
	.frame(command[2]),
	.rotate(1'b0),
	.pulse(single_L2_test)
);

frame_gen #(.WIDTH(32)) frame_gen_trig(
	.clk(fpga_clk_50),
	.ena(command[0][1]),
	.frame(command[3]),
	.rotate(1'b0),
	.pulse(trigger_test)
);


frame_gen #(.WIDTH(32)) frame_gen_dcc(
	.clk(clk_5),
	.ena(command[0][2]),
	.frame(command[4]),
	.rotate(1'b0),
	.pulse(dcc_test)
);
 
 
 
/* main module */ 
 
main_module main_mod_inst(	
	.clk_5(clk_5),
	.clk_50(fpga_clk_50),
	.clk_250(clk_250),
	.reset(reset_all), 	 
	.single_L1(single_L1), 
	.single_L2(single_L2), 
	.trigger(trigger),	
	.dcc_data_in(dcc_data_in),
	.command(command[0]),		
	.data_0(data[0]),
	.data_1(data[1]),
	.data_2(data[2]),
	.data_3(data[3]),
	.data_4(data[4]),
	.data_5(data[5]),
	.data_6(data[6]),
	.serial2scope(GPIO_0[16]),	//to lvds
	.frame_aligned(GPIO_0[30])
);    
 

 

endmodule
