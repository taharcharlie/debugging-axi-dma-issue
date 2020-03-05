
`timescale 1 ns / 1 ps

`define TICK #10
`define HALF_TICK #5

	module tb_tiny_yolo_accelerator_v1_0_M00_AXIS ();
    /*********************************************************
    *
    *                 Parameter Definition
    *
    **********************************************************/
    localparam integer C_M_AXIS_TDATA_WIDTH	= 128;
    localparam integer FIFO_ADDR_BIT	= 10;
    
    /*********************************************************
    *
    *             Port Definition
    *
    **********************************************************/
    // Input Port
    reg    M_AXIS_ACLK;
    reg    M_AXIS_ARESETN;
    reg    M_AXIS_TREADY;

    reg    FIFO_IN_QUEUE;
    reg    [31:0] NO_OF_TRANSACTION;
    reg    [FIFO_ADDR_BIT-1:0] FIFO_DEBUG_ADDR;

    // Output Port
    wire   M_AXIS_TVALID;
    wire   [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA;
    wire   [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB;
    wire   M_AXIS_TLAST;

    wire   FIFO_ALMOST_FULL;
    wire   FIFO_OUT_FULL;
    wire   [7:0] FSM_STREAM_MASTER;
    wire   [31:0] O_DEBUG_BRAM_CONTROL;
    wire   [31:0] O_DEBUG_BRAM_DATA;
    wire   O_DEBUG_I_START;
    wire   [C_M_AXIS_TDATA_WIDTH-1:0] FIFO_DEBUG_DATA;

    /*********************************************************
    *
    *             Testbench Sequence
    *
    **********************************************************/
    initial
    begin
      $display("Start of Testbench");

      resetState();
      fillFIFOBufferWhileSendingData();

      $display("End of Testbench");
    end

    /*********************************************************
    *
    *             Testbench Logic
    *
    **********************************************************/
    // Generate Clock
    always 
    begin
        `HALF_TICK;
        M_AXIS_ACLK = !M_AXIS_ACLK;
    end

    /*********************************************************
    *
    *             Testbench Task
    *
    **********************************************************/
    task resetState();
      M_AXIS_ACLK <= 1'b0;
      M_AXIS_ARESETN <= 1'b0;
      M_AXIS_TREADY <= 1'b0;

      NO_OF_TRANSACTION <= 32'd28672; // Hold This Value

      FIFO_IN_QUEUE <= 1'b0;

      FIFO_DEBUG_ADDR <= 1'b0;

      waitNCycle(5);
      M_AXIS_ARESETN <= 1'b1;
      waitNCycle(1);
    endtask

    integer i;
    task waitNCycle( input integer N);
      for (i = 0; i < N; i = i + 1)
      begin
          `TICK;
      end
    endtask

    reg [31:0] counter;
    reg [127:0] data_in;

    task fillFIFOBufferWhileSendingData();
      FIFO_IN_QUEUE <= 1;

      while (!FIFO_OUT_FULL)
      begin
        if (counter >= 512)
        begin
          // Always on except on 516 and 517 to Simulate condition when DMA Ready Goes down
          M_AXIS_TREADY <= counter < 516 || counter > 517;
        end
        else
        begin
          // Stall Ready for 512 clock cycle to Simulate DMA
          M_AXIS_TREADY <= 0;
        end
        waitNCycle(1);
      end
    endtask

    initial
    begin
        counter <= 0;
    end
    always @(posedge M_AXIS_ACLK)
    begin
        if (!M_AXIS_ARESETN)
        begin
            counter <= 0;
        end
        else
        begin
            if (FIFO_OUT_FULL)
            begin
              if (M_AXIS_TVALID && M_AXIS_TREADY)
              begin
                  counter <= counter + 1;
              end
              else
              begin
                  counter <= counter;
              end
            end
            else
            begin
              counter <= counter + 1;
            end
        end
    end

    always @(posedge M_AXIS_ACLK)
    begin
        case (counter % 16)
            0:
            begin
                data_in <= 128'h0f0e0d0c0b0a09080706050403020100;
            end
            1:
            begin
                data_in <= 128'h1f1e1d1c1b1a19181716151413121110;
            end
            2:
            begin
                data_in <= 128'h2f2e2d2c2b2a29282726252423222120;
            end
            3:
            begin
                data_in <= 128'h3f3e3d3c3b3a39383736353433323130;
            end
            4:
            begin
                data_in <= 128'h4f4e4d4c4b4a49484746454443424140;
            end
            5:
            begin
                data_in <= 128'h5f5e5d5c5b5a59585756555453525150;
            end
            6:
            begin
                data_in <= 128'h6f6e6d6c6b6a69686766656463626160;
            end
            7:
            begin
                data_in <= 128'h7f7e7d7c7b7a79787776757473727170;
            end
            8:
            begin
                data_in <= 128'h8f8e8d8c8b8a89888786858483828180;
            end
            9:
            begin
                data_in <= 128'h9f9e9d9c9b9a99989796959493929190;
            end
            10:
            begin
                data_in <= 128'hafaeadacabaaa9a8a7a6a5a4a3a2a1a0;
            end
            11:
            begin
                data_in <= 128'hbfbebdbcbbbab9b8b7b6b5b4b3b2b1b0;
            end
            12:
            begin
                data_in <= 128'hcfcecdcccbcac9c8c7c6c5c4c3c2c1c0;
            end
            13:
            begin
                data_in <= 128'hdfdedddcdbdad9d8d7d6d5d4d3d2d1d0;
            end
            14:
            begin
                data_in <= 128'hefeeedecebeae9e8e7e6e5e4e3e2e1e0;
            end
            15:
            begin
                data_in <= 128'hfffefdfcfbfaf9f8f7f6f5f4f3f2f1f0;
            end
            default:
            begin
                data_in <= 128'hffeeddccbbaa99887766554433221100;
            end
        endcase
    end

    /*********************************************************
    *
    *             DUT Instantiation
    *
    **********************************************************/
    tiny_yolo_accelerator_v1_0_M00_AXIS # (
        .C_M_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
        .FIFO_ADDR_BIT(FIFO_ADDR_BIT)
    ) DUT (
		.FIFO_IN_QUEUE(FIFO_IN_QUEUE),
		.FIFO_ALMOST_FULL(FIFO_ALMOST_FULL),
		.FIFO_OUT_FULL(FIFO_OUT_FULL),
		.FIFO_IN_DATA(data_in),

		.FSM_STREAM_MASTER(FSM_STREAM_MASTER),
		.NO_OF_TRANSACTION(NO_OF_TRANSACTION),

		.O_DEBUG_BRAM_CONTROL(O_DEBUG_BRAM_CONTROL),
		.O_DEBUG_BRAM_DATA(O_DEBUG_BRAM_DATA),
		.O_DEBUG_I_START(O_DEBUG_I_START),

		.FIFO_DEBUG_ADDR(FIFO_DEBUG_ADDR),
		.FIFO_DEBUG_DATA(FIFO_DEBUG_DATA),

		.M_AXIS_ACLK(M_AXIS_ACLK),
		.M_AXIS_ARESETN(M_AXIS_ARESETN),
		.M_AXIS_TVALID(M_AXIS_TVALID),
		.M_AXIS_TDATA(M_AXIS_TDATA),
		.M_AXIS_TSTRB(M_AXIS_TSTRB),
		.M_AXIS_TLAST(M_AXIS_TLAST),
		.M_AXIS_TREADY(M_AXIS_TREADY)
    );

	endmodule