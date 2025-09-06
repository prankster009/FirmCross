#include <stdio.h>
#include <stdlib.h>

int main() {
    // 定义要执行的命令
    const char *command = "ls -l ./";

    // 使用system函数执行命令
    int result = system(command);

    // 检查命令执行结果
    if (result == -1) {
        perror("Failed to execute command");
        return 1;
    } else if (result != 0) {
        printf("Command execution failed with status %d\n", result);
        return 1;
    }

    return 0;
}