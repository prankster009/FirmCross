#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_INPUT_LENGTH 100
#define COMMAND_TEMPLATE "echo The number is %s"

int main() {
    char input[MAX_INPUT_LENGTH];
    int number;
    char command[256];

    // 提示用户输入一个数字
    printf("请输入一个数字: ");
    if (fgets(input, sizeof(input), stdin) == NULL) {
        fprintf(stderr, "读取输入失败\n");
        return 1;
    }

    // 去除输入字符串末尾的换行符
    input[strcspn(input, "\n")] = 0;

    // 使用 atoi 函数将输入转换为整数
    // number = atoi(input);

    // 将整数转换为字符串
    char number_str[MAX_INPUT_LENGTH];
    snprintf(number_str, sizeof(number_str), "%d", input);

    // 拼接命令
    snprintf(command, sizeof(command), COMMAND_TEMPLATE, number_str);

    // 执行命令
    int result = system(command);
    if (result == -1) {
        fprintf(stderr, "执行命令失败\n");
        return 1;
    }

    return 0;
}