#/bin/sh

Max_CPU=0
Avg_CPU=0
Total_Time=1

App=$0
EXC_PATH=${App%top.sh}
Process=$1
Interval=$2
gpuEnabled=$3
outputDir=$4
logFileName=$5
# Metrics=$3
# CaseType=$4

#mkdir -p output
# check the parameters
if [ $# -ne 5 ]; then
    echo "Usage: $0 ProcessName Interval isGpuEnabled outputDir logfileName"
    exit
fi

echo "process is $Process"
LogFile=""$EXC_PATH""$outputDir/"cpu_mem.txt"
# Waiting if the Process haven't started 
while true 
do 
    if ( pgrep $Process > "$EXC_PATH""$outputDir"/process_exist.log )  then
        break 
    fi
done
#collect gpu usage data
if [ "$gpuEnabled" = "yes" ];then
    sudo ./intel_gpu_top -s 1000000 -o "$EXC_PATH""$outputDir"/gpu_usage.log > "$EXC_PATH""$outputDir"/temp.log &
fi
while  sleep $Interval 
do
    if [ -f "$EXC_PATH""$outputDir"/"$logFileName" ]; then
        if ( grep "Done!!!!" "$EXC_PATH""$outputDir"/"$logFileName" > "$EXC_PATH""$outputDir"/file_tee.log ) then
            pkill $Process
        fi
    fi

    #Exit when the process finish
    if !( pgrep $Process > "$EXC_PATH""$outputDir"/process_exist.log )  then
        if [ "$gpuEnabled" = "yes" ];then
            sudo killall intel_gpu_top
        fi
        exit 
    fi
    #collect cpu and mem usage

    top  -d 1 -bn 1|grep $Process|grep -v grep|awk '{print $9"\t"$10}'|grep -v 0.0 |awk 'BEGIN{cpu=0;mem=0} {cpu+=$1;mem+=$2} END{print cpu"\t"mem}'>> $LogFile 


done
