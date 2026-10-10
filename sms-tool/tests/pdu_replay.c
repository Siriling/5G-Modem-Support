#define _GNU_SOURCE
/* Modified by ainuoyan, 2026-10-10: allow synthetic original-PDU failure cases. */
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

/* A private pseudo terminal, never a physical modem: Chinese UCS2 + GBP. */
int main(int argc, char **argv)
{
    if (argc != 2 && argc != 3) return 2;
    const char *pdu = argc == 3 ? argv[2] :
        "0000049121430008620190210000000C4E2D658790018D39FF1A00A3";
    int master = posix_openpt(O_RDWR | O_NOCTTY);
    if (master < 0 || grantpt(master) || unlockpt(master)) return 2;
    char *slave = ptsname(master);
    if (!slave) { close(master); return 2; }
    pid_t child = fork();
    if (child < 0) { close(master); return 2; }
    if (child == 0) {
        close(master);
        execl(argv[1], argv[1], "-d", slave, "-j", "recv", (char *)NULL);
        _exit(127);
    }
    char command[512] = {0};
    size_t used = 0;
    int status;
    for (int tick = 0; tick < 150; tick++) {
        if (waitpid(child, &status, WNOHANG) == child) {
            close(master);
            return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
        }
        struct pollfd fd = { .fd = master, .events = POLLIN };
        if (poll(&fd, 1, 100) <= 0) continue;
        char input[128];
        ssize_t length = read(master, input, sizeof(input));
        if (length <= 0) { usleep(10000); continue; }
        for (ssize_t i = 0; i < length; i++) {
            if (input[i] == '\r' || input[i] == '\n') {
                command[used] = 0;
                if (strcmp(command, "AT+CMGF=0") == 0)
                    dprintf(master, "\r\nOK\r\n");
                if (strcmp(command, "AT+CMGL=4") == 0)
                    dprintf(master, "\r\n+CMGL: 1,1,,26\r\n%s\r\n\r\nOK\r\n", pdu);
                used = 0;
            } else if (used < sizeof(command) - 1) command[used++] = input[i];
        }
    }
    kill(child, SIGTERM);
    waitpid(child, &status, 0);
    close(master);
    return 1;
}
