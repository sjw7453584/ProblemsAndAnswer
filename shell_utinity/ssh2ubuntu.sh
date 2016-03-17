#!/bin/bash

expect -c "
spawn 	ssh sjw@172.24.16.195
set timeout -1

expect {
\"password\" {send \"sunjiwen\r\";}
}

expect eof
"
