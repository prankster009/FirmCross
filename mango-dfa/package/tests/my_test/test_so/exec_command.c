#include <stdio.h>
#include <stdlib.h>

// 执行命令的函数
void execute_command(const char *command) {
    if (command == NULL) {
        return;
    }
    int result = system(command);
    if (result == -1) {
        perror("Failed to execute command");
    } else if (result != 0) {
        printf("Command execution failed with status %d\n", result);
    }
}
