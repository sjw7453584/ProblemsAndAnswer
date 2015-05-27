#!/bin/bash
if [ "$#" -lt "1" ];then
	echo "./buildtrunk.sh 'absolute path of trunk'"
	exit
fi 
d_path=$1
cd ${d_path}/trunk/Server/bigpiece/server_api/battle_server/src/; chmod +x ./build.sh ; ./build.sh
cd ${d_path}/trunk/Server/bigpiece/server_api/DBSvr/src/; chmod +x ./build.sh ; ./build.sh
cd ${d_path}/trunk/Server/bigpiece/server_api/ez_bench/ez_bench/; chmod +x ./build.sh ;./build.sh

# add execution right for execs
cd ${d_path}/trunk/Server/bigpiece/server_api/battle_server/bin/; chmod +x ./*
cd ${d_path}/trunk/Server/bigpiece/server_api/DBSvr/bin/; chmod +x ./*
