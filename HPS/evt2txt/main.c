#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int read_evt(FILE* file, uint32_t *buffer){
	return fread((void*) buffer, 4, 7, file);
}


void print_evt(uint32_t *buffer){
	printf("cnt5_lsb= %d\t",buffer[0]);
	printf("cnt5_msb= %d\t",buffer[1]);	
	uint32_t data=buffer[2];
	printf("tdc_L1= %d\t",(data & (uint32_t) 0x7F));
	data = (data >> 7); 
	printf("tdc_L2= %d\n",(data & (uint32_t) 0x7F));	
	data = (data >> 7); 
	printf("tdc_tr= %d\n",(data & (uint32_t) 0x7F));	
	data = (data >> 7); 
	printf("ena_acq=%x\n",(data & (uint32_t) 0x01));	
	printf("cnt_tr=%d\n",buffer[3]);	
	printf("cnt_L1=%d\n",buffer[4]);	
	printf("cnt_L2=%d\n",buffer[5]);	
	return;
}

int main(int argc, char* argv[]){
	
	if(argc!=2){
		printf("usage: mim2txt <file>\n");
		return(1);
	}
	FILE* file=fopen(argv[1],"r");
	if(!file){
		printf("could not open file %s\n",argv[1]);
		return(1);
	}
	uint32_t buffer[7];
	uint32_t checkword;
	fread((void*) &checkword, 4, 1, file);	
	while(read_evt(file,buffer)){
		print_evt(buffer);
	}
	fclose(file);
	return(0);
} 
