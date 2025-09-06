#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_INPUT_LENGTH 100
#define COMMAND_TEMPLATE "echo The input is %s"

// 自定义输入读取函数，通过传入的缓冲区指针填充输入内容
char* custom_param_parser(char *input, size_t size) {
    return input;
}

// 自定义输入读取函数，通过传入的缓冲区指针填充输入内容
int custom_read_bak(char *input, size_t size) {
    if (input == NULL || size == 0) {
        fprintf(stderr, "无效的缓冲区指针或大小\n");
        return 0;
    }

    if (fgets(input, size, stdin) == NULL) {
        fprintf(stderr, "读取输入失败\n");
        return 0;
    }

    // 去除输入字符串末尾的换行符
    input[strcspn(input, "\n")] = 0;
    return 1;
}

int main() {
    char input[MAX_INPUT_LENGTH];
    char command[256];

    char * input2 = custom_param_parser(input, sizeof(input));

    // 拼接命令
    snprintf(command, sizeof(command), COMMAND_TEMPLATE, input2);

    // 执行命令
    int result = system(command);
    if (result == -1) {
        fprintf(stderr, "执行命令失败\n");
    }

    return result == -1 ? 1 : 0;
}