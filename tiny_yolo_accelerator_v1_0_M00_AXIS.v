
`timescale 1 ns / 1 ps

	module tiny_yolo_accelerator_v1_0_M00_AXIS #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXIS address bus. The slave accepts the read and write addresses of width C_M_AXIS_TDATA_WIDTH.
		parameter integer C_M_AXIS_TDATA_WIDTH	= 128,
		// Start count is the number of clock cycles the master will wait before initiating/issuing any transaction.
		parameter integer FIFO_ADDR_BIT	= 10
	)
	(
		// Users to add ports here
		// Signal for storing data to FIFO
		input wire 	FIFO_IN_QUEUE,
		output wire FIFO_ALMOST_FULL,
		output wire FIFO_OUT_FULL,
		input wire 	[C_M_AXIS_TDATA_WIDTH-1:0] FIFO_IN_DATA,

		output wire [7:0] FSM_STREAM_MASTER,
		input wire [31:0] NO_OF_TRANSACTION,

		// DEBUG PORT
		output wire [31:0] O_DEBUG_BRAM_CONTROL,
		output wire [31:0] O_DEBUG_BRAM_DATA,
		output wire O_DEBUG_I_START,

		// FIFO Debug wire
		input wire 	[FIFO_ADDR_BIT-1:0] FIFO_DEBUG_ADDR,
		output wire	[C_M_AXIS_TDATA_WIDTH-1:0] FIFO_DEBUG_DATA,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global ports
		input wire  M_AXIS_ACLK,
		input wire  M_AXIS_ARESETN,
		// Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted.
		output wire  M_AXIS_TVALID,
		// TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
		output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
		// TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
		output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
		// TLAST indicates the boundary of a packet.
		output wire  M_AXIS_TLAST,
		// TREADY indicates that the slave can accept a transfer in the current cycle.
		input wire  M_AXIS_TREADY
	);

	// Define the states of state machine
	// The control state machine oversees the writing of input streaming data to the FIFO,
	// and outputs the streaming data from the FIFO
	parameter [1:0] IDLE = 2'b00,        // This is the initial/idle state

	                WAIT_FIFO  = 2'b01, // This state initializes the counter, once
	                                // the counter reaches C_M_START_COUNT count,
	                                // the state machine changes state to SEND_STREAM
	                SEND_STREAM   = 2'b10; // In this state the
	                                     // stream data is output through M_AXIS_TDATA
	// State variable
	reg [1:0] mst_exec_state;
	// Number of data sent
	reg [31:0] no_data_sent;
	reg reset_counter;

	// AXI Stream internal signals
	//streaming data valid
	reg  	axis_tvalid;
	//Last of the streaming data
	wire  	axis_tlast;
	//FIFO implementation signals
	reg [C_M_AXIS_TDATA_WIDTH-1 : 0] 	stream_data_out;
	wire  	tx_en;
	reg		tx_en_delayed;
	//The master has issued all the streaming data stored in FIFO
	reg  	tx_done;

	// FIFO Buffer
	wire fifo_out_data_valid;
	wire [127:0] fifo_out_data;
	wire fifo_out_empty;
	reg fifo_out_empty_delayed;
	wire fifo_not_empty_delayed = !fifo_out_empty_delayed;
	reg axis_tready_delayed;

	reg [127:0] fix_bug_reg;
	reg fix_bug_reg_valid;

	// I/O Connections assignments

	assign M_AXIS_TVALID	= axis_tvalid;
	assign M_AXIS_TDATA	= stream_data_out;
	assign M_AXIS_TLAST	= axis_tlast;
	assign M_AXIS_TSTRB	= {(C_M_AXIS_TDATA_WIDTH/8){1'b1}};


	// Control state machine implementation
	always @(posedge M_AXIS_ACLK)
	begin
	  if (!M_AXIS_ARESETN)
	  // Synchronous reset (active low)
	    begin
	      mst_exec_state <= IDLE;
		  reset_counter <= 0;
	    end
	  else
	    case (mst_exec_state)
	      IDLE:
		  begin
			mst_exec_state  <= WAIT_FIFO;
			reset_counter <= 1;
		  end

	      WAIT_FIFO:
	        // The slave starts accepting tdata when
	        // there tvalid is asserted to mark the
	        // presence of valid streaming data
	        if ( fifo_not_empty_delayed )
	          begin
	            mst_exec_state  <= SEND_STREAM;
				reset_counter <= 0;
	          end
	        else
	          begin
	            mst_exec_state  <= WAIT_FIFO;
				reset_counter <= 0;
	          end

	      SEND_STREAM:
	        // The example design streaming master functionality starts
	        // when the master drives output tdata from the FIFO and the slave
	        // has finished storing the S_AXIS_TDATA
	        if (tx_done)
	          begin
	            mst_exec_state <= IDLE;
				reset_counter <= 0;
	          end
	        else
	          begin
	            mst_exec_state <= SEND_STREAM;
				reset_counter <= 0;
 	          end
	    endcase
	end

	//tvalid generation
	//axis_tvalid is asserted when the control state machine's state is SEND_STREAM and
	//number of output streaming data is less than the NO_OF_TRANSACTION.
	always @(*)
	begin
		if (mst_exec_state == SEND_STREAM)
		begin
			axis_tvalid <= fifo_out_data_valid;
		end
		else
		begin
			axis_tvalid <= 0;
		end
	end 

	// AXI tlast generation
	// axis_tlast is asserted number of output streaming data is NO_OF_TRANSACTION-1
	// (0 to NO_OF_TRANSACTION-1)
	assign axis_tlast = (no_data_sent == NO_OF_TRANSACTION-1) && tx_en;

	// Delay the axis_tvalid and axis_tlast signal by one clock cycle
	// to match the latency of M_AXIS_TDATA
	always @(posedge M_AXIS_ACLK)
	begin
	  if (!M_AXIS_ARESETN)
	    begin
		  tx_en_delayed <= 1'b0;
		  axis_tready_delayed <= 1'b0;
	    end
	  else
	    begin
		  tx_en_delayed <= tx_en;
		  axis_tready_delayed <= M_AXIS_TREADY;
	    end
	end

	always @(posedge M_AXIS_ACLK)
	begin
		if (!M_AXIS_ARESETN)
		begin
			fix_bug_reg <= 128'd0;
		end
		else
		begin
			if (!M_AXIS_TREADY && axis_tready_delayed)
			begin
				fix_bug_reg <= fifo_out_data;
			end
			else
			begin
				fix_bug_reg <= fix_bug_reg;
			end
		end
	end

	always @(*)
	begin
		fix_bug_reg_valid <= (!axis_tready_delayed || !M_AXIS_TREADY) && no_data_sent != 0;
	end


	// no_data_sent pointer
	always@(posedge M_AXIS_ACLK)
	begin
	  if(!M_AXIS_ARESETN || reset_counter)
	    begin
	      no_data_sent <= 0;
	    end
	  else
	    if (no_data_sent <= NO_OF_TRANSACTION-1)
	      begin
	        if (tx_en)
			begin
				no_data_sent <= no_data_sent + 1;
			end
			else
			begin
				no_data_sent <= no_data_sent;
			end
	      end
		else
		 begin
			no_data_sent <= no_data_sent;
		 end
	end

	always@(*)
	begin
	  tx_done <= no_data_sent == NO_OF_TRANSACTION-1;
	end

	//FIFO read enable generation
	assign tx_en = M_AXIS_TREADY && axis_tvalid;

	// Streaming output data is read from FIFO
	always @(*)
	begin
		if (fix_bug_reg_valid)
		begin
			stream_data_out <= fix_bug_reg;
		end
		else
		begin
			stream_data_out <= fifo_out_data;
		end
	end

	// Add user logic here

	// Delay fifo_out_empty signal                                                    
	always @(posedge M_AXIS_ACLK)                                                                  
	begin                                                                                          
	  if (!M_AXIS_ARESETN)                                                                         
		begin
			fifo_out_empty_delayed <= 1'b0;                                                                                                                                                                                                      
	    end                                                                                        
	  else                                                                                         
	    begin                        
			fifo_out_empty_delayed <= fifo_out_empty;                                                                                                                                                                          
	    end                                                                                        
	end   

	// FIFO dequeue control 
	wire fifo_in_dequeue = (mst_exec_state == SEND_STREAM) && M_AXIS_TREADY && !fix_bug_reg_valid;

	// Add user logic here
	// Call stream fifo module
	stream_queue_out data_fifo
	(
		// Input ports
        .i_clk(M_AXIS_ACLK),
        .i_rst(M_AXIS_ARESETN),
        .i_queue(FIFO_IN_QUEUE),
        .i_dequeue(fifo_in_dequeue),
        .i_data(FIFO_IN_DATA),
        // Out ports
        .o_empty(fifo_out_empty),
		.o_almost_full(FIFO_ALMOST_FULL),
        .o_full(FIFO_OUT_FULL),
		.o_data_valid(fifo_out_data_valid),
        .o_data(fifo_out_data),
        // Debug Ports
        .debug_addr(FIFO_DEBUG_ADDR),
        .debug_data(FIFO_DEBUG_DATA)
	);

	// User logic ends
	assign FSM_STREAM_MASTER = {FIFO_OUT_FULL, fifo_out_empty, FIFO_IN_QUEUE, fifo_in_dequeue, 4'd0};

	endmodule