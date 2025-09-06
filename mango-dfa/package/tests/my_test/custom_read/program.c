#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_INPUT_LENGTH 100
#define COMMAND_TEMPLATE "echo The input is %s"

// 自定义输入读取函数
char* custom_read() {
    char* input = (char*)malloc(MAX_INPUT_LENGTH);
    if (input == NULL) {
        fprintf(stderr, "内存分配失败\n");
        return NULL;
    }

    if (fgets(input, MAX_INPUT_LENGTH, stdin) == NULL) {
        fprintf(stderr, "读取输入失败\n");
        free(input);
        return NULL;
    }

    // 去除输入字符串末尾的换行符
    input[strcspn(input, "\n")] = 0;
    return input;
}

int main() {
    char* input = custom_read();
    if (input == NULL) {
        return 1;
    }

    char command[256];

    // 拼接命令
    snprintf(command, sizeof(command), COMMAND_TEMPLATE, input);

    // 执行命令
    int result = system(command);
    if (result == -1) {
        fprintf(stderr, "执行命令失败\n");
    }

    // 释放动态分配的内存
    free(input);

    return result == -1 ? 1 : 0;
}