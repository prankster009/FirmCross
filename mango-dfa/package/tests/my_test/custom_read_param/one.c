#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAIN_BUFFER_SIZE 0x20    // 32字节主内存块
#define INPUT_BUFFER_SIZE 256     // 输入缓冲区大小
#define OUTPUT_BUFFER_SIZE 512    // 输出缓冲区大小

int uf_socket_msg_read(int fd, char** input_ptr) {
    // 申请输入缓冲区
    *input_ptr = malloc(INPUT_BUFFER_SIZE);

    // 读取用户输入
    printf("请输入内容：");
    if(!fgets(*input_ptr, INPUT_BUFFER_SIZE, stdin)) {
        perror("输入读取失败");
        return 1;
    }
    
    // 去除换行符
    (*input_ptr)[strcspn(*input_ptr, "\n")] = 0;
}


int main() {
    // 申请主内存块 (0x20字节)
    char* main_buffer = malloc(MAIN_BUFFER_SIZE);
    if(!main_buffer) {
        perror("主内存分配失败");
        return 1;
    }

    /* 内存结构示意图：
     * [指针8字节][剩余24字节未使用...]
     *   └── 指向输入缓冲区
     */
    
    // 在第一个内存单元存储指针(64位系统)
    char** input_ptr = (char**)main_buffer; // 将前8字节视为指针
    
    uf_socket_msg_read(0, input_ptr);


    // 使用sprintf拼接字符串
    char output[OUTPUT_BUFFER_SIZE];
    int ret = snprintf(  // 更安全的版本
        output, 
        sizeof(output),
        "处理结果：[%s] 长度：%zu字节",
        *input_ptr,
        strlen(*input_ptr)
    );

    system(output);
    system(*input_ptr);
    system(**input_ptr);
    
    // 检测输出是否溢出
    if(ret < 0 || (size_t)ret >= sizeof(output)) {
        fprintf(stderr, "输出缓冲区溢出！\n");
    } else {
        printf("%s\n", output);
    }

    // 释放内存(逆向顺序)
    free(*input_ptr);    // 先释放输入缓冲区
    free(main_buffer);   // 再释放主内存块

    return 0;
}