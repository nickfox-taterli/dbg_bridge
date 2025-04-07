`timescale 1ns / 1ps

module tb_top();

    reg clk_i;
    reg rst_i;
    wire txd_o;
    reg rxd_i;
    
    integer i;

    // 实例化被测模块
    design_1_wrapper uut (
        .clk_100MHz(clk_i),
        .rst_n(rst_i),
        .UART_txd(txd_o),
        .UART_rxd(rxd_i)
    );

    // 生成50MHz时钟
    initial begin
        clk_i = 0;
        forever #5 clk_i = ~clk_i; // 10ns周期（100MHz）
    end

    // UART发送任务
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // 发送起始位
            rxd_i = 0;
            #8680; // 1/115200 ≈ 8680ns
            
            // 发送数据位（LSB first）
            for (i=0; i<8; i=i+1) begin
                rxd_i = data[i];
                #8680;
            end
            
            // 发送停止位
            rxd_i = 1;
            #8680;
        end
    endtask

    // 测试数据定义（固定大小数组）
    reg [7:0] test_data [0:20];
    
    // 初始化测试数据
    initial begin
        test_data[0] = 8'h10;
        test_data[1] = 8'h08;
        test_data[2] = 8'h00;
        test_data[3] = 8'h00;
        test_data[4] = 8'h10;
        test_data[5] = 8'h00;
        test_data[6] = 8'h11;
        test_data[7] = 8'h22;
        test_data[8] = 8'h33;
        test_data[9] = 8'h44;
        test_data[10] = 8'hAA;
        test_data[11] = 8'hBB;
        test_data[12] = 8'hCC;
        test_data[13] = 8'hDD;
        test_data[14] = 8'h11;
        test_data[15] = 8'h04;
        test_data[16] = 8'h00;
        test_data[17] = 8'h00;
        test_data[18] = 8'h10;
        test_data[19] = 8'h00;
    end

    // 主测试流程
    initial begin
        // 初始化信号
        rxd_i = 1; // UART空闲状态
        rst_i = 0; // 复位有效

        // 复位操作
        #1000 rst_i = 1; // 1us后释放复位

        // 等待系统稳定（可根据需要调整）
        #2000; 

        // 发送测试数据包
        for (i=0; i<20; i=i+1) begin
            uart_send_byte(test_data[i]);
        end

        // 添加观察时间
      #100000;
        $finish;
    end

endmodule