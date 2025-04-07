module uart #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    // 时钟与复位
    input        clk_i,     // 系统时钟
    input        rst_i,    // 低电平有效复位

    // 发送接口
    input        wr_i,      // 发送数据请求（上升沿有效）
    input  [7:0] data_i,    // 待发送数据
    output       tx_busy_o, // 发送忙状态指示

    // 接收接口
    input        rd_i,      // 接收数据读取确认
    output [7:0] data_o,    // 接收数据输出
    output       rx_ready_o,// 接收数据就绪标志

    // UART物理接口
    input       rxd_i,      // 串口接收引脚
    output reg  txd_o       // 串口发送引脚
);

// 根据系统时钟和波特率计算分频系数
localparam integer DIVIDER = (CLK_FREQ / BAUD_RATE) - 1;

// 接收状态机相关寄存器
reg [3:0]   recv_state;     // 接收状态（0-10）
reg [31:0]  recv_divcnt;    // 接收时钟分频计数器
reg [7:0]   recv_pattern;   // 接收数据移位寄存器
reg [7:0]   recv_buf_data;  // 接收数据缓冲
reg         recv_buf_valid;  // 接收数据有效标志

// 发送状态机相关寄存器
reg [9:0]   send_pattern;   // 发送数据移位寄存器（包含起始/停止位）
reg [3:0]   send_bitcnt;    // 发送位计数器
reg [31:0]  send_divcnt;    // 发送时钟分频计数器
reg         send_dummy;     // 发送空闲状态标志

// 接收数据输出
assign data_o = recv_buf_data;
assign rx_ready_o = recv_buf_valid;

// 发送忙状态：当发送位计数器工作或处于空闲状态时置位
assign tx_busy_o = (send_bitcnt != 0) | send_dummy;

// 接收状态机
always @(posedge clk_i) begin
    if (rst_i) begin  // 复位处理
        recv_state <= 0;
        recv_divcnt <= 0;
        recv_pattern <= 0;
        recv_buf_data <= 0;
        recv_buf_valid <= 0;
    end else begin
        recv_divcnt <= recv_divcnt + 1;  // 分频计数器递增
        
        // 读取确认信号处理
        if (rd_i) recv_buf_valid <= 0;
        
        case (recv_state)
            0: begin  // 状态0：等待起始位
                if (!rxd_i) begin  // 检测到起始位
                    recv_state <= 1;
                    recv_divcnt <= 0;
                end
            end
            1: begin  // 状态1：同步到起始位中点
                if (2 * recv_divcnt > DIVIDER) begin
                    recv_state <= 2;
                    recv_divcnt <= 0;
                end
            end
            10: begin // 状态10：处理停止位
                if (recv_divcnt > DIVIDER) begin
                    recv_buf_data <= recv_pattern;  // 锁存接收数据
                    recv_buf_valid <= 1;            // 置位数据有效标志
                    recv_state <= 0;                // 返回空闲状态
                end
            end
            default: begin  // 状态2-9：数据位采样
                if (recv_divcnt > DIVIDER) begin
                    // 右移采样（LSB first，最高位先采样）
                    recv_pattern <= {rxd_i, recv_pattern[7:1]};
                    recv_state <= recv_state + 1;
                    recv_divcnt <= 0;
                end
            end
        endcase
    end
end

// 发送状态机
always @(posedge clk_i) begin
    if (rst_i) begin  // 复位处理
        send_pattern <= 10'b1111111111;  // 保持发送线高电平
        send_bitcnt <= 0;
        send_divcnt <= 0;
        send_dummy <= 1;  // 初始处于空闲状态
    end else begin
        send_divcnt <= send_divcnt + 1;  // 分频计数器递增
        
        if (send_dummy && !send_bitcnt) begin  // 空闲状态处理
            send_pattern <= 10'b1111111111;
            send_bitcnt <= 10;  // 维持高电平
            send_divcnt <= 0;
            send_dummy <= 0;
        end else if (wr_i && !send_bitcnt) begin  // 新数据发送请求
            send_pattern <= {1'b1, data_i[7:0], 1'b0};  // 组装数据帧：停止位+数据+起始位
            send_bitcnt <= 10;      // 总发送位数（1起始+8数据+1停止）
            send_divcnt <= 0;
        end else if (send_divcnt > DIVIDER && send_bitcnt) begin  // 位发送时机
            send_pattern <= {1'b1, send_pattern[9:1]};  // 右移发送
            send_bitcnt <= send_bitcnt - 1;
            send_divcnt <= 0;
        end
        
        txd_o <= send_pattern[0];  // 输出当前最低位
    end
end

endmodule