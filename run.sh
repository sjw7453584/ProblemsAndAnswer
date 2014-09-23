#!/bin/bash
cmd=$1
input_cmd=$2
echo "cmd is $cmd"
expect -c "
spawn 	$cmd
set timeout -1
expect {
\"Input Command\" {send \"${InputCmd}\r\";}
}

expect {
\"Got EOF in Encoder\" {send \"q\r\";}
}

expect eof
"
