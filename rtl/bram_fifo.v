module bram_fifo
#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 2048,      // 实际深度：2^ADDR_WIDTH
    parameter ADDR_WIDTH = 11         // FIFO 深度 = 2^ADDR_WIDTH
)
(
    // 系统信号
    input                      clk_i,       // 系统时钟
    input                      rst_i,       // 同步复位
    
    // 写端口
    input  [DATA_WIDTH-1:0]    din,         // 写入数据
    input                      wr_en,       // 写使能
    output                     full,        // FIFO满标志
    
    // 读端口
    output reg [DATA_WIDTH-1:0] dout,       // 读出数据（同步读出）
    input                      rd_en,       // 读使能
    output                     empty        // FIFO空标志
);

(* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];

// 扩展读写指针（ADDR_WIDTH+1位）
reg [ADDR_WIDTH:0] rd_ptr;
reg [ADDR_WIDTH:0] wr_ptr;

// 写操作（同步写）
always @(posedge clk_i) begin
    if(rst_i) begin
        wr_ptr <= 0;
    end
    else if(wr_en && !full) begin
        mem[wr_ptr[ADDR_WIDTH-1:0]] <= din;
        wr_ptr <= wr_ptr + 1;
    end
end

// 读操作（同步读，BRAM通常要求同步输出）
always @(posedge clk_i) begin
    if(rst_i) begin
        rd_ptr <= 0;
        dout   <= 0;
    end
    else begin
        // 先将数据读出并寄存
        dout <= mem[rd_ptr[ADDR_WIDTH-1:0]];
        if(rd_en && !empty)
            rd_ptr <= rd_ptr + 1;
    end
end

// empty：当读写指针完全相同时 FIFO 为空
assign empty = (wr_ptr == rd_ptr);

// full：当写指针的低位与读指针的低位相等，且最高位不同则认为 FIFO 满
assign full  = ( (wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) &&
                  (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]) );

endmodule
