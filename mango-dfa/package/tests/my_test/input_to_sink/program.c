#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_INPUT_LENGTH 100
#define COMMAND_TEMPLATE "echo The input is %s"

int main() {
    char input[MAX_INPUT_LENGTH];
    char command[256];

    // 提示用户输入一个字符串
    printf("请输入一个字符串: ");
    if (fgets(input, sizeof(input), stdin) == NULL) {
        fprintf(stderr, "读取输入失败\n");
        return 1;
    }

    // 去除输入字符串末尾的换行符
    input[strcspn(input, "\n")] = 0;

    // 拼接命令
    snprintf(command, sizeof(command), COMMAND_TEMPLATE, input);

    // 执行命令
    int result = system(command);
    if (result == -1) {
        fprintf(stderr, "执行命令失败\n");
        return 1;
    }

    return 0;
}