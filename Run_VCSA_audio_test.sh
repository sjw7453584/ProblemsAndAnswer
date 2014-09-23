#!/bin/bash
Usage()
{
    echo "Usage: `basename $0` -i <config_xml>"
	echo "[-p]   use -p to automatically play the result audio with ffplay "
	echo "[-t seconds]  use -t to specify the time interval you need to check
          config and case description,the default is 5"
}

Parse_External_Params()
{
    if [[ $# -lt 1 ]];then  
        echo "ERROR: No input parameters"
        Usage
        exit 1  
    fi   

	time_interval=5
    while getopts ":i:t:hp" optname
    do
        case "$optname" in
            "i")
				Config_File=$OPTARG
                ;;
			"t")
				time_interval=$OPTARG
                ;;
			"p")
				playAudio="yes"
				;;
			"h")
                Usage
                exit
                ;;
            "?")
                echo "ERROR : Unknown option $OPTARG"
                Usage
                exit
                ;;
            ":")
                echo "ERROR : No argument value for option $OPTARG"
                Usage
                exit
                ;;
            *)
                # Should not occur
                echo "Unknown error while processing options"
                ;;
        esac
    done
    APP=$0
    EXC_PATH=${APP%`basename $0`}
    External_Params_Validation
}

External_Params_Validation()
{
    if [ "$Config_File" = "NULL" ];then
        echo "ERROR : No option '-i' !"
        Usage
        exit
    elif [ ! -e "$Config_File" ];then
        echo "Error : <$Config_File> is not exist"
        Usage
        exit
    fi

}

Parse_CaseXML()
{
	Parse_Label $Config_File "case_id"
	case_id=$label_value

	Parse_Label $Config_File "case_name"
	case_name=$label_value

	Parse_Label $Config_File "case_description"
	case_description=$label_value

	Parse_Label $Config_File "binary_dir"
	binary_dir=$label_value
	export LD_LIBRARY_PATH=$EXC_PATH/$binary_dir:$LD_LIBRARY_PATH

	Parse_Label $Config_File "binary"
	binary=$label_value

	Parse_Label $Config_File "input_dir"
	input_dir=$label_value

	Parse_Label $Config_File "input_files"
	input_files=$label_value
	option_input=`echo $input_files | awk -vdir="$input_dir" -F ';' 'BEGIN{X="" ;} {for(i=1;i<=NF;i++){X="-i "dir"/"$(i)" "X;} } END {printf("%s",X);}'`
	input_num=`echo $input_files | awk -F ';' '{printf("%d",NF)}'`
	echo "input_num:$input_num"
	Parse_Label $Config_File "output_dir"
	output_dir=$label_value
	if [ ! -e "$output_dir" ];then
		mkdir $output_dir
	fi 

	Parse_Label $Config_File "log_file"
	log_file=$label_value
	Parse_Label $Config_File "log_level"
	log_file=$label_value

	if [ ! "$log_file" = "" -a ! "$log_level" = "" ];then
		option_log="--logfile $log_file --loglevel $log_level"
	fi 
		
	Parse_Label $Config_File "audio_resample"
	audio_resample=$label_value
	if [ ! "$audio_resample" = "" ];then
		option_audio_resample="--audio-resample $audio_resample"
	fi

	Parse_Label $Config_File "audio_denoise_front"
	audio_denoise_front=$label_value
	if [ ! "$audio_denoise_front" = "" ];then
		option_audio_denoise_front="--audio-denoise-front $audio_denoise_front"
	fi 
		
	Parse_Label $Config_File "audio_denoise_back"
	audio_denoise_back=$label_value
	if [ ! "$audio_denoise_back" = "" ];then
		option_audio_denoise_back="--audio-denoise-back $audio_denoise_back"
	fi 		

	Parse_Label $Config_File "audio_nn_mix"
	audio_nn_mix=$label_value
	if [ ! "$audio_nn_mix" = "" ];then
		option_audio_nn_mix="--audio-nn-mix $audio_nn_mix"
	fi 

	Parse_Label $Config_File "audio_vad"
	audio_vad=$label_value
	if [ ! "$audio_vad" = "" ];then
		option_audio_vad="--audio-vad $audio_vad"
	fi 

	Parse_Label $Config_File "audio_agc"
	audio_agc=$label_value
	if [ ! "$audio_agc" = "" ];then
		option_audio_agc="--audio-agc $audio_agc"
	fi

	Parse_Label $Config_File "config"
	config_file=$label_value
	if [ ! "$config_file" = "" ];then
		option_config_file="-f $config_file"
	fi
	
	Parse_Label $Config_File "output_file"
	output_file=$label_value
	option_output="-o $output_file"

	options="$option_input $option_output $option_audio_vad $option_audio_nn_mix $option_audio_agc $option_config_file $option_audio_denoise_back $option_audio_denoise_front $option_audio_resample $option_log"
	echo "$options"
}

Show_Config()
{
	if [ ! "$case_description" = "" ];then
		echo "*****************************case description*******************************"
		echo "$case_description"
		echo "*****************************case description end*******************************"
		sleep $time_interval
	fi 

    echo "**********************************************************************"
    echo "Config Information :"
	echo "case_id:       $case_id"
	echo "case_name:     $case_name"
	echo "binary_dir:    $binary_dir"
	echo "binary:        $binary"
	echo "input_dir:     $input_dir"
	echo "input_files:   $input_files"
	echo "output_dir:    $output_dir"
	echo "output_file:   $output_file"
    echo "**********************************************************************"

	sleep $time_interval
}


Parse_Label()
{
    local xml_file=$1
    local label=$2
    label_value=`cat $xml_file | grep "</$label>" | cut -d '>' -f 2 | cut -d '<' -f 1 | sed 's/^[ \t]*//;s/[ \t]*$//'| sed -n "1"'p'`
	if [ "$label_value" = "" ];then
        label_value=`sed -n "/<$label>/,/<\/$label>/"'p' $xml_file | grep -v -E "$label" | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -n 'p'`
	fi 
}


Run()
{
	echo "	$binary_dir/$binary  $options"
	$binary_dir/$binary  $options
	mv *$output_file $output_dir
	if [ "$playAudio" = "yes" ];then
		if [ "$audo-nn-mix" = "on" ];then
			output_num=$input_num
		else
			if [ "$binary" = "AudioMultiMixer" ];then
				output_num=$input_num
			else
				output_num=1
			fi 
		fi 

echo "output_num :${output_num}"
		for file_n in $(seq 1 $output_num);do 
			ffplay "$output_dir"/"$file_n"-$output_file -autoexit >/dev/null 
		done 
	fi

	read -p "please input test result:  p or P for parse , else for fail
>" test_result

	if [ "$test_result" = "p" -o "$test_result" = "P" ];then
		echo "PASS" >$output_dir/test_result_$case_id
	else
		echo "FAIL" >$output_dir/test_result_$case_id
	fi 





	
}

#start
Parse_External_Params $@
Parse_CaseXML
Show_Config
Run
