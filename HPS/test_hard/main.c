/** \author Baptiste Joly
 * 	\date fev 2018
 *	\brief Terminal program for the time_tagger project.
 * 
 * 
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


//print command name from code
void cmd_name(uint32_t cmd)
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

void print_cmd(){
	printf("------------dcc command------------\n");	
	uint32_t code=read_slave(6);
	code = (code >> 4) & 0x0F;
	printf("decoder output=%x\n\n",code);		  
	cmd_name(code);
	return;
}

void print_evt(){
	printf("-----------new event------------\n");
	printf("cnt_clk_5[31:0]=%d\n",read_slave(0));
	printf("cnt_clk_5[47:32]=%d\n",read_slave(1));	
	uint32_t data=read_slave(2);
	printf("reg 2==%x\n",data);
	printf("tdc_L1=%d\n",(data & (uint32_t) 0x7F));
	data = (data >> 7); 
	printf("tdc_L2=%d\n",(data & (uint32_t) 0x7F));	
	data = (data >> 7); 
	printf("tdc_trig=%d\n",(data & (uint32_t) 0x7F));	
	data = (data >> 7); 
	printf("ena_acq=%x\n",(data & (uint32_t) 0x01));	
	printf("scaler_trig=%d\n",read_slave(3));	
	printf("scaler_sL1=%d\n",read_slave(4));	
	printf("scaler_sL2=%d\n",read_slave(5));	
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
	write_slave(8,(uint32_t) 0x00);
  usleep(1);
  return;
}

int main() {

	void *virtual_base;
	int fd;		
	
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
	
	
	// polling loop: wait for a new trigger event or command 
	uint32_t trig, state;
	while(1){
		do{
			state=read_slave(6);
			trig=state & 0x03;
		}
		while(trig==0);
		// if new event
		if(trig==0x01){
			print_evt();					
			ack_evt();
		}
		// if new command
		if(trig==0x02){			
			print_cmd();				
			ack_cmd();
		}
	} 


	// clean up our memory mapping and exit	
	if( munmap( virtual_base, HW_REGS_SPAN ) != 0 ) {
		printf( "ERROR: munmap() failed...\n" );
		close( fd );
		return( 1 );
	}

	close( fd );

	return( 0 );
}

