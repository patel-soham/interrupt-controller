// Verilog Design of interrupt controller

/* PORTS
** Advanced Peripheral Bus (APB) protocol signals. Here to configure INTC registers by processor/ master.
1. pclk_i - Clock(M->S).
2. paddr_i - Address bus(M->S).
3. pwdata_i - Write data bus (M->S). 
4. prdata_o - Read data bus (S->M).
5. pwrite_i - Direction signal(M->S). Performs write when HIGH and read when LOW.
6. p_enable_i - Enable(M->S). Indicates master is ready for APB transfer.
7. psel_i - Select(M->S). Master generates this signal to each connected slave. To indicate
             selected slave device and that a data transfer is required.
8. pready_o - Ready(S->M). To indicate slave is now ready to serve master's request.
9. perror_o - Slave error(S->M). Indicates transfer failure.
10. preset_i - Reset(M->S).

**INTC signal
1. intr_to_service_o - (INTC->M)Indicates which controller has an interrupt to serve at this moment
2. intr_serviced_i - (M->INTC)Indication from Master that the previous interrupt request has been served
3. intr_active_i - (Peripheral controllers->INTC)Signal from controllers to request interrupt from Master through INTC
4. intr_valid_o - (INTC->M)Valid signal. To indicate master that intr_to_service_o is active and respond to interrupt.

*/

module interrupt_controller(
// Master/ Processor interface
pclk_i, paddr_i, pwdata_i, prdata_o, pwrite_i, penable_i, psel_i, pready_o, perror_o, intr_to_service_o, intr_serviced_i, preset_i, intr_valid_o,
// Slave/ Peripheral Controller interface
intr_active_i
);
parameter S_NO_INTR=4'b1000, // INTC state when there is no interrupt
		  S_INTR=4'b0100, // INTC state when there there exist/s active interrupt/s and INTC request highest priority one to master
		  S_WAIT=4'b0010, // INTC state when it is waiting for master to serve requested interrupt
		  S_ERROR=4'b0001, // INTC Error state (NOT YET DEFINED)

		  DATA_WIDTH=8, // Width of data bus 
		  ADDR_WIDTH=8, // Width of address bus
		  NUM_INTR=16, // Number of peripheral controllers i.e. max number of interrupts
		  INTR_SERV=4; // Number of bits required to represent each interrupts (Depends on NUM_INTR)

input pclk_i, pwrite_i, penable_i, intr_serviced_i, preset_i, psel_i;
input [DATA_WIDTH-1 : 0] pwdata_i;
input [ADDR_WIDTH-1 : 0] paddr_i;
input [NUM_INTR-1 : 0] intr_active_i;
output reg pready_o, perror_o, intr_valid_o;
output reg [DATA_WIDTH-1 : 0] prdata_o;
output reg [INTR_SERV-1 : 0] intr_to_service_o;

reg [3 : 0] state, next_state;
// This register stores priority value for each peripheral controllers 
reg [INTR_SERV-1 : 0] priority_reg [NUM_INTR-1 : 0];
// technically the priority value i.e. [INTR_SERV-1 : 0] is set by pwdata
// so it can be same size as DATA_WIDTH as well but extra bits will be unused.
// reg [DATA_WIDTH-1 : 0] priority_reg [NUM_INTR-1 : 0];
reg [INTR_SERV-1 : 0]current_highest_priority, interrupt_number; 
integer i;

// Register programming logic
always @ (posedge pclk_i) begin
	if (preset_i == 1) begin
		pready_o = 0;
		perror_o = 0;
		prdata_o = 0;
		intr_to_service_o = 0; 
		intr_valid_o = 0;
		for (i=0; i<NUM_INTR; i=i+1) priority_reg[i] = 0;
		state = S_NO_INTR;
		next_state = S_NO_INTR;
		current_highest_priority = 0;
		interrupt_number = 0;
	end
	else begin
		perror_o = 0;
		if ( (psel_i & penable_i) == 1) begin
		 	pready_o = 1;
			if (pwrite_i == 1) priority_reg[paddr_i] = pwdata_i;
			else if ((pwrite_i == 0) && (prdata_o == {DATA_WIDTH{1'bz}})) prdata_o = priority_reg[paddr_i];
			else perror_o = 1; // Raise error
		end
		else pready_o = 0;
	end
end

// Interrupt handling logic
always @ (posedge pclk_i) begin
	if (preset_i != 1) begin
		case (state)
			S_NO_INTR: begin
				// If any of the bits from NUM_INTR goes HIGH or request interrupt
				if (intr_active_i != 0) next_state = S_INTR;
				// If none of the bits are high i.e. no interrupts 
				else next_state = S_NO_INTR;
			end
			S_INTR: begin
				// Get the highest priority interrupt among all active
				// interrupts and send the same to master
				current_highest_priority = 0;
				interrupt_number = 0;
				for (i=0; i<NUM_INTR; i=i+1) begin
					if (intr_active_i[i] == 1) begin
						if ( current_highest_priority < priority_reg[i]) begin
							current_highest_priority = priority_reg[i];
							interrupt_number = i;
						end
					end
				end
				intr_to_service_o = interrupt_number;
				intr_valid_o = 1;
				next_state = S_WAIT;
			end
			S_WAIT: begin
				// If INTC gets signal from master that previous interrupt
				// request was serviced
				if (intr_serviced_i == 1) begin
					intr_to_service_o = 0;
					intr_valid_o = 0;
					if (intr_active_i != 0) next_state = S_INTR;
					else next_state = S_NO_INTR;
				end
			end
			S_ERROR: begin
				// !! Not yet defined !!
			end
		endcase
	end
end

always @ (next_state) state = next_state;

endmodule
