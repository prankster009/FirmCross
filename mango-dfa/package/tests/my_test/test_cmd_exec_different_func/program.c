#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_COMMAND_LENGTH 1024

// 读取用户输入的函数
void read_user_input(char *command) {
    printf("请输入要执行的命令: ");
    if (fgets(command, MAX_COMMAND_LENGTH, stdin) != NULL) {
        // 移除 fgets 读取时可能包含的换行符
        size_t len = strlen(command);
        if (len > 0 && command[len - 1] == '\n') {
            command[len - 1] = '\0';
        }
    }
}

void xxx123(char *command){
    printf(command);
    return;
}

// 执行命令的函数
void execute_command(const char *command) {
    if (command == NULL || *command == '\0') {
        printf("输入的命令为空，无法执行。\n");
        return;
    }
    xxx123(command);
    int result = system(command);
    if (result == -1) {
        perror("执行命令时出错");
    } else if (result != 0) {
        printf("命令执行失败，返回状态码: %d\n", result);
    }
}

int main() {
    char command[MAX_COMMAND_LENGTH];
    read_user_input(command);
    execute_command(command);
    return 0;
}
