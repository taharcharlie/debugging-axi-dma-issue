module stream_queue_out
    // Declare parameters
    #(
        parameter DWIDTH = 128,
        parameter SIZE = 1024,
        parameter ADDR_BIT = 10
    )  (
        // Input ports
        input wire i_clk,
        input wire i_rst,
        input wire i_queue,
        input wire i_dequeue,
        input wire [DWIDTH-1:0] i_data,

        // Out ports
        output wire o_empty,
        output reg o_almost_full,
        output reg o_full,
        output reg o_data_valid,
        output wire [DWIDTH-1:0] o_data,

        // Debug Ports
        input wire [ADDR_BIT-1:0] debug_addr,
        output wire [DWIDTH-1:0] debug_data
    );

    reg [ADDR_BIT-1:0] write_pointer;
    reg [ADDR_BIT-1:0] read_pointer;
    reg [ADDR_BIT-1:0] queue_addr;
    wire write_enable;
    reg i_dequeue_delayed;

    always @(posedge i_clk)
    begin
        i_dequeue_delayed <= i_dequeue;
    end

    assign write_enable = (i_queue == 1'b1);

    assign o_empty = (write_pointer == read_pointer);
    
    always @(*)
    begin
        if (write_pointer < 1023)
        begin
            if (write_pointer < 1022)
            begin
                o_almost_full <= (write_pointer + 2) == read_pointer;
            end
            else
            begin
                o_almost_full <= read_pointer == 0;
            end
            o_full <= (write_pointer + 1) == read_pointer;
        end
        else
        begin
            o_almost_full <= read_pointer == 1;
            o_full <= read_pointer == 0;
        end
        
    end
    

    // Selector for the first port if queue issued, use for write, else use for debug purpose
    always @(*)
    begin
        if (i_queue == 1'b1)
        begin
            queue_addr <= write_pointer;
        end
        else
        begin
            queue_addr <= debug_addr;
        end
    end

    // Read and Write pointer logic
    initial
    begin
        write_pointer <= 0;
        read_pointer <= 0;
    end
    always @(posedge i_clk)
    begin
        if (i_rst == 1'b0)
        begin
            write_pointer <= 0;
        end
        else
        begin
            if ((i_queue == 1'b1)  && (o_full == 1'b0))
            begin
                // If Queue and not full, increase the write address
                write_pointer <= write_pointer + 1;
            end
            else
            begin
                // Else Hold the address
                write_pointer <= write_pointer;
            end
        end
    end
    always @(posedge i_clk)
    begin
        if (i_rst == 1'b0)
        begin
            read_pointer <= 0;
        end
        else
        begin
            if ((i_dequeue == 1'b1) && (o_empty == 1'b0))
            begin
                // If Dequeue and not empty, increase the read address
                read_pointer <= read_pointer + 1;
            end
            else
            begin
                // Else Hold the address
                read_pointer <= read_pointer;
            end
        end
    end

    // Out valid
    always @(posedge i_clk)
    begin
        if (i_rst == 1'b0)
        begin
            o_data_valid <= 0;
        end
        else
        begin
            if (o_empty)
            begin
                o_data_valid <= 0;
            end
            else
            begin
                if ((i_dequeue && !i_dequeue_delayed))
                begin
                    o_data_valid <= 0;
                end
                else
                begin
                    o_data_valid <= 1;
                end
            end
        end
    end

    // Instantiate the Queue
    bram_tdp #(
        .DWIDTH(DWIDTH),
        .DEPTH(SIZE),
        .ADDR_BIT(ADDR_BIT)
    ) stream_out_queue_inst (
        .clk_a(i_clk),
        .clk_b(i_clk),
        .en_a(1'b1),
        .en_b(1'b1),
        .we_a(write_enable),
        .we_b(1'b0),
        .addr_a(queue_addr),
        .addr_b(read_pointer),
        .d_in_a(i_data),
        .d_in_b(i_data),
        .d_out_a(debug_data),
        .d_out_b(o_data)
    );

endmodule