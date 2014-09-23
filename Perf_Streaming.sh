#!/bin/bash

# This is the performance test script for libVA file mode.
# Please run "$EXC_PATH"tools/install_prerequisites.sh to install require libs.

binary_dir="NULL"
run_mode="NULL"
Input[1]="NULL"
MAX_COMPOSITION_NUM=16

# Show the usage of this script
#
# Params: null
# Return: null
Usage()
{
    echo ""
    echo "Usage: Perf_Streaming.sh -f <config file> -e <result excel>"
    echo "[options]:"
    echo "-i <case xml>      - Specify case xml. If not set, will excute from test plan excel."
    echo "-p <binary dir>    - Specify path of binary. If not set, will use that defined in case xml"
    echo "-b <binary>        - Specify the test binary. If not set, will use that defined in case xml"
    echo "-o                 - Specify whether overwrite input_num in xml file"
    echo "-h                 - Show this usage."
}

# Parse external parameters and assign '-f' value to global variable 'Running_mode'
# and assign '-i' value to global variable 'Input'.
#
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
    EXC_PATH=${APP%Perf_Streaming.sh}
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
        if [ ! -e "${Input[1]}" ];then
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
    # Case_Type=`cat $config_file | grep Case_type | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    XML_path=`cat $config_file | grep Case_path | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    Target_usage=`cat $config_file | grep Target_usage | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    metrics=`cat $config_file | grep Metrics | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
    OndemandServer_IP=`cat $config_file | grep Ondemand_server | cut -d '=' -f 2 | sed 's/^[ \t]*//'`
	
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

    if [ ! "${input_file##*.}" = "h264" -a ! "${input_file##*.}" = "264" -a ! "${input_file##*.}" = "m2v" -a ! "${input_file##*.}" = "vc1" -a ! "${input_file##*.}" = "ivf" ];then
        echo "ERROR: The file <$input_file> has invalid format !"
        Usage
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
        Binary=$Binary_xml
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
        echo "ERROR: $binary_dir$Binary is not exist !"
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
		if [ "$Overwrite" = "true" -a ! "$Case_Type" =  "Perf_StreamingMBR" ];then
			read -p "please input channel number
>" Input_num
		else
			Parse_Label $XML_File "input_num" $In_index
			Input_num=$label_value
		fi

        if [ "$clip" = "" ];then
            In_Flag="yes"
        else
            InputClip_Validation $clip
            Input_Clip_Array[$In_index]=$clip
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
                StreamType=""
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
				echo "ERROR: Invalid target usage $TargetUsage"
				exit
			fi

			Parse_Label $XML_File "gop" $Out_index
			Gop=$label_value
			
			Parse_Label $XML_File "gopType" $Out_index
			GopType=$label_value

			Parse_Label $XML_File "qp" $Out_index
			Qp=$label_value
			
			Parse_Label $XML_File "ratectrl" $Out_index
			Ratectrl=$label_value
			
			Parse_Label $XML_File "framerate" $Out_index
			Framerate=$label_value

			Parse_Label $XML_File "deInterlace_enable" $Out_index
			deInterlace_enable=$label_value

			Parse_Label $XML_File "pictureStruct" $Out_index
			pictureStruct=$label_value
			
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

			if [ "$Overwrite" = "true" -a "$Case_Type" = "Perf_MultiStreaming" ];then
				Output_num=${Input_num_Array[$Out_index]}
			else
				if [ "$Overwrite" = "true" -a "$Case_Type" = "Perf_StreamingMBR" ];then
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
			Framerate_Array[$Out_index]=$Framerate
			Qp_Array[$Out_index]=$Qp
			deInterlace_enable_Array[$Out_index]=$deInterlace_enable
			pictureStruct_Array[$Out_index]=$pictureStruct
            Out_index=$(($Out_index+1))
        fi
    done
    ((Out_index=$Out_index-1))

    echo "CASE TYPE: $Case_Type"
    if [ "$Case_Type" = "Perf_MultiStreaming" ];then
        if [ ! "$In_index" = "$Out_index" ];then
            echo "In:$In_index, Out:$Out_index"
            echo "ERROR: Parse xml failed! 1:1 Multichannel <input_num> and <output_num> are not match !"
            exit
        else
            for index in $(seq 1 $In_index)
            do
                if [ ! "${Input_num_Array[$index]}" = "${Output_num_Array[$index]}" ];then
					echo "${Input_num_Array[$index]},$Output_num, ${Output_num_Array[$index]}, $XML_File"
                    echo "ERROR: Parse xml failed! 1:1 Multichannel <input_num> and <output_num> are not match !"
                    exit
                fi
            done
        fi
    elif [ "$Case_Type" = "Perf_StreamingMBR" ];then
        if [ ! "$In_index" = "1" ];then
            echo "ERROR: Parse xml failed! 1:N MBR mode should have one input !"
            exit
        fi
    elif [ "$Case_Type" = "Perf_StreamingComposition" ];then
        if [ ! "$Out_index" = "1" ];then
            echo "ERROR: Parse xml failed! N:1 Composition should have one output !"
            exit
        fi
    fi

    input_num=0
    output_num=0
    local divide=4
    local total_x=1920
    local total_y=1080
    Generate_ConfigFile_Server $OndemandServer_IP > "$EXC_PATH"config/config_$Case_Type.ini
    if [ "$Case_Type" = "Perf_MultiStreaming" ];then

        for index_multi in $(seq 1  $In_index)
        do
            for index_multi_ in $(seq 1 ${Input_num_Array[$index_multi]})
            do
                ((input_num=$input_num+1))
                pos_x=0
                pos_y=0
                pos_w=${Width_Array[$index_multi]}
                pos_h=${Height_Array[$index_multi]}
                local clip_multi=${Input_Clip_Array[$index_multi]%.*}
                Generate_ConfigFile_Streaming 0 $input_num ${Width_Array[$index_multi]} ${Height_Array[$index_multi]} "1to1" ${Profile_Array[$index_multi]} ${Level_Array[$index_multi]} ${Bitrate_Array[$index_multi]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Framerate_Array[$index_multi]} ${Qp_Array[$index_multi]} $clip_multi"_"$input_num ${deInterlace_enable_Array[$index_multi]} ${pictureStruct_Array[$index_multi]} ${StreamType_Array[$index_multi]} >> "$EXC_PATH"config/config_$Case_Type.ini
            done
        done
        output_num=$input_num
    elif [ "$Case_Type" = "Perf_StreamingMBR" ];then
        for index_mbr in $(seq 1 $Out_index)
        do
            for index_mbr_ in $(seq 1 ${Output_num_Array[$index_mbr]})
            do

                ((output_num=$output_num+1))
                pos_x=0
                pos_y=0
                pos_w=${Width_Array[$index_mbr]}
                pos_h=${Height_Array[$index_mbr]}
                local clip_mbr=${Input_Clip_Array[1]%.*}
                Generate_ConfigFile_Streaming 0 $output_num ${Width_Array[$index_mbr]} ${Height_Array[$index_mbr]} "1toN" ${Profile_Array[$index_mbr]} ${Level_Array[$index_mbr]} ${Bitrate_Array[$index_mbr]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Framerate_Array[$index_multi]} ${Qp_Array[$index_multi]} $clip_mbr ${deInterlace_enable_Array[$index_multi]} ${pictureStruct_Array[$index_multi]} ${StreamType_Array[$index_multi]} >> "$EXC_PATH"config/config_$Case_Type.ini
            done
        done
        input_num=1
    elif [ "$Case_Type" = "Perf_StreamingComposition" ];then

        if [ "$total_input" = "1" ];then
            divide=1
        elif [ "$total_input" -gt "1" -a "$total_input" -lt "5" ];then
            divide=2
        elif [ "$total_input" -gt "4" -a "$total_input" -lt "10" ];then
            divide=3
        elif [ "$total_input" -gt "9" -a "$total_input" -lt "17" ];then
            divide=4
        fi
        output_num=1
        local total_x=${Width_Array[1]}
        local total_y=${Height_Array[1]}

        if [ $(echo "$total_input > $MAX_COMPOSITION_NUM"|bc) -eq 1 ];then
            echo "ERROR : Exceed max composition number $MAX_COMPOSITION_NUM !"
            exit
        else
            for index_comp in $(seq 1 $In_index)
            do
                for index_comp_ in $(seq 1 ${Input_num_Array[$index_comp]})
                do
                    ((input_num=$input_num+1))
                    local clip_comp=${Input_Clip_Array[$index_comp]%.*}

                    local com_num=$(($input_num-1))
                    ((pos_w=$total_x/$divide))
                    ((pos_h=$total_y/$divide))
                    ((pos_x=$com_num%$divide))
                    ((pos_x=$pos_x*$pos_w))
                    ((pos_y=$com_num/$divide))
                    ((pos_y=$pos_y*$pos_h))
                    Generate_ConfigFile_Streaming 0 $input_num ${Width_Array[$index_comp]} ${Height_Array[$index_comp]} "Nto1" ${Profile_Array[$index_comp]} ${Level_Array[$index_comp]} ${Bitrate_Array[$index_comp]} ${Gop_Array[$index_multi]} ${GopType_Array[$index_multi]} ${TargetUsage_Array[$index_multi]} ${Ratectrl_Array[$index_multi]} ${Framerate_Array[$index_multi]} ${Qp_Array[$index_multi]} $clip_comp"_"$input_num ${deInterlace_enable_Array[$index_multi]} ${pictureStruct_Array[$index_multi]} ${StreamType_Array[$index_multi]} >> "$EXC_PATH"config/config_$Case_Type.ini
                done
            done
        fi
    else
        echo "To be define !"
    fi
    Show_CaseInfo
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

# Config streaming server
#
# Params: IP
# Return:
Generate_ConfigFile_Server()
{
    echo "[client]"
    echo "port = 8556"
    echo "[server]"
    echo "port = 8554"
    echo "ip   = $1"
}
# Generate streaming config file
#
# Params:
# Retuen:
Generate_ConfigFile_Streaming()
{

    local Plus_Flag=$1
    local index=$2
    local width=$3
    local height=$4
    local xcodermode=$5
    local profile=$6
    local level=$7
    local bitrate=$8
	local gop=$9
	local gopType=${10}
	local target_usage=${11}
	local ratectrl=${12}
	local framerate=${13}
	local qp=${14}
    local streaming_in=${15}
	local deinterlace_enable=${16}
	local pictureStruct=${17}
	local streamType=${18}

    echo "[stream_$index]"
    if [ "$Plus_Flag" = "0" ];then

        echo "streamin   = $streaming_in.ts"
        echo "pos_x      = $pos_x"
        echo "pos_y      = $pos_y"
        echo "pos_w      = $pos_w"
        echo "pos_h      = $pos_h"
    fi
    echo "streamout  = stream_$index.ts"
    echo "width      = $width"
    echo "height     = $height"
    echo "xcoderMode = $xcodermode"
    echo "profile=$profile"
    echo "level=$level"
    echo "encMode=$gopType"
    echo "framerate=$framerate"
    echo "ratectrl=$ratectrl"
    echo "bitrate=$bitrate"
    echo "intra=$gop"
    echo "qp=$qp"
	echo "targetUsage=$target_usage"
	echo "deinterlace_enable=$deinterlace_enable"
	echo "nPicStruct=$pictureStruct"
	echo "streamType=$streamType"
    # echo "maxBframes=2"
    # echo "progressive_sequence=1"
    # echo "progressive_frame=1"
    # echo "picture_structure=3"
    # echo "aspect_ratio_info=1"
    # echo "low_delay=0"
    # echo "top_field_first=0"
    # echo "concealment_motion_vectors=0"
    # echo "q_scale_type=0"
    # echo "intra_vlc_format=0"
    # echo "alternate_scan=0"
    # echo "repeat_first_field=0"
    # echo "threads=1"
    # echo "min_quantizer=0"
    # echo "max_quantizer=0"
    # echo "keyframe_auto=0"
    # echo "kf_min_dist=0"
    # echo "kf_max_dist=0"

    # echo "log_enable=1"
    # echo "log_media=1"
    # echo "log_level=2"
    # echo "log_file=log_encoder.txt"

}

# Run the transcoding
#
# Params: null
# Return: null
Run()
{
	isWatchRunnig=`ps -e|grep "watch.sh" |sed -n '$='`
	if [[ $isWatchRunnig > 0 ]];then
		pkill watch.sh
	fi 

	"$EXC_PATH"tools/watch.sh $Case_Type &
		
    if [ "$Binary" = "libVA_streaming_xcoder" ];then
        "$EXC_PATH"tools/top.sh libVA_streaming 1 $metrics $Case_Type &
    elif [ "$Binary" = "msdk_stream_xcoder" ];then
        "$EXC_PATH"tools/top.sh msdk_stream_xco 1 $metrics $Case_Type &
    elif [ "$Binary" = "msdkTranscoder" ];then
        "$EXC_PATH"tools/top.sh msdkTranscoder 1 $metrics $Case_Type &
    fi
    if [ "$Case_Type" = "Perf_StreamingComposition" ];then
        echo $input_num > ~/message.log
    else
        echo $output_num > ~/message.log
    fi
	echo "    ${binary_dir}$Binary -f "$EXC_PATH"config/config_$Case_Type.ini > "$EXC_PATH"output/$Case_Type.log
"
    $binary_dir$Binary -f "$EXC_PATH"config/config_$Case_Type.ini > "$EXC_PATH"output/$Case_Type.log
	streamedNum=`cat "$iPATH"output/$Case_Type.log |grep "Done processing" |sed -n '$='`
	totalNum=`cat ~/message.log`

	if [[ ! $streamedNum = $totalNum ]];then
		echo "transcoding failed :$streamedNum : $totalNum"
		exit
	fi 
    echo "Processing Done!"
    echo "Detail information Please reference: "$EXC_PATH"output/PerfData.log "
    echo "0" > ~/message.log
}

# Get the performance data
#
# Params: null
# Return: null
Get_PerfData()
{
	pkill watch.sh
    wait
    echo "******************************************************************"
    echo "                Performance Statistics :"
    echo "******************************************************************"
    eval $(awk '{a+=$1;b+=$2} END {printf("avgcpu=%.1f\navgmem=%.1f", a/(NR*8),b/NR);}' "$EXC_PATH"output/cpu_mem.txt)

    if [ ! "$metrics" = "2" ];then
        sed -i '1d' "$EXC_PATH"output/gpu_usage.log
        eval $(awk '{b+=$2} END {printf("avggpu=%.1f", b/NR);}' "$EXC_PATH"output/gpu_usage.log)
    fi

    Test_Result
    if [ ! "$metrics" = "4" ];then
        echo "CPU Util. =$avgcpu%"
    fi
    if [ ! "$metrics" = "2" ];then
        echo "GPU Util. =$avggpu%"
    fi
    if [ ! "$metrics" = "3" ];then
        echo "Mem Util. =$avgmem%"
    fi
    echo "******************************************************************"
    echo "Case Name:$Case_Name"
    echo "Test Result:$test_result"
    echo "INPUT-NUM:$input_num"
    if [ "$Case_Type" = "Perf_MultiStreaming" -o "$Case_Type" = "Perf_StreamingComposition" ];then
        for index_log in $(seq 1 $input_num)
        do

            echo "******************************************************************"
            echo "                       [ Channel $index_log ]"
            echo "******************************************************************"
            echo "            Decode"
            echo "*********************************"
            sed -n "/DEC> channel $index_log of $input_num/,/INFO/"'p'  "$EXC_PATH"output/$Case_Type.log | grep -E 'DecodeNum|AvgDecodeLatency'| sed 's/^[ \t]*//'

            echo "*********************************"
            echo "        Encode Parameters"
            echo "*********************************"
            input_=$(($index_log*3))
            input_=$(($input_-1))
            cat "$EXC_PATH"output/$Case_Type.log | grep Input | sed -n "$input_"'p'| sed 's/^[ \t]*//'
            sed -n "/Encoding Params> channel $index_log of $input_num/,/INFO/"'p' "$EXC_PATH"output/$Case_Type.log| grep -E 'Width|Height|Profile|Level|time_scale|bitRate|RateCtrl|EncodingMode|IntraPeroid|QPValuei|targetUsage'| sed 's/^[ \t]*//'

            echo "*********************************"
            echo "            Encode"
            echo "*********************************"
            sed -n "/ENC> channel $index_log of $input_num/,/INFO/"'p' "$EXC_PATH"output/$Case_Type.log | grep -E 'EncodedNum|AvgVPPLatency|AvgEncLatency|FirstFrameLatency|MaxFrameLatency|MinFrameLatency|AvgFrameLatency|ChannelDuration|AvgFPS'| sed 's/^[ \t]*//'
        done


    elif [ "$Case_Type" = "Perf_StreamingMBR" ];then

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

		target_fps=29
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
    if [ "$Case_Type" = "Perf_StreamingComposition" ];then
        num_data=$input_num
    else
        num_data=$output_num
    fi
    avgfps=`cat "$EXC_PATH"output/PerfData.log | grep "Avg  FPS" | cut -d ':' -f 2 | sed 's/ //g'`
    echo "Writing data to excel ..."
    #Find the right position in excel
    echo "offset=$offset"
	echo "CaseRow:$Case_Row"
    Case_Row=$(($Case_Row + $offset))
    echo "Input_excel : $Input_excel"
    echo "sheet : $sheet"
    echo "Case_Row : $Case_Row"
    echo "output_num : $num_data"
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

    "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $channel_col $num_data 0
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
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgEncLatency_col  $AvgEncLatency 0
    "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $FirstFrameLatency_col  $FirstFrameLatency 0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $MaxFrameLatency_col  $MaxFrameLatency  0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $MinFrameLatency_col $MinFrameLatency 0
    # "$EXC_PATH"tools/write_excel $Input_excel $sheet $Case_Row $AvgFrameLatency_col $AvgFrameLatency 0

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
    target_fps=29
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
    if [ "$Case_Type" = "Perf_MultiStreaming" ];then
        sheet="Performance_S_MultiChannel"
    elif [ "$Case_Type" = "Perf_StreamingMBR" ];then
        sheet="Performance_S_MBR"
    elif [ "$Case_Type" = "Perf_StreamingComposition" ];then
        sheet="Performance_S_Composition"
    fi
    echo "EXCEL : $Input_excel"
    echo "SHEET : $sheet"
    "$EXC_PATH"tools/parse_excel $Input_excel $sheet all 1 2 3 > "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log
    "$EXC_PATH"tools/parse_excel $Input_excel $summary_sheet all 14  8 6 > "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    "$EXC_PATH"tools/parse_excel $Input_excel $summary_sheet all 11  8 6 > "$EXC_PATH"Test_Plan/$sub_name"_"AllCase.log
    sed -i '/Performance/!d' "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log
    sed -i '/Planned/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    #Only test Multichannel
    if [ "$Case_Type" = "Perf_MultiStreaming" ];then
        sed -i '/Media_Performance_Streaming_M_/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    elif [ "$Case_Type" = "Perf_StreamingMBR" ];then
        sed -i '/Media_Performance_Streaming_MBR_/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
    elif [ "$Case_Type" = "Perf_StreamingComposition" ];then
        sed -i '/Media_Performance_Streaming_Composition_/!d' "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log
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

Parse_GlobalSetting $global_setting
mkdir -p "$EXC_PATH"output
mkdir -p "$EXC_PATH"config
rm -rf "$EXC_PATH"output/*
rm -rf "$EXC_PATH"config/*

isContinue=y
while [ "$isContinue" = "y" ]
do 
	if [ "$run_mode" = "1" ];then
		Parse_CaseXML $Case_Xml
		if [ ! "$Overwrite" = "true" ];then
			Parse_Excel $TestPlan_excel
		fi 
		sub_case_type=${Case_Name%_*}
		if [ "$Case_Type" = "Perf_MultiStreaming" ];then
			channel_num=$Output_num
		elif [ "$Case_Type" = "Perf_StreamingMBR" ];then
			channel_num=$Output_num
		elif [ "$Case_Type" = "Perf_StreamingComposition" ];then
			channel_num=$Input_num
		fi
		if [ ! "$Overwrite" = "true" ];then
			"$EXC_PATH"tools/parse_excel $Input_excel $summary_sheet all 11 6 8 > "$EXC_PATH"Test_Plan/All_Cases.log
			sed /"$sub_case_type"/'!d' "$EXC_PATH"Test_Plan/All_Cases.log > "$EXC_PATH"Test_Plan/current_case.log
		else
			Input_excel=$TestPlan_excel
			"$EXC_PATH"tools/parse_excel $Input_excel "Perf_data" all 4 > "$EXC_PATH"Test_Plan/All_Cases.log
		fi

		Run
		Get_PerfData > "$EXC_PATH"output/PerfData.log
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
				status_row=`cat "$EXC_PATH"Test_Plan/current_case.log | cut -d ' ' -f 1 | sed -n "$channel_index"'p'
`				save_excel=true
			elif [ "$target_num" = "" ];then
				echo "ERROR:Target num not match with the case !"
				save_excel=false
			fi

			((channel_index=$channel_index+1))
		done

		if [ "$save_excel" = "true" ];then
			if [ ! "$Overwrite" = "true" ];then
				Case_Row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log | grep $sub_case_type |cut -d ' ' -f 1 |sed -n '1p'`
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
			for planned_case_index in $(seq 1 $Total_planned_case_num)
			do
				rm -rf "$EXC_PATH"output/*
				planned_xml_file=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 3 | sed -n "$planned_case_index"'p'`
				planned_case_name=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 4 | sed -n "$planned_case_index"'p'`
				case_summary_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 1 | sed -n "$planned_case_index"'p'`
				status_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"PlannedCase.log | cut -d ' ' -f 1 | sed -n "$planned_case_index"'p'`
				Case_Row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"$Case_Type.log | grep $planned_case_name |cut -d ' ' -f 1`
				base_summary_row=`cat  "$EXC_PATH"Test_Plan/$sub_name"_"AllCase.log | grep $planned_case_name |cut -d ' ' -f 1 | sed -n '1p'`
				offset=$(($case_summary_row-$base_summary_row))
				echo "case[$planned_case_index] : $planned_xml_file"

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
					unset StreamType_Array[$index]
					unset Width_Array[$index]
					unset Height_Array[$index]
					unset Profile_Array[$index]
					unset Level_Array[$index]
					unset Bitrate_Array[$index]
					unset Output_num_Array[$index]
					unset Gop_Array[$index]
					unset GopType_Array[$index]
					unset TargetUsage_Array[$index]
					unset Ratectrl_Array[$index]
					unset Framerate_Array[$Index]
					unset Qp_Array[$Index]
					unset deInterlace_enable_Array[$Index]
					unset pictureStruct_Array[$Index]
				done
				Parse_CaseXML  $XML_path/$planned_xml_file
				echo "*****************************************************************************"
				echo "Case : $Case_Name"
				echo "*****************************************************************************"
				Run
				Get_PerfData > "$EXC_PATH"output/PerfData.log
				cat "$EXC_PATH"output/PerfData.log |sed "11,$"'d'
				save_excel="y"
				if [ "$Overwrite" = "true" ];then
					if [ "$Case_Type" = "Perf_MultiFile2File" ];then
						channel_num=$Output_num
					elif [ "$Case_Type" = "Perf_File2FileMBR" ];then
						channel_num=$Output_num
					elif [ "$Case_Type" = "Perf_File2FileComposition" ];then
						channel_num=$Input_num
					fi
					
					target_num=$channel_num
		   			read -p "whether save to excel ?y or n
>" save_excel
				fi
				if [ "$save_excel" = "y" ];then
					Write_Excel
				fi 

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
