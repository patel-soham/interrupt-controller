`include "interrupt_controller.v"
`timescale 1ns/1ps

module tb;

parameter DATA_WIDTH=8, // Width of data bus
		  ADDR_WIDTH=8, // Width of address bus 
		  NUM_INTR=16, // Number of peripheral controllers i.e. max number of interrupts
		  INTR_SERV=4, // Number of bits required to represent each interrupts (Depends on NUM_INTR)
		  MAX_DELAY=30, // Max delay to serve one interrupt by Master
		  TIME_PERIOD=2; // Time period of clock

reg pclk_i, pwrite_i, penable_i, intr_serviced_i, preset_i, psel_i;
reg [DATA_WIDTH-1 : 0] pwdata_i;
reg [ADDR_WIDTH-1 : 0] paddr_i;
reg [NUM_INTR-1 : 0] intr_active_i;
wire pready_o, perror_o, intr_valid_o;
wire [DATA_WIDTH-1 : 0] prdata_o;
wire [INTR_SERV-1 : 0] intr_to_service_o;

reg [INTR_SERV-1 : 0] random_priority_array [NUM_INTR-1 : 0]; 
reg [30*8 : 1] testname;
integer i;

interrupt_controller #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH), .NUM_INTR(NUM_INTR), .INTR_SERV(INTR_SERV)) u0 (.*);

initial begin
	pclk_i = 0;
	forever #(TIME_PERIOD/2.0) pclk_i = ~pclk_i;
end

initial begin
	// Store type of test in testname variable
	$value$plusargs("testname=%s",testname);
	
	// intialize reg variables
	pwrite_i = 0;
	penable_i = 0;
	intr_serviced_i = 0;
	psel_i = 0;
	pwdata_i = 0;
	paddr_i = 0;
	intr_active_i = 0;
	for (i=0; i<NUM_INTR; i=i+1) random_priority_array[i] = 0;

	// Hold and release reset
	preset_i = 1;
	repeat (5) @ (posedge pclk_i);
	preset_i = 0;
    
	randomizer(); // create a randomized priority array to use in random_priority test case
    for (i=0; i<NUM_INTR; i=i+1) begin 
		if (testname == "ascending_priority") write_intc(i, i); // (peripheral->priority) 0->0, 1->1, ...n->n 
		else if (testname == "descending_priority") write_intc(i, NUM_INTR-1-i); // (peripheral->priority) 0->n, 1->n-1, ...n->0 
		else if (testname == "random_priority") write_intc(i, random_priority_array[i]);
		else begin
			$display("*** Error testname ***");
			i = NUM_INTR;
		end
	end
	intr_active_i = $random;
	#300;
	intr_active_i = $random;
	#300;
	intr_active_i = $random;
	#300;
	$finish;
end

initial begin
	forever begin
		@(posedge pclk_i);
		if (intr_valid_o == 1) begin
			#($urandom_range(1,MAX_DELAY)); // time taken by master to serve interrupt request from intc
			intr_active_i[intr_to_service_o] = 0; // Specific Peripheral controller indicating INTC that interrupt is serviced   
			intr_serviced_i = 1; // Master/ processor giving signal to indicate previous interrupt request served
			@(posedge pclk_i);
			intr_serviced_i = 0; // Master/ processor making reseting flag after INTC already got acknowledged
		end
	end
end

task write_intc (input reg [ADDR_WIDTH-1 : 0] addr, input reg [DATA_WIDTH-1 : 0]data); 
begin
	paddr_i = addr;
	pwdata_i = data;
	pwrite_i = 1;
	psel_i = 1;
	penable_i = 1;
	wait (pready_o == 1);
	@(posedge pclk_i);
	paddr_i = 0;
	pwdata_i = 0;
	pwrite_i = 0;
	psel_i = 0;
	penable_i = 0;
end
endtask

// Task to generate random unique values of priority for each of NUM_INTR peripheral controllers
// This randomizer task is used in random_priority test case
task randomizer();
reg [INTR_SERV-1 : 0] temp;
reg unique;
integer j, k;
begin
	for (j=0; j<NUM_INTR-1; ) begin
		temp = $urandom;
		unique = 1;
		for (k=0; k<j; k=k+1) begin
			if (random_priority_array[k] == temp) begin
				unique = 0;
				k = j;
			end
		end
		if (unique == 1) begin
			random_priority_array[j] = temp;
			j=j+1;
		end
	end	
	//for (j=0; j<NUM_INTR-1; j=j+1) $display("Port-%d Priority-%d",j,random_priority_array[j]);
end
endtask

endmodule
