#!/bin/bash

expect -c "
spawn 	git push -u origin master
set timeout -1
expect {
\"Username\" {send \"sjw7453584\r\";}
}

expect {
\"Password\" {send \"sunjiwen7453584\r\";}
}

expect eof
"
