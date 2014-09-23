#!/bin/bash

# This is the performance test script for libVA file mode.
# Please run "$EXC_PATH"tools/install_prerequisites.sh to install require libs.

binary_dir="NULL"
run_mode="NULL"
Input[1]="NULL"
MAX_COMPOSITION_NUM=16
target_fps=29
# Show the usage of this script
#
# Params: null
# Return: null
Usage()
{
    echo ""
    echo "Usage: Perf_File.sh -f <config file> -e <result excel>"
    echo "[options]:"
    echo "-i <case xml>      - Specify case xml. If not set, will excute from test plan excel."
    echo "-p <binary dir>    - Specify path of binary. If not set, will use that defined in case xml"
    echo "-b <binary>        - Specify the test binary. If not set, will use that defined in case xml"
    echo "-o                 - Specify whether overwrite input_num in xml file"
    echo "-h                 - Show this usage."
}

# Parse external parameters and assign '-f' value to global variable 'Running_mode'
# and assign '-i' value to global variable 'Input'.
# Params: $@
# Return: null
Parse_External_Params()
{
    local index=1
    while getopts ":f:e:b:p:i:h:o" optname
    do
        case "$optname" in
            "f")
                global_setting=$OPTARG
                ;;
            "e")
                TestPlan_excel=$OPTARG
                ;;
            "b")
                binary_dir=$OPTARG
                export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$binary_dir
                ;;
            "p")
                Binary=$OPTARG
                ;;
            "i")
                Input[$index]=$OPTARG
                ((index=$index+1))
                ;;
			"o")
				Overwrite=true
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
    EXC_PATH=${APP%Perf_File.sh}
    External_Params_Validation
}

# validate the external parameters
#
# Params: null
# Return: null
External_Params_Validation()
{

    if [ "$global_setting" = "NULL" ];then
        echo "ERROR : No option '-f' ! "
        Usage
        exit
    elif [ ! -f "$global_setting" ];then
        echo "ERROR : <$global_setting> is not exist !"
        Usage
        exit
    fi

    if [ "$TestPlan_excel" = "NULL" ];then
        echo "ERROR : No option '-e' !"
        Usage
        exit
    elif [ ! -f "$TestPlan_excel" ];then
        echo "Error : <$TestPlan_excel> is not exist"
        Usage
        exit
    fi

    if [ "${Input[1]}" = "NULL" ];then
        run_mode=2
    elif [ "${Input[1]##*.}" = "xml" ];then
        run_mode=1
        if [ ! -f "${Input[1]}" ];then
            echo "ERROR : <${Input[1]}> not exist !"
            Usage
            exit
        fi
    else
        echo "ERROR: unsupport input file !"
        Usage
        exit
    fi

    if [ "$run_mode" = "1" ];then
        Case_Xml=${Input[1]}
    fi
}

#
#
#
#
Parse_GlobalSetting()
{
    local config_file=$1
    Case_Type=`cat $config_file | grep Case_type | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    XML_path=`cat $config_file | grep Case_path | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    Target_usage=`cat $config_file | grep Target_usage | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    metrics=`cat $config_file | grep Metrics | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    #OndemendServer_IP=`cat $config_file | grep Ondemend_server | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
}

# Using 'mediainfo' tool to analysis clip and get clip info for auto config.
#
# Params: clip
# Return: null
Clip_MediaInfo()
{
    local input_clip=$1
    mediainfo $input_clip > "$EXC_PATH"output/Input_clip_mediainfo.log
    sed -i 's/ //g' "$EXC_PATH"output/Input_clip_mediainfo.log
    MediaInfo_Format=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep Format | sed -n '1p'| cut -d ':' -f 2`
    if [ "$MediaInfo_Format" = "AVC" ];then
        MediaInfo_Format="h264"
    elif [ "$MediaInfo_Format" = "MPEGVideo" ];then
        MediaInfo_Format="m2v"
    elif [ "$MediaInfo_Format" = "VC-1" ];then
        MediaInfo_Format="vc1"
    elif [ "$MediaInfo_Format" = "VP8" ];then
        MediaInfo_Format="ivf"
    fi

    MediaInfo_Profile=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep profile | cut -d ':' -f 2|cut -d '@' -f 1`
    MediaInfo_Profile=`tr '[A-Z]' '[a-z]' <<<"$MediaInfo_Profile"`
    MediaInfo_Level=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep profile | cut -d ':' -f 2|cut -d '@' -f 2`
    MediaInfo_Level=${MediaInfo_Level#*L}
    MediaInfo_Level=${MediaInfo_Level/./""}
    MediaInfo_Bitrate=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep "Bitrate:" | cut -d ':' -f 2`
    MediaInfo_Bitrate=${MediaInfo_Bitrate%bps*}
    b_length=${#MediaInfo_Bitrate}
    b_level=${MediaInfo_Bitrate:$b_length-1}
    MediaInfo_Bitrate=${MediaInfo_Bitrate%K*}
    MediaInfo_Bitrate=${MediaInfo_Bitrate%M*}
    MediaInfo_Bitrate=${MediaInfo_Bitrate%.*}
    if [ ! "$MediaInfo_Bitrate" = "" ];then
        if [ "$b_level" = "K" ];then
            ((MediaInfo_Bitrate=$MediaInfo_Bitrate*1000))
        elif [ "$b_level" = "M" ];then
            ((MediaInfo_Bitrate=$MediaInfo_Bitrate*1000000))
        fi
    fi
    MediaInfo_Width=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep "Width" | cut -d ':' -f 2`
    MediaInfo_Width=${MediaInfo_Width%pix*}
    MediaInfo_Height=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep "Height" | cut -d ':' -f 2`
    MediaInfo_Height=${MediaInfo_Height%pix*}
    MediaInfo_ScanType=`cat "$EXC_PATH"output/Input_clip_mediainfo.log | grep "Scantype" | cut -d ':' -f 2`

}

# Validate the input clip, including existence validation, format supportable validation
# and invalid clip validation.
#
# Params: clip
# Return: true/false
InputClip_Validation()
{
    local input_file=$1

    if [ ! -f "$input_file" ];then
        echo "ERROR : <$input_file> is not exit !"
        Usage
        exit
    elif [ ! "${input_file##*.}" = "h264" -a ! "${input_file##*.}" = "264" -a ! "${input_file##*.}" = "m2v" -a ! "${input_file##*.}" = "vc1" -a ! "${input_file##*.}" = "ivf" ];then
        echo "ERROR: The file <$input_file> has invalid format !"
        Usage
        exit
    fi
    Clip_MediaInfo $input_file
    if [ "$MediaInfo_Format" = "" ];then
        echo "ERROR : The file <$input_file> is invalid !"
        exit
    fi
}

# Parse label value of case xml
#
# Params: xml, label, index
# Return: value
Parse_Label()
{
    local xml_file=$1
    local label=$2
    local index=$3
    label_value=`cat $xml_file | grep "</$label>" | cut -d '>' -f 2 | cut -d '<' -f 1 | sed -n "$index"'p'`
    in_num=`cat $xml_file | grep "Filename" | cut -d '>' -f 2 | cut -d '<' -f 1 | sed -n '$='`
    out_num=`cat $xml_file | grep "output_format" | cut -d '>' -f 2 | cut -d '<' -f 1 | sed -n '$='`
    if [ "$label_value" = "" ];then
        label_value=`sed -n "/<$label>/,/<\/$label>/"'p' $xml_file | grep -v -E "$label" | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -n "$index"'p'`
        in_num=`sed -n "/<Filename>/,/<\/Filename>/"'p' $xml_file | grep -v -E "Filename" | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -n '$='`
        out_num=`sed -n "/<output_format>/,/<\/output_format>/"'p' $xml_file | grep -v -E "output_format" | sed 's/^[ \t]*//;s/[ \t]*$//' | sed -n '$='`
    fi
}

# Parse case xml for input clips, encode parameters and so on.
#
# Params: xml name
# Return: null
Parse_CaseXML()
{
    XML_File=$1
    local In_index=1
    local Out_index=1
    In_Flag="no"
    Out_Flag="no"
    Parse_Label $XML_File "case_type" 1
    Case_Type=$label_value
    Parse_Label $XML_File "case_name" 1
    Case_Name=$label_value
    Parse_Label $XML_File "binarypath" 1
    BinaryPath_xml=$label_value
    Parse_Label $XML_File "binary" 1
    Binary_xml=$label_value

    if [ "$Binary" = "" ];then
        Binary=$Binary_xml;
    fi
    if [ "$binary_dir" = "NULL" ];then
        binary_dir=$BinaryPath_xml
    fi
    if [ ! -d "$binary_dir" ];then
        echo "ERROR : <$binary_dir> not exist !"
        Usage
        exit
    fi
    if [ ! -f "$binary_dir"/"$Binary" ];then
        echo "ERROR: $binary_dir$Binary is not ddddd exist !"
        exit
    fi
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$binary_dir

    local total_input=0
    for a in $(seq 1 $in_num)
    do
        Parse_Label $XML_File "Filename" $In_index
        clip=$label_value
        Parse_Label $XML_File "clip_folder" $In_index
        clip_folder=$label_value
		if [ "$Overwrite" = "true" -a ! "$Case_Type" =  "Perf_File2FileMBR" ];then
			read -p "please input channel number
>" Input_num
		else
			Parse_Label $XML_File "input_num" $In_index
			Input_num=$label_value
		fi
        if [ "$clip" = "" ];then
            In_Flag="yes"
        else
            InputClip_Validation $clip_folder"/"$clip
            Input_Clip_Array[$In_index]=$clip_folder"/"$clip
            Input_num_Array[$In_index]=$Input_num
            total_input=$(($Input_num+$total_input))
            In_index=$(($In_index+1))
        fi
    done
    ((In_index=$In_index-1))

    for b in $(seq 1 $out_num)
    do
        Parse_Label $XML_File "output_format" $Out_index
        local Format=$label_value

        if [ "$Format" = "" ];then
            Out_Flag="yes"
        else
            Output_Format=$Format
            if [ "$Output_Format" = "h264" ];then
                StreamType="H264"
            elif [ "$Output_Format" = "m2v" ];then
                StreamType="MPEG2"
            elif [ "$Output_Format" = "ivf" ];then
                StreamType="VP8"
            fi
            Parse_Label $XML_File "resolution" $Out_index
            Resolution=$label_value
            Width=${Resolution%x*}
            NumericalParams_Validation $Width
            local tem1=$?
            Height=${Resolution#*x}
            NumericalParams_Validation $Height
            local tem2=$?
            if [ "$tem1" = "0" -o "$tem2" = "0" ];then
                echo "ERROR: Invalid Resolution $Resolution !"
                exit
            fi

			Parse_Label $XML_File "targetUsage" $Out_index
			TargetUsage=$label_value
			if [[ $TargetUsage > 7 || $TargetUsage < 1 ]];then
				echo "ERROR: Invalid target usage"
				exit
			fi

			Parse_Label $XML_File "framerate" $Out_index
			FrameRate=$label_value

			Parse_Label $XML_File "ratectrl" $Out_index
			Ratectrl=$label_value
			
			Parse_Label $XML_File "gop" $Out_index
			Gop=$label_value
			
			Parse_Label $XML_File "gopType" $Out_index
			GopType=$label_value

			Parse_Label $XML_File "qp" $Out_index
			Qp=$label_value

			
            Parse_Label $XML_File "profile" $Out_index
            Profile=$label_value
            Params_Validation_profile $Profile $Output_Format
            local tem3=$?
            if [ "$tem3" = "0" ];then
                echo "ERROR: Invalid Profile $Profile !"
                exit
            fi
            Parse_Label $XML_File "level" $Out_index
            Level=$label_value
            Params_Validation_level $Level $Output_Format
            local tem4=$?
            if [ "$tem4" = "0" ];then
                echo "ERROR: Invalid Level $Level !"
                exit
            fi
            Parse_Label $XML_File "bitrate" $Out_index
            Bitrate=$label_value
            NumericalParams_Validation $Bitrate
            local tem5=$?
            if [ "$tem5" = "0" -o "$tem5" = "0" ];then
                echo "ERROR: Invalid Bitrate $Bitrate !"
                exit
            fi
			if [ "$Overwrite" = "true" -a "$Case_Type" = "Perf_MultiFile2File" ];then
				Output_num=${Input_num_Array[$Out_index]}
			else
				if [ "$Overwrite" = "true" -a "$Case_Type" = "Perf_File2FileMBR" ];then
					read -p "please input output channel number
> " Output_num
				else
					Parse_Label $XML_File "output_num" $Out_index
					Output_num=$label_value
				fi 
			fi 

			Output_Format_Array[$Out_index]=$Output_Format
            StreamType_Array[$Out_index]=$StreamType
            Width_Array[$Out_index]=$Width
            Height_Array[$Out_index]=$Height
            Profile_Array[$Out_index]=$Profile
            Level_Array[$Out_index]=$Level
            Bitrate_Array[$Out_index]=$Bitrate
            Output_num_Array[$Out_index]=$Output_num
			Gop_Array[$Out_index]=$Gop
			GopType_Array[$Out_index]=$GopType
			TargetUsage_Array[$Out_index]=$TargetUsage
			Ratectrl_Array[$Out_index]=$Ratectrl
			FrameRate_Array[$Out_index]=$FrameRate
			Qp_Array[$Out_index]=$Qp
            Out_index=$(($Out_index+1))

        fi
    done
    ((Out_index=$Out_index-1))

    if [ "$Case_Type" = "Perf_MultiFile2File" ];then
        if [ ! "$In_index" = "$Out_index" ];then
            echo "In:$In_index, Out:$Out_index"
            echo "ERROR: Parse xml failed! 1:1 Multichannel <input_num> and <output_num> are not match !"
            exit
        else
            for index in $(seq 1 $In_index)
            do
                if [ ! "${Input_num_Array[$index]}" = "${Output_num_Array[$index]}" ];then
					echo "In:${Input_num_Array[$index]}, Out:${Output_num}"
                    echo "ERROR: Parse xml failed! 1:1 Multichannel <input_num> and <output_num> are not match !"
                    exit
                fi
            done
        fi
    elif [ "$Case_Type" = "Perf_File2FileMBR" ];then
        if [ ! "$In_index" = "1" ];then
            echo "ERROR: Parse xml failed! 1:N MBR mode should have one input !"
            exit
        fi
    elif [ "$Case_Type" = "Perf_File2FileComposition" ];then
        if [ ! "$Out_index" = "1" ];then
            echo "ERROR: Parse xml failed! N:1 Composition should have one output !"
            exit
        fi
    fi

    input_num=0
    output_num=0
    if [ "$total_input" = "1" ];then
        divide=1
    elif [ "$total_input" -gt "1" -a "$total_input" -lt "5" ];then
        divide=2
    elif [ "$total_input" -gt "4" -a "$total_input" -lt "10" ];then
        divide=3
    elif [ "$total_input" -gt "9" -a "$total_input" -lt "17" ];then
        divide=4
    fi
    local total_x=${Width_Array[1]}
    local total_y=${Height_Array[1]}
    if [ "$Case_Type" = "Perf_MultiFile2File" ];then

        for index_multi in $(seq 1  $In_index)
        do
            for index_multi_ in $(seq 1 ${Input_num_Array[$index_multi]})
            do
                ((input_num=$input_num+1))

                local clip_name=${Input_Clip_Array[$index_multi]%.*}
                clip_name=$clip_name"_"$index_multi_
                local clip_format=${Input_Clip_Array[$index_multi]##*.}
                clip_new=$clip_name"."$clip_format
                Get_InputFormat ${Input_Clip_Array[$index_multi]}
                Generate_MSDK_par $input_format $clip_new ${Output_Format_Array[$index_multi]} "$EXC_PATH"output/output_"$input_num".${Output_Format_Array[$index_multi]}  ${Width_Array[$index_multi]} ${Height_Array[$index_multi]} ${Bitrate_Array[$index_multi]} ${FrameRate_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Gop_Array[$index_multi]}  ${GopType_Array[$index_multi]} ${Qp_Array[$index_multi]} >> "$EXC_PATH"config/par_"$Case_Type".par
                Generate_ConfigFile_In $input_num $clip_new 0 0 ${Width_Array[$index_multi]} ${Height_Array[$index_multi]} > "$EXC_PATH"config/config_$Case_Type-$input_num.ini
                Generate_ConfigFile_Out $input_num ${StreamType_Array[$index_multi]} ${Width_Array[$index_multi]} ${Height_Array[$index_multi]} ${Bitrate_Array[$index_multi]} ${Profile_Array[$index_multi]} ${Level_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${FrameRate_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]}  ${Output_Format_Array[$index_multi]} ${Qp_Array[$index_multi]} >> "$EXC_PATH"config/config_$Case_Type-$input_num.ini

				echo "                Generate_ConfigFile_Out $input_num ${StreamType_Array[$index_multi]} ${Width_Array[$index_multi]} ${Height_Array[$index_multi]} ${Bitrate_Array[$index_multi]} ${Profile_Array[$index_multi]} ${Level_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${FrameRate_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]}  ${Output_Format_Array[$index_multi]} ${Qp_Array[$index_multi]} >> "$EXC_PATH"config/config_$Case_Type-$input_num.ini
"
            done
        done
        output_num=$input_num

    else
        if [ $(echo "$total_input > $MAX_COMPOSITION_NUM"|bc) -eq 1 ];then
            echo "ERROR : Exceed max composition number $MAX_COMPOSITION_NUM !"
            exit
        else
            for index in $(seq 1 $In_index)
            do
                for index_ in $(seq 1 ${Input_num_Array[$index]})
                do

                    if [ "$Case_Type" = "Perf_File2FileMBR" ];then
                        pos_x=0
                        pos_y=0
                        pos_w=${Width_Array[1]}
                        pos_h=${Height_Array[1]}
                        clip_new=${Input_Clip_Array[$index]}
                    else
                        ((pos_w=$total_x/$divide))
                        ((pos_h=$total_y/$divide))
                        ((pos_x=$input_num%$divide))
                        ((pos_x=$pos_x*$pos_w))
                        ((pos_y=$input_num/$divide))
                        ((pos_y=$pos_y*$pos_h))
                        local clip_name=${Input_Clip_Array[$index]%.*}
                        clip_name=$clip_name"_"$index_
                        local clip_format=${Input_Clip_Array[$index]##*.}
                        clip_new=$clip_name"."$clip_format
                    fi
                    Generate_ConfigFile_In $input_num $clip_new $pos_x $pos_y $pos_w $pos_h >> "$EXC_PATH"config/config_$Case_Type.ini
                    Get_InputFormat ${Input_Clip_Array[$index]}
                    Generate_MSDK_par $input_format ${Input_Clip_Array[$index]} "sink" >> "$EXC_PATH"config/par_"$Case_Type".par
                    ((input_num=$input_num+1))
                done
            done
            for index_out in $(seq 1 $Out_index)
            do
                for index_out_ in $(seq 1 ${Output_num_Array[$index_out]})
                do
                    Generate_ConfigFile_Out $output_num ${StreamType_Array[$index_out]} ${Width_Array[$index_out]} ${Height_Array[$index_out]} ${Bitrate_Array[$index_out]} ${Profile_Array[$index_out]} ${Level_Array[$index_out]} ${TargetUsage_Array[$index_multi]}  ${FrameRate_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]} ${Output_Format_Array[$index_out]} ${Qp_Array[$index_multi]} >> "$EXC_PATH"config/config_$Case_Type.ini
                    Generate_MSDK_par "source" ${Input_Clip_Array[$index_out]} ${Output_Format_Array[$index_out]} "$EXC_PATH"output/output_"$output_num".${Output_Format_Array[$index_out]}  ${Width_Array[$index_out]} ${Height_Array[$index_out]} ${Bitrate_Array[$index_out]} ${FrameRate_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]} ${Qp_Array[$index_multi]} >> "$EXC_PATH"config/par_"$Case_Type".par
                    ((output_num=$output_num+1))
                done
            done
        fi
    fi
    Show_CaseInfo
}

# parse input clip for input format
#
# Params:clip
# Return:format
Get_InputFormat()
{
    local clip=$1
    local postfix=${clip##*.}
    if [ "$postfix" = "264" -o "$postfix" = "h264" ];then
        input_format="h264"
    elif [ "$postfix" = "m2v" -o "$postfix" = "mpeg2" ];then
        input_format="mpeg2"
    elif [ "$postfix" = "vc1" ];then
        input_format="vc1"
    fi
}

#
#
#
#
Show_CaseInfo()
{
    echo "==========================================="
    echo "Case_Type  = $Case_Type"
    echo "Case_Name  = $Case_Name"
    echo "clip       = $clip"
    echo "clip_folder= $clip_folder"
    echo "Input_num  = $Input_num"
    echo "Format     = $Format"
    echo "Resolution = $Resolution"
    echo "Profile    = $Profile"
    echo "Level      = $Level"
    echo "Bitrate    = $Bitrate"
    echo "Output_num = $Output_num"
    echo "==========================================="

}

# Parse xml file from itms, and parse input and encode params of every cases.
#
# Params: xml name
# Return: null
Parse_iTMS_XML()
{
    itms_xml=$1
    sed = $itms_xml | sed 'N;s/\n/\t/' | grep testcase  > "$EXC_PATH"output/numbered.xml
    sed -e 's/<testcase>//g' -e 's/<\/testcase>//g' -e 's/[ \t]*$//' "$EXC_PATH"output/numbered.xml > "$EXC_PATH"output/case_divided.log
    local index=1
    case_start_row=`sed -n "$index"'p' "$EXC_PATH"output/case_divided.log`
    while [ ! "$case_start_row" = "" ]
    do
        ((index=$index+1))
        case_end_row=`sed -n "$index"'p' "$EXC_PATH"output/case_divided.log`
        ((itms_case_num=$index/2))
        sed -n "$case_start_row","$case_end_row"'p' $itms_xml > "$EXC_PATH"itms_cases/case_$itms_case_num.xml
        ((index=$index+1))
        case_start_row=`sed -n "$index"'p' "$EXC_PATH"output/case_divided.log`
    done
}

# Set encode parameters
#
# Params: null
# Return: null
Params_setting()
{

    valid_format=""
    valid_resolution=""
    valid_profile=""
    valid_level=""
    valid_bitrate=""
    #Config Output format
    while [ ! "$valid_format" = "yes" ]
    do
        echo "Please select output file format :"
        echo "[1].H264  [2].MPEG2  [3].VP8"
        read -n 1 Output_Format
        if [ "$Output_Format" = "1" -o "$Output_Format" = "h" ];then
            StreamType=$Output_Format
            Output_Format="h264"
            valid_format="yes"
        elif [ "$Output_Format" = "2" -o "$Output_Format" = "m" ];then
            StreamType=$Output_Format
            Output_Format="m2v"
            valid_format="yes"
        elif [ "$Output_Format" = "3" -o "$Output_Format" = "v" ];then
            StreamType=$Output_Format
            Output_Format="ivf"
            valid_format="yes"
        else
            echo -e "\nInvalid input!"
        fi
    done
    echo -e "\nOutput Format = $Output_Format"
    #Config resolution
    while [ ! "$valid_resolution" = "yes" ]
    do
        echo "Please select transcode resolution :"
        echo "[1].1920x1080  [2].1280x720  [3].720x480  [4].352x288  [5].176x144   [6].manual input  [7].No Vpp "
        read -n 1 Resolution
        if [ "$Resolution" = "1" ];then
            Resolution="1920x1080"
            valid_resolution="yes"
        elif [ "$Resolution" = "2" ];then
            Resolution="1280x720"
            valid_resolution="yes"
        elif [ "$Resolution" = "3" ];then
            Resolution="720x480"
            valid_resolution="yes"
        elif [ "$Resolution" = "4" ];then
            Resolution="352x288"
            valid_resolution="yes"
        elif [ "$Resolution" = "5" ];then
            Resolution="176x144"
            valid_resolution="yes"
        elif [ "$Resolution" = "7" ];then
            Resolution="x"
            valid_resolution="yes"
        elif [ "$Resolution" = "6" ];then
            read -p "Width: " Width
            read -p "Height: " Height
            NumericalParams_Validation $Width
            local tem1=$?
            NumericalParams_Validation $Height
            local tem2=$?
            if [ "$tem1" = "1" -a "$tem2" = "1" ];then
                Resolution=$Width"x"$Height
                valid_resolution="yes"
            fi
        else
            echo -e "\nInvalid input!"
        fi
    done
    Width=${Resolution%x*}
    Height=${Resolution#*x}
    echo -e "\nResolution = $Resolution"

    #Config Profile
    while [ ! "$valid_profile" = "yes" ]
    do
        echo "Please select transcode profile :"
        echo "[1].high  [2].main  [3].baseline  [4].simple [5].manual input(0~3)"
        read -n 1 Profile
        if [ "$Profile" = "1" -o "$Profile" = "h" ];then
            Profile="high"
            valid_profile="yes"
        elif [ "$Profile" = "2" -o "$Profile" = "m" ];then
            Profile="main"
            valid_profile="yes"
        elif [ "$Profile" = "3" -o "$Profile" = "b" ];then
            Profile="baseline"
            valid_profile="yes"
        elif [ "$Profile" = "4" -o "$Profile" = "s" ];then
            Profile="simple"
            valid_profile="yes"
        elif [ "$Profile" = "5" ];then
            read -p "Profile (0~3): " Profile
            valid_profile="yes"
        else
            echo -e "\nInvalid input!"
        fi

        Params_Validation_profile $Profile $Output_Format
        local tem3=$?
        if [ "$tem3" = "0" ];then
            valid_profile="no"
        fi
    done
    echo -e "\nProfile = $Profile"

    #Config Level
    while [ ! "$valid_level" = "yes" ]
    do
        echo "Config encoding level:"
        echo "H264  encode: 41,40,31,30,20,11"
        echo "MPEG2 encode: Low(10),Main(8),High1440(6),High(4)"
        read -p "Please select encode level:" Level

        Params_Validation_level $Level $Output_Format
        local tem4=$?
        if [ "$tem4" = "1" ];then
            valid_level="yes"
        else
            valid_level="no"
        fi
    done
    echo -e "\nLevel = $Level"

    #Config bitrate
    while [ ! "$valid_bitrate" = "yes" ]
    do
        echo "Input the bitrate (bps): "
        read Bitrate
        NumericalParams_Validation $Bitrate
        local tem5=$?
        if [ "$tem5" = "1" ];then
            valid_bitrate="yes"
        else
            valid_bitrate="no"
        fi
    done
}

# Validate numerical params such as :bitrate and resolution
#
# Params: numerical param
# Return: true/false
NumericalParams_Validation()
{
    local param=$1
    valid_param=`expr match $param "[0-9][0-9]*$"`
    if [ "$valid_param" = "0" -o "$param" = "0" -o "$param" = "" ];then
        return 0
    fi
    return 1
}

# Validate profile
#
# Params: profile, encode format
# Return: true/false
Params_Validation_profile()
{

    local profile=$1
    local format=$2
    if [ "$format" = "ivf" ];then
        if [ "$profile" = "high" -o "$profile" = "main" -o "$profile" = "baseline" -o "$profile" = "simple" ];then
            echo "VP8 encode profile should be 0~3, Please select [5] to manual input !"
            return 0
        fi
    fi

    if [ "$format" = "h264" -a "$profile" = "sample" ];then
        echo "H264 encode can not support 'sample' profile ! "
        return 0
    fi

    if [ "$format" = "m2v" ];then
        if [ "$profile" = "high" -o "$profile" = "baseline" ];then
            echo "MPEG2 encode can not support 'high' and 'baseline' profile !"
            return 0
        fi
    fi
    return 1
}

# Validate level
#
# Params: level, encode format
# Return: true/false
Params_Validation_level()
{
    local level=$1
    local format=$2
    if [ "$format" = "h264" ];then
        if [ ! "$level" = "41" -a ! "$level" = "40" -a ! "$level" = "31" -a ! "$level" = "30" -a ! "$level" = "20" -a ! "$level" = "11" ];then
            return 0
        fi
    fi

    if [ "$format" = "m2v" ];then
        if [ ! "$level" = "10" -a ! "$level" = "8" -a ! "$level" = "6" -a ! "$level" = "4" ];then
            return 0
        fi
    fi

    return 1
}

# Generate msdk par file
#
# Params:
# Return:
Generate_MSDK_par()
{
    local input_format=$1
    local input_clip=$2
    local output_format=$3
    local output_name=$4
    local width=$5
    local height=$6
    local bitrate=$7
    local framerate=$8
    local usage=$9
	local ratectrl=${10}
	local gop=${11}
	local gopType=${12}
    if [ "$output_format" = "sink" ];then
        echo "-hw -i::$input_format $input_clip -o::$output_format -join"
    elif [ "$input_format" = "source" ];then
        echo "-hw -i::$input_format -o::$output_format $output_name -w $width -h $height -b $bitrate -f $framerate -u $usage -join"
    else
        echo "-hw -i::$input_format $input_clip -o::$output_format $output_name -w $width -h $height -b $bitrate -f $framerate -u $usage -async 2"
    fi
}

# Generate config file according input clips
#
# Params: number, input clip, x, y, w, h
# Return: null
Generate_ConfigFile_In()
{
    echo "[Input_$1]"
    echo "streamin=$2"
    echo "pos_x=$3"
    echo "pos_y=$4"
    echo "pos_w=$5"
    echo "pos_h=$6"
}

# Generate config parameters
#
# Params: number, output format, width. height, bitrate, profile, level, usage, format postfix
# Return: null
Generate_ConfigFile_Out()
{
    echo "[out_$1]"
    echo "streamout = "$EXC_PATH"output/out_$1.${13}"
    echo "streamType = $2"
    echo "width=$3"
    echo "height=$4"
    echo "framerate=${9}"
    echo "ratectrl=${10}"
    echo "bitrate=$5"
    echo "intra=${11}"
    echo "qp=${14}"
    echo "encMode=${12}"
    echo "profile=$6"
    echo "level=$7"
    echo "targetUsage=$8"
    echo "maxBframes=2"
    echo "progressive_sequence=1"
    echo "progressive_frame=1"
    echo "picture_structure=3"
    echo "aspect_ratio_info=1"
    echo "low_delay=0"
    echo "top_field_first=0"
    echo "concealment_motion_vectors=0"
    echo "q_scale_type=0"
    echo "intra_vlc_format=0"
    echo "alternate_scan=0"
    echo "repeat_first_field=0"
    echo "filename="$EXC_PATH"output/out_$1.${13}"
    echo "log_enable=1"
    echo "log_media=1"
    echo "log_level=2"
    echo "log_file=log_encoder.txt"

}

# Run the transcoding
#
# Params: null
# Return: null
Run()
{
    if [ "$Binary" = "libVA_file_xcoder" -o "$Binary" = "msdk_file_xcoder" ];then
		if [ "$Binary" = "libVA_file_xcoder" ];then 
		"$EXC_PATH"tools/top.sh libVA_file_xcod 1 $metrics $Case_Type &
		else
			"$EXC_PATH"tools/top.sh msdk_file_xcode 1 $metrics $Case_Type &
		fi 
        if [ "$Case_Type" = "Perf_MultiFile2File" ];then
            for index in $(seq 1 $input_num)
            do
                $binary_dir/$Binary -f "$EXC_PATH"config/config_$Case_Type-$index.ini > "$EXC_PATH"output/$Case_Type-$index.log &
            done
        else
            $binary_dir/$Binary -f "$EXC_PATH"config/config_$Case_Type.ini > "$EXC_PATH"output/$Case_Type.log
        fi
    elif [ "$Binary" = "sample_multi_transcode_drm" ];then
        "$EXC_PATH"tools/top.sh sample_multi_tr 1 $metrics $Case_Type &
        ${binary_dir}$Binary -f "$EXC_PATH"config/par_"$Case_Type".par > "$EXC_PATH"output/MSDK_$Case_Type.log
    fi
    wait
    echo "Processing Done!"
    echo "Detail information Please reference: "$EXC_PATH"output/PerfData.log "

}

#
#
#
#
Get_MSDK_PerfData()
{
    local data_index=1
    local total_fps=0
    local processing_time=`cat "$EXC_PATH"output/MSDK_$Case_Type.log | grep "Processing time" | cut -d ':' -f 2 | cut -d ' ' -f 2 | sed 's/^[ \t]*//' | sed -n "$data_index"'p'`
    local frame_num=`cat "$EXC_PATH"output/MSDK_$Case_Type.log | grep "Number of processed frames" | cut -d ':' -f 2 | sed 's/^[ \t]*//' | sed -n "$data_index"'p'`
    while [ ! "$processing_time" = "" -a ! "$frame_num" = "" ]
    do
        local fps=`echo "scale=2; $frame_num/$processing_time"|bc`
        total_fps=`echo "scale=2; $total_fps+$fps"|bc`
        ((data_index=$data_index+1))
        processing_time=`cat "$EXC_PATH"output/MSDK_$Case_Type.log | grep "Processing time" | cut -d ':' -f 2 | cut -d ' ' -f 2 | sed 's/^[ \t]*//' | sed -n "$data_index"'p'`
        frame_num=`cat "$EXC_PATH"output/MSDK_$Case_Type.log | grep "Number of processed frames" | cut -d ':' -f 2 | sed 's/^[ \t]*//' | sed -n "$data_index"'p'`
    done
    ((data_index=$data_index-1))
    wait
    echo "******************************************************************"
    echo "                Performance Statistics :"
    echo "******************************************************************"
    eval $(awk '{a+=$1;b+=$2} END {printf("avgcpu=%.1f\navgmem=%.1f", a/(NR*8),b/NR);}' "$EXC_PATH"output/cpu_mem.txt)

    if [ ! "$metrics" = "2" ];then
        sed -i '1d' "$EXC_PATH"output/gpu_usage.log
        eval $(awk '{b+=$2} END {printf("avggpu=%.1f", b/NR);}' "$EXC_PATH"output/gpu_usage.log)
    fi

    #Test_Result
    local avgfps=`echo "scale=2; $total_fps/$data_index"|bc`
    if [ $(echo "$avgfps > $target_fps"|bc) -eq 1 ];then
        test_result="Pass"
    else
        test_result="Fail"
    fi

    echo "Avg  FPS  : $avgfps"
    if [ ! "$metrics" = "4" ];then
        echo "CPU Util. : $avgcpu%"
    fi
    if [ ! "$metrics" = "2" ];then
        echo "GPU Util. : $avggpu%"
    fi
    if [ ! "$metrics" = "3" ];then
        echo "Mem Util. : $avgmem%"
    fi
    echo "******************************************************************"
    echo "Case Name:$Case_Name"
    echo "Test Result:$test_result"

}
# Get the performance data
#
# Params: null
# Return: null
Get_PerfData()
{
    wait
    echo "******************************************************************"
    echo "                Performance Statistics :"
    echo "******************************************************************"
    if [ "$Case_Type" = "Perf_MultiFile2File" ];then
        eval $(awk '{a+=$1;b+=$2} END {printf("avgcpu=%.1f\navgmem=%.1f", (a/(NR*8))*'"$input_num"',(b/NR)*'"$input_num"');}' "$EXC_PATH"output/cpu_mem.txt)
    else
        eval $(awk '{a+=$1;b+=$2} END {printf("avgcpu=%.1f\navgmem=%.1f", a/(NR*8),b/NR);}' "$EXC_PATH"output/cpu_mem.txt)
    fi

    if [ ! "$metrics" = "2" ];then
        sed -i '1d' "$EXC_PATH"output/gpu_usage.log
        eval $(awk '{b+=$2} END {printf("avggpu=%.1f", b/NR);}' "$EXC_PATH"output/gpu_usage.log)
    fi

    Test_Result
    if [ ! "$metrics" = "4" ];then
        echo "CPU Util. : $avgcpu%"
    fi
    if [ ! "$metrics" = "2" ];then
        echo "GPU Util. : $avggpu%"
    fi
    if [ ! "$metrics" = "3" ];then
        echo "Mem Util. : $avgmem%"
    fi
    echo "******************************************************************"
    echo "Case Name:$Case_Name"
    echo "Test Result:$test_result"

    if [ "$Case_Type" = "Perf_MultiFile2File" ];then
        for index_log in $(seq 1 $input_num)
        do
            echo "******************************************************************"
            echo "                       [ Channel $index_log ]"
            echo "******************************************************************"
            echo "        Encode Parameters"
            echo "*********************************"
            cat "$EXC_PATH"output/$Case_Type-$index_log.log | grep Input | sed -n '2p'| sed 's/^[ \t]*//'
            cat "$EXC_PATH"output/$Case_Type-$index_log.log | grep -E 'Width|Height|Profile|Level|time_scale|bitRate|RateCtrl|EncodingMode|IntraPeroid|QPValue|targetUsage'| sed 's/^[ \t]*//'
            echo "*********************************"
            echo "            Decode"
            echo "*********************************"
            cat "$EXC_PATH"output/$Case_Type-$index_log.log | grep -E 'DecodeNum|AvgDecodeLatency'| sed 's/^[ \t]*//'
            echo "*********************************"
            echo "            Encode"
            echo "*********************************"
            cat "$EXC_PATH"output/$Case_Type-$index_log.log | grep -E 'EncodedNum|AvgVPPLatency|AvgEncLatency|FirstFrameLatency|MaxFrameLatency|MinFrameLatency|AvgFrameLatency|ChannelDuration|AvgFPS'|sed 's/^[ \t]*//'
        done
    elif [ "$Case_Type" = "Perf_File2FileMBR" ];then

        echo "*********************************"
        echo "            Decode"
        echo "*********************************"
        cat "$EXC_PATH"output/$Case_Type.log | grep -E 'DecodeNum|AvgDecodeLatency'| sed 's/^[ \t]*//'

        for a in $(seq 1 $output_num)
        do

            echo "******************************************************************"
            echo "                       [Output Channel $a ]"
            echo "******************************************************************"
            echo "        Encode Parameters"
            echo "*********************************"
            cat "$EXC_PATH"output/$Case_Type.log | grep Input | sed -n '3p'| sed 's/^[ \t]*//'
            sed -n "/<AVC Encoding Params> channel $a of $output_num/,/INFO/"'p' "$EXC_PATH"output/$Case_Type.log| grep -E 'Width|Height|Profile|Level|time_scale|bitRate|RateCtrl|EncodingMode|IntraPeroid|QPValue|targetUsage'| sed 's/^[ \t]*//'

            echo "*********************************"
            echo "            Encode"
            echo "*********************************"
            sed -n "/<AVCENC> channel $a of $output_num/,/INFO/"'p' "$EXC_PATH"output/$Case_Type.log | grep -E 'EncodedNum|AvgVPPLatency|AvgEncLatency|FirstFrameLatency|MaxFrameLatency|MinFrameLatency|AvgFrameLatency|ChannelDuration|AvgFPS'| sed 's/^[ \t]*//'
        done

    elif [ "$Case_Type" = "Perf_File2FileComposition" ];then

        for index_com in $(seq 1 $input_num)
        do
            echo "******************************************************************"
            echo "                       [Input Channel $index_com ]"
            echo "******************************************************************"
            cat "$EXC_PATH"output/$Case_Type.log | grep "Input   " | sed -n "$index_com"'p'| sed 's/^[ \t]*//'
            sed -n "/<AVCDEC> channel $index_com of $input_num/,/INFO/"'p' "$EXC_PATH"output/$Case_Type.log | grep -E 'DecodeNum|AvgDecodeLatency'| sed 's/^[ \t]*//'
        done

        echo "*********************************"
        echo "        Encode Parameters"
        echo "*********************************"
        cat "$EXC_PATH"output/$Case_Type.log | grep -E 'Width|Height|Profile|Level|time_scale|bitRate|RateCtrl|EncodingMode|IntraPeroid|QPValue|targetUsage'| sed 's/^[ \t]*//'

        echo "*********************************"
        echo "            Encode"
        echo "*********************************"
        cat "$EXC_PATH"output/$Case_Type.log | grep -E 'EncodedNum|AvgVPPLatency|AvgEncLatency|FirstFrameLatency|MaxFrameLatency|MinFrameLatency|AvgFrameLatency|ChannelDuration|AvgFPS'| sed 's/^[ \t]*//'
    fi
}

# Write perfprmance data to excel
#
# Params: null
# Return: null
Write_Excel()
{

	if [ ! "$Overwrite" = "true" ];then
		
		channel_col=3
		cpu_col=4
		gpu_col=5
		mem_col=6
		fps_col=8
	# AvgLatency_col=9
	# AvgDecodeLatency_col=9
	# AvgVPPLatency_col=10
	# AvgEncLatency_col=11
		FirstFrameLatency_col=9
	# MaxFrameLatency_col=13
	# MinFrameLatency_col=14 
	# AvgFrameLatency_col=15
		
    #target_fps=30
		status_col=13
	else
		sheet="Perf_data"
		channel_col=24 
		cpu_col=27
		gpu_col=29
		mem_col=28 
		fps_col=25
	# AvgLatency_col=9
	# AvgDecodeLatency_col=9
	# AvgVPPLatency_col=10
	# AvgEncLatency_col=11
		FirstFrameLatency_col=26
	# MaxFrameLatency_col=13
	# MinFrameLatency_col=14 
	# AvgFrameLatency_col=15
		
    #target_fps=30
		status_col=13
	fi 
    #GenerateCaseName
    let "Data_row=$output_num+7"
    echo "Writing data to excel ..."
    #Find the right position in excel
    echo "offset=$offset $Case_Row"
    Case_Row=$(($Case_Row+$offset))
	strTmp="$AvgDecodeLatency $AvgEncLatency"
	AvgLatency=$(echo ${strTmp// /+} |bc -l)

    echo "Input_excel : $Input_excel"
    echo "sheet : $sheet"
    echo "Case_Row : $Case_Row"
    echo "Case_Type: $Case_Type"
    echo "output_num : $output_num"
    echo "input_num : $input_num"
    echo "avgcpu : $avgcpu"
    echo "avggpu : $avggpu"
    echo "avgmem : $avgmem"
    echo "avgfps : $avgfps"
	echo "AvgDecodeLatency:$AvgDecodeLatency"
	echo "AvgVPPLatency:$AvgVPPLatency"
	echo "AvgEncLatency:$AvgEncLatency"
	echo "FirstFrameLatency:$FirstFrameLatency"
	echo "MaxFrameLatency:$MaxFrameLatency"
	echo "MinFrameLatency:$MinFrameLatency"
	echo "AvgFrameLatency:$AvgFrameLatency"


	if [ -e final_result.txt ];then
		rm final_result.txt
	fi 
		
	echo "Case : $Case_Name" >>"$EXC_PATH"output/final_result.txt
	echo "Case_Type: $Case_Type" >>"$EXC_PATH"output/finale_result.txt

	if [ "$Case_Type" = Perf_File2FileComposition ];then
		max_channel=$input_num
	else
		max_channel=$Output_num
	fi 

    echo "max_channel : $max_channel" >>"$EXC_PATH"output/finale_result.txt
    echo "avgcpu : $avgcpu" >>"$EXC_PATH"output/finale_result.txt
    echo "avggpu : $avggpu" >>"$EXC_PATH"output/finale_result.txt
    echo "avgmem : $avgmem" >>"$EXC_PATH"output/finale_result.txt
    echo "avgfps : $avgfps" >>"$EXC_PATH"output/finale_result.txt
	echo "AvgDecodeLatency:$AvgDecodeLatency" >>"$EXC_PATH"output/finale_result.txt
	echo "AvgVPPLatency:$AvgVPPLatency" >>"$EXC_PATH"output/finale_result.txt
	echo "AvgEncLatency:$AvgEncLatency" >>"$EXC_PATH"output/finale_result.txt
	echo "FirstFrameLatency:$FirstFrameLatency" >>"$EXC_PATH"output/finale_result.txt
	echo "MaxFrameLatency:$MaxFrameLatency" >>"$EXC_PATH"output/finale_result.txt
	echo "MinFrameLatency:$MinFrameLatency" >>"$EXC_PATH"output/finale_result.txt
	echo "AvgFrameLatency:$AvgFrameLatency" >>"$EXC_PATH"output/finale_result.txt

    if [ "$Case_Type" = "Perf_File2FileComposition" ];then
        "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $channel_col $input_num 0
    else
        "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $channel_col $output_num 0
    fi
    if [ ! "$metrics" = "4" ];then
        "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $cpu_col $avgcpu 0
    fi
    if [ ! "$metrics" = "2" ];then
        "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $gpu_col $avggpu 0 
    fi
    if [ ! "$metrics" = "3" ];then
        "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $mem_col $avgmem 0
    fi
    "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $fps_col "$avgfps " 0
	# "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgLatency_col  "$AvgLatency "  0

    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgDecodeLatency_col  "$AvgDecodeLatency "  0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgVPPLatency_col  "$AvgVPPLatency " 0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgEncLatency_col  "$AvgEncLatency " 0
    "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $FirstFrameLatency_col  "$FirstFrameLatency " 0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $MaxFrameLatency_col  "$MaxFrameLatency "  0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $MinFrameLatency_col "$MinFrameLatency " 0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgFrameLatency_col "$AvgFrameLatency " 0

	
	if [ ! "$Overwrite" = "true" ];then
		
		if [ $(echo "$avgfps > $target_fps"|bc) -eq 1 ];then
			"$EXC_PATH"tools/write_excel $Input_excel $summary_sheet $status_row $status_col "Pass" 0
		else
			"$EXC_PATH"tools/write_excel $Input_excel $summary_sheet $status_row $status_col "Fail" 0
		fi
	fi 
}

#
#
#
#
Test_Result()
{
    if [ "$Case_Type" = "Perf_File2FileComposition" ];then
        avgfps=`cat "$EXC_PATH"output/$Case_Type.log | grep AvgFPS |sed 's/ //g' | cut -d '=' -f 2 `
		AvgDecodeLatency=`"$EXC_PATH"output/$Case_Type.log | grep AvgDecodeLatency |sed 's/ //g' | cut -d '=' -f 2 `
		AvgVPPLatency=`"$EXC_PATH"output/$Case_Type.log | grep AvgVPPLatency |sed 's/ //g' | cut -d '=' -f 2 `
		AvgEncLatency=`"$EXC_PATH"output/$Case_Type.log | grep AvgEncLatency |sed 's/ //g' | cut -d '=' -f 2 `
		FirstFrameLatency=`"$EXC_PATH"output/$Case_Type.log | grep FirstFrameLatency |sed 's/ //g' | cut -d '=' -f 2 `
		MaxFrameLatency=`"$EXC_PATH"output/$Case_Type.log | grep MaxFrameLatency |sed 's/ //g' | cut -d '=' -f 2 `
		MinFrameLatency=`"$EXC_PATH"output/$Case_Type.log | grep MinFrameLatency |sed 's/ //g' | cut -d '=' -f 2 `
		AvgFrameLatency=`"$EXC_PATH"output/$Case_Type.log | grep AvgFrameLatency |sed 's/ //g' | cut -d '=' -f 2 `
    else
        avgfps=`cat "$EXC_PATH"output/$Case_Type*.log | grep AvgFPS |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		AvgDecodeLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep AvgDecodeLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		AvgVPPLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep AvgVPPLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		FirstFrameLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep FirstFrameLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		MaxFrameLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep MaxFrameLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		MinFrameLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep MinFrameLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		AvgFrameLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep AvgFrameLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`
		AvgEncLatency=`cat "$EXC_PATH"output/$Case_Type*.log | grep AvgEncLatency |sed 's/ //g'|cut -d '=' -f 2 | awk '{a+=$1} END {printf("%.1f",a/'"$output_num"')}'`

    fi

    if [ $(echo "$avgfps > $target_fps"|bc) -eq 1 ];then
        test_result="Pass"
    else
        test_result="Fail"
    fi
    echo "Avg  FPS  : $avgfps"
	echo "Avg  DecodeLatency  : $AvgDecodeLatency"
	echo "Avg  EncodeLatency  : $AvgEncLatency"
	echo "Avg  FirstFrameLatency  : $FirstFrameLatency"
	echo "Avg  MaxFrameLatency  : $MaxFrameLatency"
	echo "Avg  MinFrameLatency  : $MinFrameLatency"
	echo "Avg  FrameLatency  : $AvgFrameLatency"

}

#
#
# Params: Excel
#
Parse_Excel()
{

    Input_excel=$1
    mkdir -p "$EXC_PATH"Test_Plan
    sub_name=${Input_excel%.*}
    sub_name=${sub_name##*/}
    summary_sheet="Performance"
    if [ "$Case_Type" = "Perf_MultiFile2File" ];then
        sheet="Performance_F_MultiChannel"
    elif [ "$Case_Type" = "Perf_File2FileMBR" ];then
        sheet="Performance_F_MBR"
    elif [ "$Case_Type" = "Perf_File2FileComposition" ];then
        sheet="Performance_F_Composition"
    fi
    echo "EXCEL : $Input_excel"
    echo "SHEET : $sheet"
    "$EXC_PATH"tools/parse_excel $Input_excel $sheet all 1 2 3 > "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log
    "$EXC_PATH"tools/parse_excel $Input_excel $summary_sheet all 14  8 6 > "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    "$EXC_PATH"tools/parse_excel $Input_excel $summary_sheet all 11  8 6 > "$EXC_PATH"Test_Plan/$sub_name"_"AllCase.log
    sed -i '/Performance/!d' "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log
    sed -i '/Planned/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    #Only test Multichannel
    if [ "$Case_Type" = "Perf_MultiFile2File" ];then
        sed -i '/Media_Performance_File_M_/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    elif [ "$Case_Type" = "Perf_File2FileMBR" ];then
        sed -i '/Media_Performance_File_MBR_/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    elif [ "$Case_Type" = "Perf_File2FileComposition" ];then
        sed -i '/Media_Performance_File_Composition_/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    fi
    Total_planned_case_num=`wc -l "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 1`
    if [ "$run_mode" = "2" ];then
        echo "Total case number : $Total_planned_case_num"
    fi
}
####################################################################
#START
####################################################################

Parse_External_Params $@
mkdir -p "$EXC_PATH"output
mkdir -p "$EXC_PATH"config
rm -rf "$EXC_PATH"output/*
Parse_GlobalSetting $global_setting

isContinue=y
while [ "$isContinue" = "y" -o "$isContinue" = "Y" ]
do 
	if [ "$run_mode" = "1" ];then
		rm -rf "$EXC_PATH"config/*
		Parse_CaseXML $Case_Xml
		if [ ! "$Overwrite" = "true" ];then
			Parse_Excel $TestPlan_excel
		fi 
		sub_case_type=${Case_Name%_*}
		if [ "$Case_Type" = "Perf_MultiFile2File" ];then
			channel_num=$Output_num
		elif [ "$Case_Type" = "Perf_File2FileMBR" ];then
			channel_num=$Output_num
		elif [ "$Case_Type" = "Perf_File2FileComposition" ];then
			channel_num=$Input_num
		fi

		if [ ! "$Overwrite" = "true" ];then
			"$EXC_PATH"tools/parse_excel $Input_excel $summary_sheet all 11 6 8 > "$EXC_PATH"Test_Plan/All_Cases.log
			sed /"$sub_case_type"/'!d' "$EXC_PATH"Test_Plan/All_Cases.log > "$EXC_PATH"Test_Plan/current_case.log
		else
			Input_excel=$TestPlan_excel
			"$EXC_PATH"tools/parse_excel $Input_excel "Perf_data" all 4 > "$EXC_PATH"Test_Plan/All_Cases.log
		fi
		
	 #Metrics_Option
		Run
		if [ "$Binary" = "libVA_file_xcoder" -o "$Binary" = "msdk_file_xcoder" ];then
			Get_PerfData > "$EXC_PATH"output/PerfData.log
		elif [ "$Binary" = "sample_multi_transcode_drm" ];then
			Get_MSDK_PerfData > "$EXC_PATH"output/PerfData.log
		fi

		cat "$EXC_PATH"output/PerfData.log |sed "11,$"'d'
		channel_index=1
		target_num=null
		save_excel=""
		if [ "$Overwrite" = "true" ];then
			while [ ! "save_excel" = "y" -a  ! "save_excel" = "n" ]
			do
				read -p "save to excel ?y or n
>" save_excel
				if [ "$save_excel" = "n" ];then
					save_excel=false
					break
				elif [ "$save_excel" = "y" ];then
					target_num=$channel_num
					save_excel=true
					break
				fi
			done
		fi 
		while [ "$save_excel" = "" ]
		do
			target_num=`cat "$EXC_PATH"Test_Plan/current_case.log | cut -d ' ' -f 2 | sed -n "$channel_index"'p'`
			if [ "$target_num" = "$channel_num" ];then
           		save_excel=true
			elif [ "$target_num" = "" ];then
				echo "ERROR:Target num not match with the case !"
				save_excel=false
			fi

			((channel_index=$channel_index+1))
		done
		if [ "$save_excel" = "true" ];then
			if [ ! "$Overwrite" = "true" ];then
				Case_Row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log | grep $sub_case_type |cut -d ' ' -f 1|sed -n '1p'`
				base_summary_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"AllCase.log | grep $sub_case_type |cut -d ' ' -f 1 | sed -n '1p'`
				case_summary_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"AllCase.log | grep ${Case_Xml##*/} |cut -d ' ' -f 1 | sed -n '1p'`
				offset=$(($case_summary_row-$base_summary_row))
				status_row=`cat "$EXC_PATH"Test_Plan/current_case.log | grep "${Case_Xml##*/}" | cut -d ' ' -f 1 | sed -n '1p'`
			else
				offset=0
				Case_Row=`cat  "$EXC_PATH"Test_Plan/All_Cases.log | grep "$Case_Name" |cut -d ' ' -f 1`
			fi
			Write_Excel
		fi
	elif [ "$run_mode" = "2" ];then
		if [ ! "$Overwrite" = "true" ];then
			Parse_Excel $TestPlan_excel
    #Metrics_Option
			for planned_case_index in $(seq 1 $Total_planned_case_num)
			do
				rm -rf "$EXC_PATH"output/*
				rm -rf "$EXC_PATH"config/*
				planned_xml_file=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 3 | sed -n "$planned_case_index"'p'`
				planned_case_name=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 4 | sed -n "$planned_case_index"'p'`
				case_summary_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 1 | sed -n "$planned_case_index"'p'`
				status_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 1 | sed -n "$planned_case_index"'p'`
				Case_Row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log | grep $planned_case_name |cut -d ' ' -f 1`
				base_summary_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"AllCase.log | grep $planned_case_name |cut -d ' ' -f 1 | sed -n '1p'`
				offset=$(($case_summary_row-$base_summary_row))
				echo "case[$planned_case_index] : $planned_xml_file"
				echo "$XML_path"
				if [ ! -f $XML_path"/"$planned_xml_file ];then
					echo "ERROR:This xml file is not exist! Go to the next one."
					continue
				fi
				for index in $(seq 1 $input_num)
				do
					unset Input_Clip_Array[$index]
					unset Input_num_Array[$index]
				done
				for index in $(seq 1 $output_num)
				do
					unset Output_Format_Array[$index]
					unset Width_Array[$index]
					unset Height_Array[$index]
					unset Profile_Array[$index]
					unset Level_Array[$index]
					unset Bitrate_Array[$index]
					unset Output_num_Array[$index]
					unset Gop_Array[$index]
					unset GopType_Array[$index]
					unset TargetUsage_Array[$index]
					unset FrameRate_Array[$index]
					unset Ratectrl_Array[$index]
					unset Qp_Array[$index]
				done
				Parse_CaseXML  $XML_path/$planned_xml_file
				echo "*****************************************************************************"
				echo "Case : $Case_Name"

				echo "*****************************************************************************"
				Run
				if [ "$Binary" = "libVA_file_xcoder" ];then
					Get_PerfData > "$EXC_PATH"output/PerfData.log
				elif [ "$Binary" = "sample_multi_transcode_drm" ];then
					Get_MSDK_PerfData > "$EXC_PATH"output/PerfData.log
				fi
				cat "$EXC_PATH"output/PerfData.log |sed "11,$"'d'
				Write_Excel
			done
		fi 
	fi
	
	if [ "$Overwrite" = "true" ];then
		 
		read -p "continue?y or n
>" isContinue
		while [ ! "$isContinue" = "y" -a ! "$isContinue" = "n" ]
		do
			read -p "continue?y or n
>" isContinue
		done
	else
		isContinue=n
	fi 
done 
