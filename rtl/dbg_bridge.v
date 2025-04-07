/*
 * 调试桥模块 - UART 转 AXI 接口
 * 功能;通过 UART 接收调试命令,转换为 AXI 总线读写操作
 * 参数;
 *   CLK_FREQ  - 系统时钟频率 (Hz)
 *   BAUD_RATE - UART 波特率
 *   AXI_ID    - AXI 事务 ID
 */
module dbg_bridge
#(
    parameter CLK_FREQ         = 100_000_000,  // 默认 100MHz 时钟
    parameter BAUD_RATE        = 115200,       // 默认 115200 波特率
    parameter AXI_ID           = 4'd0          // 默认 AXI ID
)
(
    // 时钟与复位
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 clk_i CLK" *)
    input           clk_i,                     // 系统时钟
    
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 rst RST" *)
    input           rst_i,                     // 系统复位 (高有效)

    // UART 接口
    (* X_INTERFACE_INFO = "xilinx.com:interface:uart:1.0 UART RXD" *)
    input          uart_rxd_i,                 // UART 接收数据
    (* X_INTERFACE_INFO = "xilinx.com:interface:uart:1.0 UART TXD" *)
    output         uart_txd_o,                 // UART 发送数据

    // AXI 写地址通道
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWREADY" *)
    input           mem_awready_i,             // 写地址准备好
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWVALID" *)
    output          mem_awvalid_o,             // 写地址有效
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWADDR" *)
    output [31:0]   mem_awaddr_o,              // 写地址
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWID" *)
    output [3:0]    mem_awid_o,                // 写事务 ID
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWLEN" *)
    output [7:0]    mem_awlen_o,               // 写突发长度
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI AWBURST" *)
    output [1:0]    mem_awburst_o,             // 写突发类型

    // AXI 写数据通道
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WREADY" *)
    input           mem_wready_i,              // 写数据准备好
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WVALID" *)
    output          mem_wvalid_o,              // 写数据有效
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WDATA" *)
    output [31:0]   mem_wdata_o,               // 写数据
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WSTRB" *)
    output [3:0]    mem_wstrb_o,               // 写字节使能
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI WLAST" *)
    output          mem_wlast_o,               // 写突发最后一个数据

    // AXI 写响应通道
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BVALID" *)
    input           mem_bvalid_i,              // 写响应有效
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BRESP" *)
    input  [1:0]    mem_bresp_i,               // 写响应
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BID" *)
    input  [3:0]    mem_bid_i,                 // 写响应 ID
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI BREADY" *)
    output          mem_bready_o,              // 写响应准备好

    // AXI 读地址通道
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARREADY" *)
    input           mem_arready_i,             // 读地址准备好
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARVALID" *)
    output          mem_arvalid_o,             // 读地址有效
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARADDR" *)
    output [31:0]   mem_araddr_o,              // 读地址
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARID" *)
    output [3:0]    mem_arid_o,                // 读事务 ID
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARLEN" *)
    output [7:0]    mem_arlen_o,               // 读突发长度
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI ARBURST" *)
    output [1:0]    mem_arburst_o,             // 读突发类型

    // AXI 读数据通道
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RVALID" *)
    input           mem_rvalid_i,              // 读数据有效
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RDATA" *)
    input  [31:0]   mem_rdata_i,               // 读数据
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RRESP" *)
    input  [1:0]    mem_rresp_i,               // 读响应
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RID" *)
    input  [3:0]    mem_rid_i,                 // 读数据 ID
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RLAST" *)
    input           mem_rlast_i,               // 读突发最后一个数据
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 AXI RREADY" *)
    output          mem_rready_o               // 读数据准备好
);

// 命令定义
localparam REQ_WRITE        = 8'h10;  // 写命令
localparam REQ_READ         = 8'h11;  // 读命令

// 状态机定义
`define STATE_W        4
`define STATE_R        3:0
localparam STATE_IDLE       = 4'd0;   // 空闲状态
localparam STATE_LEN        = 4'd2;   // 接收长度
localparam STATE_ADDR0      = 4'd3;   // 接收地址字节3
localparam STATE_ADDR1      = 4'd4;   // 接收地址字节2
localparam STATE_ADDR2      = 4'd5;   // 接收地址字节1
localparam STATE_ADDR3      = 4'd6;   // 接收地址字节0
localparam STATE_WRITE      = 4'd7;   // 写数据状态
localparam STATE_READ       = 4'd8;   // 读数据状态
localparam STATE_DATA0      = 4'd9;   // 发送数据字节0
localparam STATE_DATA1      = 4'd10;  // 发送数据字节1
localparam STATE_DATA2      = 4'd11;  // 发送数据字节2
localparam STATE_DATA3      = 4'd12;  // 发送数据字节3

// UART 接口信号
wire [7:0] uart_wr_data_w;            // UART 发送数据
wire       uart_wr_busy_w;            // UART 发送忙
wire       uart_rd_w;                 // UART 接收使能
wire [7:0] uart_rd_data_w;            // UART 接收数据
wire       uart_rd_valid_w;           // UART 接收数据有效
wire       uart_rx_error_w;           // UART 接收错误

// FIFO 接口信号
wire       tx_valid_w;                // 发送 FIFO 写有效
wire [7:0] tx_data_w;                 // 发送 FIFO 写数据
wire       tx_accept_w;               // 发送 FIFO 写准备好
wire       rx_valid_w;                // 接收 FIFO 读有效
wire [7:0] rx_data_w;                 // 接收 FIFO 读数据
wire       rx_accept_w;               // 接收 FIFO 读使能

// FIFO 状态信号
wire tx_fifo_full;                    // 发送 FIFO 满
wire tx_fifo_empty;                   // 发送 FIFO 空
wire rx_fifo_full;                    // 接收 FIFO 满
wire rx_fifo_empty;                   // 接收 FIFO 空

// 寄存器定义
reg [31:0] mem_addr_q;                // 存储器地址
reg        mem_busy_q;                // 存储器忙标志
reg        mem_wr_q;                  // 写使能
reg [7:0]  len_q;                     // 传输长度
reg [1:0]  data_idx_q;                // 数据索引
reg [31:0] data_q;                    // 数据寄存器

// UART 实例化
uart #(
    .CLK_FREQ(CLK_FREQ),
    .BAUD_RATE(BAUD_RATE)
)u_uart (
    // 时钟与复位
    .clk_i(clk_i),
    .rst_i(rst_i),

    // 发送接口
    .wr_i(uart_wr_sync_reg),
    .data_i(uart_wr_data_w),
    .tx_busy_o(uart_wr_busy_w),

    // 接收接口
    .rd_i(rx_fifo_wr_en),
    .data_o(uart_rd_data_w),
    .rx_ready_o(uart_rd_valid_w),

    // UART 物理接口
    .rxd_i(uart_rxd_i),
    .txd_o(uart_txd_o)
);

// 发送 FIFO (UART 发送缓冲)
bram_fifo #(
    .DATA_WIDTH(8),
    .FIFO_DEPTH(2048),
    .ADDR_WIDTH(11))
tx_fifo (
    // 系统信号
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    // 写端口
    .din(tx_data_w),
    .wr_en(tx_valid_w),
    .full(tx_fifo_full),
    
    // 读端口
    .dout(uart_wr_data_w),
    .rd_en(uart_tx_pop_w),
    .empty(tx_fifo_empty)
);

// 接收 FIFO (UART 接收缓冲)
bram_fifo #(
    .DATA_WIDTH(8),
    .FIFO_DEPTH(2048),
    .ADDR_WIDTH(11))
rx_fifo (
    // 系统信号
    .clk_i(clk_i),
    .rst_i(rst_i),
    
    // 写端口
    .din(uart_rd_data_w),
    .wr_en(rx_fifo_wr_en),
    .full(rx_fifo_full),
    
    // 读端口
    .dout(rx_data_w),
    .rd_en(rx_accept_w),
    .empty(rx_fifo_empty)
);

// FIFO 控制信号
wire uart_tx_pop_w = !uart_wr_busy_w && !tx_fifo_empty && !uart_wr_sync_reg;
wire rx_fifo_wr_en = uart_rd_valid_w && !rx_fifo_full;
assign tx_accept_w = !tx_fifo_full;

// 状态寄存器
reg [`STATE_R] state_q;
reg [`STATE_R] next_state_r;

reg rx_valid_reg;
always @(posedge clk_i) begin
    rx_valid_reg <= !rx_fifo_empty;
end
assign rx_valid_w = rx_valid_reg;

reg uart_wr_sync_reg;
always @(posedge clk_i) begin
    uart_wr_sync_reg <= uart_tx_pop_w;
end

always @ * begin
    next_state_r = state_q;

    case (next_state_r)
        // IDLE: 空闲状态
        STATE_IDLE: begin
            if (rx_valid_w) begin
                case (rx_data_w)
                    REQ_WRITE,
                    REQ_READ: next_state_r = STATE_LEN;  // 接收长度
                    default: ;  // 忽略无效命令
                endcase
            end
        end
        
        // STATE_LEN: 接收传输长度
        STATE_LEN: begin
            if (rx_valid_w)
                next_state_r = STATE_ADDR0;
        end
        
        // STATE_ADDR: 接收地址(4字节)
        STATE_ADDR0: if (rx_valid_w) next_state_r = STATE_ADDR1;
        STATE_ADDR1: if (rx_valid_w) next_state_r = STATE_ADDR2;
        STATE_ADDR2: if (rx_valid_w) next_state_r = STATE_ADDR3;
        STATE_ADDR3: begin
            if (rx_valid_w && mem_wr_q) 
                next_state_r = STATE_WRITE;  // 写操作
            else if (rx_valid_w) 
                next_state_r = STATE_READ;    // 读操作            
        end
        
        // STATE_WRITE: 写数据到存储器
        STATE_WRITE: begin
            if (len_q == 8'b0 && (mem_bvalid_i))
                next_state_r = STATE_IDLE;    // 写完成
            else
                next_state_r = STATE_WRITE;   // 继续写
        end
        
        // STATE_READ: 从存储器读取数据
        STATE_READ: begin
            if (mem_rvalid_i)
                next_state_r = STATE_DATA0;   // 数据就绪
        end
        
        // STATE_DATA: 发送读取的数据(4字节)
        STATE_DATA0: begin
            if (tx_accept_w && (len_q == 8'b0))
                next_state_r = STATE_IDLE;
            else if (tx_accept_w)
                next_state_r = STATE_DATA1;
        end
        STATE_DATA1: begin
            if (tx_accept_w && (len_q == 8'b0))
                next_state_r = STATE_IDLE;
            else if (tx_accept_w)
                next_state_r = STATE_DATA2;
        end
        STATE_DATA2: begin
            if (tx_accept_w && (len_q == 8'b0))
                next_state_r = STATE_IDLE;
            else if (tx_accept_w)
                next_state_r = STATE_DATA3;
        end
        STATE_DATA3: begin
            if (tx_accept_w && (len_q != 8'b0))
                next_state_r = STATE_READ;    // 继续读
            else if (tx_accept_w)
                next_state_r = STATE_IDLE;    // 读完成
        end
        default: ;
    endcase
end

always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        state_q <= STATE_IDLE;
    else
        state_q <= next_state_r;
end

// UART 读写控制信号

// 发送 FIFO 写使能 (在发送数据状态有效)
assign tx_valid_w = ((state_q == STATE_DATA0) |
                    (state_q == STATE_DATA1) |
                    (state_q == STATE_DATA2) |
                    (state_q == STATE_DATA3));

// 接收 FIFO 读使能 (在接收数据状态有效)
assign rx_accept_w = (state_q == STATE_IDLE) |
                     (state_q == STATE_LEN) |
                     (state_q == STATE_ADDR0) |
                     (state_q == STATE_ADDR1) |
                     (state_q == STATE_ADDR2) |
                     (state_q == STATE_ADDR3) |
                     (state_q == STATE_WRITE && !mem_busy_q);

// 传输长度寄存器
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        len_q <= 8'd0;
    else if (state_q == STATE_LEN && rx_valid_w)
        len_q[7:0] <= rx_data_w;  // 捕获长度
    else if (state_q == STATE_WRITE && rx_valid_w && !mem_busy_q)
        len_q <= len_q - 8'd1;    // 写操作长度减1
    else if (state_q == STATE_READ && (mem_busy_q && mem_rvalid_i))
        len_q <= len_q - 8'd1;    // 读操作长度减1
    else if (((state_q == STATE_DATA0) || (state_q == STATE_DATA1) || 
             (state_q == STATE_DATA2)) && (tx_accept_w))
        len_q <= len_q - 8'd1;    // 发送数据长度减1
end

// 存储器地址寄存器
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        mem_addr_q <= 'd0;
    else if (state_q == STATE_ADDR0 && rx_valid_w)
        mem_addr_q[31:24] <= rx_data_w;  // 地址字节3
    else if (state_q == STATE_ADDR1 && rx_valid_w)
        mem_addr_q[23:16] <= rx_data_w;  // 地址字节2
    else if (state_q == STATE_ADDR2 && rx_valid_w)
        mem_addr_q[15:8] <= rx_data_w;   // 地址字节1
    else if (state_q == STATE_ADDR3 && rx_valid_w)
        mem_addr_q[7:0] <= rx_data_w;    // 地址字节0
    // 每次访问后地址递增4字节
    else if (state_q == STATE_WRITE && (mem_busy_q && mem_bvalid_i))
        mem_addr_q <= {mem_addr_q[31:2], 2'b0} + 'd4;
    else if (state_q == STATE_READ && (mem_busy_q && mem_rvalid_i))
        mem_addr_q <= {mem_addr_q[31:2], 2'b0} + 'd4;
end

// 数据索引寄存器 (用于字节对齐)
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        data_idx_q <= 2'b0;
    else if (state_q == STATE_ADDR3)
        data_idx_q <= rx_data_w[1:0];  // 从地址低2位初始化索引
    else if (state_q == STATE_WRITE && rx_valid_w && !mem_busy_q)
        data_idx_q <= data_idx_q + 2'd1;  // 写数据索引递增
    else if (((state_q == STATE_DATA0) || (state_q == STATE_DATA1) || 
             (state_q == STATE_DATA2)) && tx_accept_w && (data_idx_q != 2'b0))
        data_idx_q <= data_idx_q - 2'd1;  // 读数据索引递减
end

// 数据寄存器
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        data_q <= 32'b0;
    // 写操作: 从 UART 接收数据
    else if (state_q == STATE_WRITE && rx_valid_w && !mem_busy_q) begin
        case (data_idx_q)
            2'd0: data_q[7:0]   <= rx_data_w;
            2'd1: data_q[15:8]  <= rx_data_w;
            2'd2: data_q[23:16] <= rx_data_w;
            2'd3: data_q[31:24] <= rx_data_w;
        endcase  
    end
    // 读操作: 从存储器捕获数据
    else if (state_q == STATE_READ && mem_rvalid_i)
        data_q <= mem_rdata_i;
    // 发送数据: 右移数据
    else if (((state_q == STATE_DATA0) || (state_q == STATE_DATA1) || 
             (state_q == STATE_DATA2)) && (tx_accept_w))
        data_q <= {8'b0, data_q[31:8]};  // 右移8位准备发送下一个字节
end

// 发送数据选择最低字节
assign tx_data_w = data_q[7:0];                  

// 写数据输出
assign mem_wdata_o = data_q;

// AXI 写请求控制
reg mem_awvalid_q;
reg mem_awvalid_r;

reg mem_wvalid_q;
reg mem_wvalid_r;

// 写地址通道控制
always @ * begin
    mem_awvalid_r = 1'b0;

    // 保持有效直到被接受
    if (mem_awvalid_o && !mem_awready_i)
        mem_awvalid_r = mem_awvalid_q;
    else if (mem_awvalid_o)
        mem_awvalid_r = 1'b0;
    // 每4字节或最后字节发起写请求
    else if (state_q == STATE_WRITE && rx_valid_w && (data_idx_q == 2'd3 || len_q == 1))
        mem_awvalid_r = 1'b1;
end

// 写数据通道控制
always @ * begin
    mem_wvalid_r = 1'b0;

    // 保持有效直到被接受
    if (mem_wvalid_o && !mem_wready_i)
        mem_wvalid_r = mem_wvalid_q;
    else if (mem_wvalid_o)
        mem_wvalid_r = 1'b0;
    // 每4字节或最后字节发起写请求
    else if (state_q == STATE_WRITE && rx_valid_w && (data_idx_q == 2'd3 || len_q == 1))
        mem_wvalid_r = 1'b1;
end

// 写控制寄存器
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        mem_awvalid_q <= 1'b0;
        mem_wvalid_q  <= 1'b0;
    end else begin
        mem_awvalid_q <= mem_awvalid_r;
        mem_wvalid_q  <= mem_wvalid_r;
    end
end

// AXI 写接口信号
assign mem_awvalid_o = mem_awvalid_q;
assign mem_wvalid_o  = mem_wvalid_q;
assign mem_awaddr_o  = {mem_addr_q[31:2], 2'b0};  // 地址对齐到4字节
assign mem_awid_o    = AXI_ID;
assign mem_awlen_o   = 8'b0;       // 单次传输
assign mem_awburst_o = 2'b01;      // 增量突发
assign mem_wlast_o   = 1'b1;       // 总是单次传输
assign mem_bready_o  = 1'b1;       // 总是准备好接收响应

// AXI 读请求控制
reg mem_arvalid_q;
reg mem_arvalid_r;

// 读地址通道控制
always @ * begin
    mem_arvalid_r = 1'b0;

    // 保持有效直到被接受
    if (mem_arvalid_o && !mem_arready_i)
        mem_arvalid_r = mem_arvalid_q;
    else if (mem_arvalid_o)
        mem_arvalid_r = 1'b0;
    // 发起读请求
    else if (state_q == STATE_READ && !mem_busy_q)
        mem_arvalid_r = 1'b1;
end

// 读控制寄存器
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        mem_arvalid_q <= 1'b0;
    else
        mem_arvalid_q <= mem_arvalid_r;
end

// AXI 读接口信号
assign mem_arvalid_o = mem_arvalid_q;
assign mem_araddr_o  = {mem_addr_q[31:2], 2'b0};  // 地址对齐到4字节
assign mem_arid_o    = AXI_ID;
assign mem_arlen_o   = 8'b0;       // 单次传输
assign mem_arburst_o = 2'b01;      // 增量突发
assign mem_rready_o  = 1'b1;       // 总是准备好接收数据
assign mem_wstrb_o = 4'b1111;

// 写使能寄存器
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        mem_wr_q <= 1'b0;
    else if (state_q == STATE_IDLE && rx_valid_w)
        mem_wr_q <= (rx_data_w == REQ_WRITE);  // 根据命令设置写使能
end

// 存储器忙标志
always @ (posedge clk_i or posedge rst_i) begin
    if (rst_i)
        mem_busy_q <= 1'b0;
    else if (mem_arvalid_o || mem_awvalid_o)
        mem_busy_q <= 1'b1;        // 开始传输
    else if (mem_bvalid_i || mem_rvalid_i)
        mem_busy_q <= 1'b0;        // 传输完成
end

endmodule