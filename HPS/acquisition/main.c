/** \author Baptiste Joly
 * 	\date fev 2018
 *	\brief Acquisition program for the time_tagger project.
 * 
 * 	Saves trigger events and command data in separate files
 * 
 */


#include <stdio.h>
#include <errno.h>
#include <string.h> //for strerror(errno)
#include <time.h>
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
const uint32_t frame_idle=			0x0000CED0;

void* slave_addr; // * most functions use this address, 
									// * it is unique
									//   => better declare it global


//write (data) to the 32-bit register no (reg_id) of Slave_Template (slave_addr)
void write_slave(unsigned reg_id, uint32_t data){
	uint32_t* reg_addr=(uint32_t*) (slave_addr+reg_id*0x40+0x04);
	*reg_addr=data;	
	return;
}

//read and return the 32-bit register no (reg_id) of Slave_Template (slave_addr)
uint32_t read_slave(unsigned reg_id){
	uint32_t* reg_addr=(uint32_t*) (slave_addr+reg_id*0x40);
	return(*reg_addr);	
}

void save_cmd(FILE* file){		
	uint32_t code=read_slave(6); //status word (includes cmd code and current timestamp) 
	fwrite((void*)(&code),4,1,file);
	return;
}

void read_evt(uint32_t *buffer){
	int i;
	for(i=0;i<6;i++)	buffer[i]=read_slave(i);
	return;	
}

void save_evt(uint32_t *buffer, FILE* file){	
	fwrite((void*) buffer,4,6,file);
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
	return;
}




int main(int argc, char* argv[]) {
	//create event and command files
	if(argc!=2) printf("usage: acquisition <output path>\n");
	long int starttime=(long int) time(NULL); //date in s since 01/01/1970
	char evt_filename[100];	
	sprintf(evt_filename,"%s%s%ld%s",argv[1],"/evt",starttime,".mim");
	
	FILE* evt_file=fopen(evt_filename,"w");
	if(!evt_file){
		printf("unable to create file %s\n",evt_filename);
		printf(strerror(errno));
		return -1;
	}
	
	char cmd_filename[100];	
	sprintf(cmd_filename,"%s%s%ld%s",argv[1],"/cmd",starttime,".mim");
	
	FILE* cmd_file=fopen(cmd_filename,"w");
	if(!cmd_file){
		printf("unable to create file %s\n",cmd_filename);
		printf(strerror(errno));
		return -1;
	}
	
	//write header in files
	//role: ensure detection of endianness when reading the files
	uint32_t header=0xF3E2D1B0;	
	fwrite((void*) (&header),4,1,evt_file);	
	fwrite((void*) (&header),4,1,cmd_file);	
	
	// map the address space for the data registers into user space so we can interact with them.
	// we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span

	void *virtual_base;
	int fd;			
	
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
	uint32_t buffer[7];
	int cnt;
	for(cnt=0;cnt<100;cnt++){
		do{
			state=read_slave(6);
			trig=state & 0x03;
		}
		while(trig==0);
		// if new event
		if(trig==0x01){
			read_evt(buffer);				
			ack_evt();
			save_evt(buffer,evt_file);	
		}
		// if new command
		if(trig==0x02){			
			save_cmd(cmd_file);				
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
	
	fclose(evt_file);
	fclose(cmd_file);

	return( 0 );
}

