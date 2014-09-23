#!/bin/bash
Usage()
{
    echo "Usage: `basename $0` -i <config_xml>"
	echo "[-p]   use -p to automatically play the result vedio with ffplay "
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
				playVedio="yes"
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

	Parse_Label $Config_File "input_file"
	input_file=$label_value

	Parse_Label $Config_File "input_format"
	input_format=$label_value

	Parse_Label $Config_File "input_num"
	input_num=$label_value

	Parse_Label $Config_File "width"
	width=$label_value

	Parse_Label $Config_File "height"
	height=$label_value

    	
	Parse_Label $Config_File "bit_rate"
	bit_rate=$label_value

	Parse_Label $Config_File "output_dir"
	output_dir=$label_value
	if [ ! -e "$output_dir" ];then
		mkdir $output_dir
	fi 

	Parse_Label $Config_File "output_file"
	output_file=$label_value

	Parse_Label $Config_File "output_format"
	output_format=$label_value

	Parse_Label $Config_File "output_num"
	output_num=$label_value

	Parse_Label $Config_File "input_cmd"
	InputCmd=$label_value

	if [ "$InputCmd" = "" ];then
		InputCmd="p"
		for input_ch in $(seq 2 $input_num);do
			if [ "$input_format" = "h264" ];then 
				InputCmd=$InputCmd"d"
			else
				InputCmd=$InputCmd"c"
			fi 
			
		done
		
		# output_tmp=$output_format 
		for output_ch in $(seq 2 $output_num);do
			# if [ "$output_format" = "h264" ];then 
				InputCmd=$InputCmd"f"
			# else
				# InputCmd=$InputCmd"e"
				# output_format="h264"
			# fi 
			
		done

		# output_format=$output_tmp
	fi 
	echo "inputCmd:$InputCmd"
	
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
	echo "input_file:    $input_file"
	echo "input_format:  $input_format"
	echo "input_num:     $input_num"
	echo "width:         $width"
	echo "height:        $height"
	echo "bit_rate:      $bit_rate"
	echo "output_dir:    $output_dir"
	echo "output_file:   $output_file"
	echo "output_format: $output_format"
	echo "output_num:    $output_num"
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
	echo "	$binary_dir/$binary -i::$input_format $input_dir/$input_file -o::$output_format $output_dir/$output_file -w $width -h $height -b $bit_rate"
	# $binary_dir/$binary -i::$input_format $input_dir/$input_file -o::$output_format $output_dir/$output_file -w $width -h $height -b $bit_rate


	expect -c "
spawn 	$binary_dir/$binary -i::$input_format $input_dir/$input_file -o::$output_format $output_dir/$output_file -w $width -h $height -b $bit_rate
set timeout -1
expect {
\"Input Command\" {send \"${InputCmd}\r\";}
}

expect {
\"Got EOF in Encoder\" {send \"q\r\";}
}

expect eof
"
	if [ "$playVedio" = "yes" ];then
		ffplay $output_dir/$output_file -autoexit >/dev/null 
		if [[ $ouput_num > 1 ]];then 
			nfiletoPlay=$((output_num - 1))
			for file_n in $(seq 1 $nfiletoPlay);do 
				ffplay $output_dir/$output_file-$file_n -autoexit >/dev/null 
			done 

		fi 
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
