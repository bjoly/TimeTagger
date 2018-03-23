/** \author Baptiste Joly
 * 	\date fev 2018
 *	\brief Test program for the time_tagger project.
 * 
 * The events signals and dcc command frames are generated internally.
 * 
 */


#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#define soc_cv_av //choose cyclone V SoC
#include "soc_cv_av/socal/socal.h"
#include "soc_cv_av/socal/hps.h"
#include "soc_cv_av/socal/alt_gpio.h"
#include "hwlib.h"
#include "hps_0.h"
#include "slave_template_macros.h"

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )

const uint32_t frame_reset_bcid=	0x0000C1D0;
const uint32_t frame_start_acq=		0x0000F2D0;
const uint32_t frame_ramfull_ext=	0x0000E3D0;
const uint32_t frame_stop_acq=		0x000085D0;
const uint32_t frame_idle=				0x0000CED0;

void* slave_addr; // * most functions use this address, 
									// * it is unique
									//   => better declare it global


//write (data) to the 32-bit register no (reg_id) of Slave_Template (slave_addr)
void write_slave(unsigned reg_id, uint32_t data)
{
	uint32_t* reg_addr=(uint32_t*) (slave_addr+reg_id*0x40+0x04);
	*reg_addr=data;	
	return;
}

//read and return the 32-bit register no (reg_id) of Slave_Template (slave_addr)
uint32_t read_slave(unsigned reg_id)
{
	uint32_t* reg_addr=(uint32_t*) (slave_addr+reg_id*0x40);
	return(*reg_addr);	
}


void send_cmd_frame(uint32_t frame){
	/*
  printf("sending command frame%x\n",frame);
	//write new frame		
	write_slave(12,frame); 	
	//stop the frame_gen to load the frame
	write_slave(8,(uint32_t) 0); 
	usleep(1);
	//restart the frame_gen	
	write_slave(8,(uint32_t) 4); 
	//run frame_gen during some time	
	usleep(10);
	
	//check status bit while the frame is on
	printf("status (cmd ON)=%x\n",read_slave(6));
		
	//set idle
	write_slave(12,frame_idle);
	//stop the frame_gen to load "idle"
	write_slave(8,(uint32_t) 0); 
	usleep(1);
	//restart the frame_gen	
	write_slave(8,(uint32_t) 4); 
	*/
  printf("sending command frame%x\n",frame);
	write_slave(8,(uint32_t) 0); //ensure frame_gen is stopped (can load frame)
	write_slave(12,frame); 
	write_slave(8,(uint32_t) 4); //run frame_gen
	usleep(10);
	write_slave(8,(uint32_t) 0); //stop frame_gen
	return;
}



//print command name from code
void print_cmd(uint32_t cmd)
{
	switch(cmd){
		case 0:
			printf("command %d:\t dif reset\n",cmd);
			break;
		case 1:
			printf("command %d:\t bcid reset\n",cmd);
			break;
		case 2:
			printf("command %d:\t start acq\n",cmd);
			break;
		case 3:
			printf("command %d:\t ramfull ext\n",cmd);
			break;
		case 4:
			printf("command %d:\t trigger_ext\n",cmd);
			break;
		case 5:
			printf("command %d:\t stop_acq\n",cmd);
			break;
		case 6:
			printf("command %d:\t digital_ro\n",cmd);
			break;
		case 0xA:
			printf("command %d:\t pulse_lemo\n",cmd);
			break;
		case 0xB:
			printf("command %d:\t raz_chn\n",cmd);
			break;
		case 0xC:
			printf("command %d:\t spill_on\n",cmd);
			break;
		case 0xD:
			printf("command %d:\t spill_off\n",cmd);
			break;
		case 0xE:
			printf("command %d:\t idle_cmd\n",cmd);
			break;
		case 0xF:
			printf("command %d:\t trigger\n",cmd);
			break;
		default:
			printf("command %d:\t unknown\n",cmd);
			break;
	}
}

void report_decoder_out(){
	printf("------------dcc command------------\n");	
	uint32_t code=read_slave(6);
	code = (code >> 4) & 0x0F;
	printf("decoder output=%x\n\n",code);		  
	print_cmd(code);
	return;
}


void send_event(uint32_t frame_L1, uint32_t frame_L2, uint32_t frame_trig){
	write_slave(9,frame_L1);
	write_slave(10,frame_L2);
	write_slave(11,frame_trig);
	write_slave(8,(uint32_t) 2); //test_event command signal
	usleep(2);
	write_slave(8,(uint32_t) 0);	
	return;
}

void read_event(uint32_t *buffer){
	int i;
	for(i=0;i<6;i++)	buffer[i]=read_slave(i);
	return;	
}


void print_event(uint32_t *buffer){
	printf("-----------new event------------\n");
	printf("cnt_clk_5[31:0]=%d\n",buffer[0]);
	printf("cnt_clk_5[47:32]=%d\n",buffer[1]);	
	uint32_t data=buffer[2];
	printf("reg 2==%x\n",data);
	printf("tdc_L1=%d\n",(data & (uint32_t) 0x7F));
	data = (data >> 7); 
	printf("tdc_L2=%d\n",(data & (uint32_t) 0x7F));	
	data = (data >> 7); 
	printf("tdc_trig=%d\n",(data & (uint32_t) 0x7F));	
	data = (data >> 7); 
	printf("ena_acq=%x\n",(data & (uint32_t) 0x01));	
	printf("scaler_trig=%d\n",buffer[3]);	
	printf("scaler_sL1=%d\n",buffer[4]);	
	printf("scaler_sL2=%d\n",buffer[5]);	
	return;
}


void ack_evt(){
	write_slave(8,(uint32_t) 0x08); 
	usleep(1);
	write_slave(8,(uint32_t) 0x00);
	return;
}

void ack_cmd(){
	write_slave(8,(uint32_t) 0x10);
	usleep(1);
  printf("status in ack cmd=%x\n",read_slave(6));
	write_slave(8,(uint32_t) 0x00);
  usleep(1);
	printf("status after ack cmd=%x\n",read_slave(6));
  return;
}




int main() {

	void *virtual_base;
	int fd;		
	uint32_t evt_buffer[6];

	// map the address space for the data registers into user space so we can interact with them.
	// we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span

	if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
		printf( "ERROR: could not open \"/dev/mem\"...\n" );
		return( 1 );
	}
	virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );

	if( virtual_base == MAP_FAILED ) {
		printf( "ERROR: mmap() failed...\n" );
		close( fd );
		return( 1 );
	}	
	slave_addr=virtual_base + ((unsigned long)(ALT_LWFPGASLVS_OFST+SLAVE_TEMPLATE_0_BASE) & (unsigned long)(HW_REGS_MASK));
	
	//global reset 
	write_slave(8,(uint32_t) 0);
	write_slave(8,(uint32_t) 1); 
	usleep(100);
	write_slave(8,(uint32_t) 0); 
	
	
	//**************test tagger module***************
	
	//check status bits
	printf("initial status=%x\n",read_slave(6));

	//send event 1
	send_event((uint32_t) 0x000000F0,(uint32_t) 0x000001E0,(uint32_t) 0x000003C0);
		
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//load event in memory
  read_event(evt_buffer);	

	//acknowledge to release the tagger output registers
	ack_evt();

	//print event
	print_event(evt_buffer);		
	
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//send event 2
	send_event((uint32_t) 0x000000F0,(uint32_t) 0x000003C0,(uint32_t) 0x00000F00);
	
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//load event in memory
  read_event(evt_buffer);	

	//acknowledge to release the tagger output registers
	ack_evt();

	//print event
	print_event(evt_buffer);		
	
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//**************test command module***************
		
	//send command 1
	send_cmd_frame(frame_reset_bcid);	
	
	//print command
	report_decoder_out();
	
	//acknowledge cmd
	ack_cmd();
	
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//send command 2
	send_cmd_frame(frame_start_acq);
		
	//print command
	report_decoder_out();
	
	//acknowledge cmd
	ack_cmd();
	
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//*********check counter reset***********
	
	//send event 
	send_event((uint32_t) 0x000000F0,(uint32_t) 0x000001E0,(uint32_t) 0x000003C0);
		
	//check status bits
	printf("status=%x\n",read_slave(6));
	
	//load event in memory
  read_event(evt_buffer);	

	//acknowledge to release the tagger output registers
	ack_evt();

	//print event
	print_event(evt_buffer);		
	
	//check status bits
	printf("status=%x\n",read_slave(6)); 

	//global reset 
	write_slave(8,(uint32_t) 0);
	write_slave(8,(uint32_t) 1); 
	usleep(100);
	write_slave(8,(uint32_t) 0); 


// clean up our memory mapping and exit
	
	if( munmap( virtual_base, HW_REGS_SPAN ) != 0 ) {
		printf( "ERROR: munmap() failed...\n" );
		close( fd );
		return( 1 );
	}

	close( fd );

	return( 0 );
}

