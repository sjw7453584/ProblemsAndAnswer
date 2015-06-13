#!/bin/bash
if [ "$#" -lt "2" ];then
	echo "./buildtrunk.sh 'absolute path of source trunk' 'absolute path of dst trunk'"
	exit
fi 
s_path=$1
d_path=$2

# cp cmakelists.txt and build.sh
cp ${s_path}/trunk/Server/bigpiece/server_api/battle_server/src/CMakeLists.txt ${d_path}/trunk/Server/bigpiece/server_api/battle_server/src/
cp ${s_path}/trunk/Server/bigpiece/server_api/DBSvr/src/CMakeLists.txt ${d_path}/trunk/Server/bigpiece/server_api/DBSvr/src/
cp ${s_path}/trunk/Server/bigpiece/server_api/ez_bench/ez_bench/CMakeLists.txt ${d_path}/trunk/Server/bigpiece/server_api/ez_bench/ez_bench/

cp ${s_path}/trunk/Server/bigpiece/server_api/battle_server/src/build.sh ${d_path}/trunk/Server/bigpiece/server_api/battle_server/src/
cp ${s_path}/trunk/Server/bigpiece/server_api/DBSvr/src/build.sh ${d_path}/trunk/Server/bigpiece/server_api/DBSvr/src/
cp ${s_path}/trunk/Server/bigpiece/server_api/ez_bench/ez_bench/build.sh ${d_path}/trunk/Server/bigpiece/server_api/ez_bench/ez_bench/


# cp etc files
cp -r ${s_path}/trunk/Server/bigpiece/server_api/battle_server/etc ${d_path}/trunk/Server/bigpiece/server_api/battle_server/
cp -r ${s_path}/trunk/Server/bigpiece/server_api/DBSvr/etc ${d_path}/trunk/Server/bigpiece/server_api/DBSvr

# build
cd ${d_path}/trunk/Server/bigpiece/server_api/battle_server/src/; chmod +x ./build.sh ; ./build.sh
cd ${d_path}/trunk/Server/bigpiece/server_api/DBSvr/src/; chmod +x ./build.sh ; ./build.sh
cd ${d_path}/trunk/Server/bigpiece/server_api/ez_bench/ez_bench/; chmod +x ./build.sh ;./build.sh

# add execution right for execs
cd ${d_path}/trunk/Server/bigpiece/server_api/battle_server/bin/; chmod +x ./*
cd ${d_path}/trunk/Server/bigpiece/server_api/DBSvr/bin/; chmod +x ./*
