#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_INPUT_LENGTH 100
#define COMMAND_TEMPLATE "echo The input is %s"

int uf_socket_msg_read(int fd, char *input) {
    return 1;
}

int main() {
    // int input[MAX_INPUT_LENGTH];
    // char ** input = malloc(0x20);
    char ** input;
    char command[256];

    uf_socket_msg_read(0, input);


    // 拼接命令
    snprintf(command, sizeof(command), COMMAND_TEMPLATE, **input);

    // 执行命令
    int result = system(command);
    if (result == -1) {
        fprintf(stderr, "执行命令失败\n");
    }

    return result == -1 ? 1 : 0;
}