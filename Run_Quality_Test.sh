#!/bin/bash

mkdir -p quality_test
LibVA=./codec/LibVA
LMSDK=./codec/LMSDK
JM=./codec/JM
X264=./codec/X264

Usage()
{
    echo "Usage: `basename $0` -i config.xml"
}

Parse_External_Params()
{
    if [[ $# -lt 1 ]];then  
        echo "ERROR: No input parameters"
        Usage
        exit 1  
    fi   
    while getopts ":i:h" optname
    do
        case "$optname" in
            "i")
				Input_Config_File=$OPTARG
                if [ ! -e "$Input_Config_File" ];then
                    echo "ERROR: File <$Input_Config_File> is not exist"
                    exit
                fi
                ;;
            "h")
                Usage
                exit
                ;;
            "?")
                echo "ERROR: Unknown option \"$OPTARG\""
                Usage
                exit
                ;;
            ":")
                echo "ERROR: No argument value for option \"$OPTARG\""
                Usage
                exit
                ;;
            *)
                # Should not occur
                echo "ERROR: Should not be here, Unknown error while processing options"
                ;;
        esac
    done

    #extract the prefix path of executable script
    APP=$0
    EXEC_PATH=${APPNAME%`basename $0`}
    
    Parse_CaseXML $Input_Config_File
}

Parse_CaseXML()
{
	Parse_Label $Input_Config_File "result_excel"
	outputExcel=$label_value

	Parse_Label $Input_Config_File "sheet"
	sheet=$label_value
	if [ "$sheet" = "" ];then
		sheet="Quality_data"
	fi 
	echo "sheet:$label_value"
	
	Parse_Label $Input_Config_File "caseid"
	caseid=$label_value

	Parse_Label $Input_Config_File "case_name"
	case_name=$label_value

	Parse_Label $Input_Config_File "input_dir"
	Input_dir=$label_value
	
    Parse_Label $Input_Config_File "input_file"
	Input_File_Name=$label_value
	Input_File=${Input_dir}$Input_File_Name
	
	Parse_Label $Input_Config_File "encoder"
	encoder=$label_value

	Parse_Label $Input_Config_File "output_format"
	Output_Format=$label_value
	
	Parse_Label $Input_Config_File "resolution"
	Resolution=$label_value
    Width=${Resolution%x*}
	Height=${Resolution#*x}

	Parse_Label $Input_Config_File "profile"
	Profile=$label_value
	optionProfile="-profile $Profile"
	
	Parse_Label $Input_Config_File "level"
	Level=$label_value
	optionLevel="-level $Level"
	
	Parse_Label $Input_Config_File "bitrate"
	optionBitrate=$label_value
	
	Parse_Label $Input_Config_File "target_usage"
	optionTargetUsage=$label_value
	
    Parse_Label $Input_Config_File "frameRate"
	frameRate=$label_value
	if [ ! "$frameRate" = "" ];then
		optionFrameRate="-f $frameRate"
	fi

	Parse_Label $Input_Config_File "rcMode"
	rcMode=$label_value
	if [ ! "$rcMode" = "" ];then
		optionRCMode="-rc $rcMode"
	fi
	
	Get_CPU_Arch
	if [ "$arch" = "IVB" -a "${rcMode%%_*}" = "LA" ];then
		echo "Error:lookahead not supported on IVB !"
		exit
	fi
	
	if [  "${rcMode%%_*}" = "LA" -a ! "$Output_Format" = "h264" ];then
		echo "Error:lookahead only used with h264 !"
		exit
	fi

	Parse_Label $Input_Config_File "laDepth"
    laDepth=$label_value

	if [ "${rcMode%%_*}" = "LA" ];then
        if [ ! "$laDepth" = "N/A" -a ! "$laDepth" = "" -a "${rcMode%%_*}" = "LA" ];then
			optionLaDepth="-lad $laDepth"
		fi
	fi

	Parse_Label $Input_Config_File "mbbrcEnabled"
	mbbrcEnabled=$label_value
	if [  "$mbbrcEnabled" = "on" ];then
		optionMBBRCEnabled="-mbbrc"
	fi
	

	Parse_Label $Input_Config_File "gop"
	gop=$label_value
	optionGop="-gop $gop"

	Parse_Label $Input_Config_File "gopType"
	gopType=$label_value
	optionGopType="-gopType $gopType"

	Parse_Label $Input_Config_File "cabac"
	cabac=$label_value
	if [ "$cabac" = "on" ];then
		optionCabac="-cabac"
	fi 

	
	Parse_Label $Input_Config_File "input_color_format"
	input_color_format=$label_value
	if [ "$input_color_format" = "nv12" ];then
		optionCSC="-nv12"
    else 
        optionCSC=""
	fi 

	Parse_Label $Input_Config_File "destWidth"
	destWidth=$label_value
	if [ ! "$destWidth" = "" ];then
		optionDestWidth="-dstw $destWidth"
	fi

	Parse_Label $Input_Config_File "destHeight"
	destHeight=$label_value
	if [ ! "$destHeight" = "" ];then
		optionDestHeight="-dsth $destHeight"
	fi

	Parse_Label $Input_Config_File "maxbitrate"
	maxBitrate=$label_value
	if [ ! "$maxBitrate" = "" ];then
		optionMaxBitrate="-maxbitrate $maxBitrate"
	fi

	Parse_Label $Input_Config_File "scantype"
	scanType=$label_value
	if [ ! "$scanType" = "" -a ! "scanType" = "progressive" ];then
		if [ "$scanType" = "tff" ];then
			optionScanType="-tff"
		else
			optionScanType="-bff"
		fi 
	fi
	
	Parse_Label $Input_Config_File "env_config"
	envConfigFile=$label_value
	if [ ! "$envConfigFile" = "" ];then
		if [ ! -e "$envConfigFile" ];then
			envConfigFile=""
		fi
	fi
	
    Config_Validate
	Parse_EnvConfig

}

Parse_EnvConfig()
{
	if [ ! "$envConfigFile" = "" ];then
		Parse_Label $envConfigFile "arch"
		arch=$label_value

		Parse_Label $envConfigFile "processor"
		processor=$label_value

		Parse_Label $envConfigFile "gpu"
		gpu=$label_value

		Parse_Label $envConfigFile "gpuMaxFrequency"
		gpuMaxFrequency=$label_value

		Parse_Label $envConfigFile "turbo"
		turbo=$label_value

		Parse_Label $envConfigFile "memory"
		memory=$label_value

		Parse_Label $envConfigFile "os"
		os=$label_value

		Parse_Label $envConfigFile "kernel"
		kernel=$label_value

		Parse_Label $envConfigFile "driverBuild"
		driverBuild=$label_value

		Parse_Label $envConfigFile "appType"
		appType=$label_value

		Parse_Label $envConfigFile "appVersion"
		appVersion=$label_value
	fi 
}

Parse_Label()
{
    local xml_file=$1
    local label=$2
    label_value=`cat $xml_file | grep "</$label>" | cut -d '>' -f 2 | cut -d '<' -f 1 | sed -n "1"'p'`
}

Config_Validate()
{
    if [ ! -e "$outputExcel" ];then
        echo "ERROR: File <$outputExcel> is not exist"
        exit
    fi

	if [ ! -e "$Input_File" ];then
		echo "ERROR: File <$Input_File> is not exist"
		exit
    fi
	
	Validate_Encoder
	Validate_Output_Format
	Validate_level
	validate_usage
}

Validate_Encoder()
{
    if [ ! "$encoder" = "LMSDK" -a ! "$encoder" = "X264" -a ! "$encoder" = "JM" -a ! "$encoder" = "LibVA App" ];then
		echo "ERROR: unsupported encoder: $encoder"
		exit 
	fi
}

Validate_Output_Format()
{
	#depends on encoder
	if [ "$encoder" = "LMSDK" ];then
	    if [ ! "$Output_Format" = "h264" -a ! "$Output_Format" = "mpeg2" ];then
			echo "ERROR: unsupported Output_Format: $Output_Format ! "
			exit
		fi
	elif [ "$encoder" = "LibVA App" -o  "$encoder" = "X264" -o "$encoder" = "JM" ];then
		if [ ! "$Output_Format" = "h264" ];then
			echo "ERROR: unsupported Output_Format: $Output_Format ! "
			exit
		fi
	fi 
}

Validate_level()
{
    if [ "$Output_Format" = "h264" ];then
        if [ ! "$Level" = "41" -a ! "$Level" = "40" -a ! "$Level" = "31" -a ! "$Level" = "30" -a ! "$Level" = "20" -a ! "$Level" = "11" ];then
			echo "ERROR: invalid Level: $Level !"
			exit 
        fi
    fi

    if [ "$Output_Format" = "mpeg2" ];then
        if [ ! "$Level" = "10" -a ! "$Level" = "8" -a ! "$Level" = "6" -a ! "$Level" = "4" ];then
			echo "Error: invalid Level: $Level !"
			exit 
        fi
    fi

}

validate_usage()
{
	if [[ $optionTargetUsage > 7 || $optionTargetUsage < 1 ]];then
		echo "ERROR: invalid optionTargetUsage: $optionTargetUsage !"
		exit
	fi
}

GetData()
{
    if [ "$encoder" = "LibVA App" ];then

        echo "************************************************"
        cat ./quality_test/LibVA_Encode.log  | grep -E 'Width|Height|Profile|Level|frameRate|bitRate|RateCtrl|EncodingMode|motionRank|IntraPeroid|QPValue|targetUsage'| sed 's/^[ \t]*//'  
    fi
    echo "************************************************"
    cat ./quality_test/psnr_ssim.log | grep avg_metric | sed 's/<\/avg_metric>//g' | sed 's/<avg_metric=//g' | sed 's/>/=/g' | sed 's/=/ &/g' 
    echo "************************************************"

}


Clean()
{
    rm -rf ./quality_test/*
}

Generate_JM_Config_File()
{
    echo " # This is a file containing input parameters to the JVT H.264/AVC decoder."
    echo " # The text line following each parameter is discarded by the decoder."
    echo " # <ParameterName> = <ParameterValue> # Comment"
    echo " ##########################################################################################"
    echo " # Files"
    echo " ##########################################################################################"
    echo " InputFile             = "./quality_test/$1"       # H.264/AVC coded bitstream "
    echo " OutputFile            = "./quality_test/JM_DecodeToYUV.yuv"   # Output file, YUV/RGB "
    echo " #RefFile               =                 "
    echo " WriteUV               = 1                # Write 4:2:0 chroma components for monochrome streams"
    echo " FileFormat            = 0                # NAL mode (0=Annex B, 1: RTP packets)"
    echo " RefOffset             = 0                # SNR computation offset"
    echo " POCScale              = 2                # Poc Scale (1 or 2)"
    echo " ##########################################################################################"
    echo " # HRD parameters"
    echo " ##########################################################################################"
    echo " #R_decoder             = 500000           # Rate_Decoder"
    echo " #B_decoder             = 104000           # B_decoder"
    echo " #F_decoder             = 73000            # F_decoder"
    echo " #LeakyBucketParamFile  = "leakybucketparam.cfg" # LeakyBucket Params"
    echo " ##########################################################################################"
    echo " # decoder control parameters"
    echo " ##########################################################################################"
    echo " DisplayDecParams       = 0                # 1: Display parameters; "
    echo " ConcealMode            = 0                # Err Concealment(0:Off,1:Frame Copy,2:Motion Copy)"
    echo " RefPOCGap              = 2                # Reference POC gap (2: IPP (Default), 4: IbP / IpP) "
    echo " POCGap                 = 2                # POC gap (2: IPP /IbP/IpP (Default), 4: IPP with frame skip = 1 etc.) "
    echo " Silent                 = 0                # Silent decode"
    echo " IntraProfileDeblocking = 1                # Enable Deblocking filter in intra only profiles (0=disable, 1=filter according to SPS parameters)"
    echo " DecFrmNum              = 0                # Number of frames to be decoded (-n) "
    echo " ##########################################################################################"
    echo " # MVC decoding parameters"
    echo " #########################################################################################"
    echo " DecodeAllLayers        = 0                 # Decode all views (-mpr)"

}


Run()
{
    #start transcode

    if [ "$encoder" = "LibVA App" ];then
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LibVA
        $LibVA/fileTranscoder -i $Input_File -o ./quality_test/LibVA_Encode.$Output_Format -u $optionTargetUsage --profile $Profile --framerate $frameRate --level $Level --bitrate $optionBitrate --loglevel 3 > ./quality_test/LibVA_Encode.log
		flag_=$?
	    if [ ! "$flag_" = "0" ];then
			echo "ERROR: $flag_ $encoder Encode failed !"
			exit
		fi
        JM_Input_File=LibVA_Encode.$Output_Format

		
    elif [ "$encoder" = "X264" ];then
        optionBitrate=$(($optionBitrate/1000))
        $X264/x264 --profile $Profile --level $Level --no-cabac --bframes 0 --keyint 30 --min-keyint 30 --ref 2 --bitrate $optionBitrate -o ./quality_test/X264_Encode.$Output_Format $Input_File 
        JM_Input_File=X264_Encode.$Output_Format

	elif [ "$encoder" = "LMSDK" ];then
        # optionBitrate=$(($optionBitrate/1000))
        # export LD_LIBRARY_PATH=$LMSDK

        $LMSDK/sample_encode $Output_Format -u $optionTargetUsage -b $optionBitrate -hw -i $Input_File -o ./quality_test/LMSDK_Encode.$Output_Format -w $Width -h $Height $optionRCMode $optionFrameRate $optionScanType $optionMaxBitrate $optionBFrames $optionLaDepth $optionMBBRCEnabled $optionDestWidth $optionDestHeight $optionProfile $optionLevel $optionGop $optionGopType  $optionCabac > ./quality_test/LMSDK_Encode.log 
		flag_=$?

		echo " $LMSDK/sample_encode $Output_Format -u $optionTargetUsage -b $optionBitrate -hw -i $Input_File -o ./quality_test/LMSDK_Encode.$Output_Format -w $Width -h $Height $optionRCMode $optionFrameRate $optionScanType $optionMaxBitrate $optionLaEnabled $optionLaDepth $optionMBBRCEnabled $optionDestWidth $optionDestHeight $optionProfile $optionLevel $optionGop $optionGopType $optionCabac > ./quality_test/LMSDK_Encode.log "
	    if [ ! "$flag_" = "0" ];then
			echo "ERROR: $encoder Encode failed !"
			exit
		fi
        JM_Input_File=LMSDK_Encode.$Output_Format

	elif [ "$encoder" = "JM" ];then
        ./tools/Generate_JM_Encode_ConfigFile.sh $Input_File $Width $Height $Bitrate $Output_Format $Level > ./quality_test/JM_Encode.cfg
        $JM/lencod.exe -d ./quality_test/JM_Encode.cfg > ./quality_test/JM_Encode.log 
		flag_=$?
	    if [ ! "$flag_" = "0" ];then
			echo "ERROR: $flag_ $encoder Encode failed !"
			exit
		fi
        JM_Input_File=JM_Encode.$Output_Format
    fi

	if [ ! -e "./quality_test/$JM_Input_File" ];then
		echo "ERROR: $encoder Encode failed !"
		exit
	else
		echo "$encoder Encode done !"
	fi
	
	if [ "$Output_Format" = "mpeg2" ];then
		ffmpeg -i ./quality_test/$JM_Input_File ./quality_test/ffmeg_decodetoyuv.yuv >ffmpeg_decode.log
		flag_=$?
	    if [ ! "$flag_" = "0" ];then
			echo "ERROR: ffmpeg decode failed !"
			exit
		fi

		echo "FFMPEG Decode to YUV done !"
		echo "Calculating PSNR & SSIM !"
		./tools/metrics_calc_lite -i1 $Input_File -i2 ./quality_test/ffmeg_decodetoyuv.yuv -w $Width -h $Height psnr ssim all > ./quality_test/psnr_ssim.log

	else		
		Generate_JM_Config_File $JM_Input_File > ./quality_test/jm_decode.cfg
		$JM/ldecod.exe -d ./quality_test/jm_decode.cfg > ./quality_test/jm_decode.log
		echo "JM Decode to YUV done !"
		echo "Calculating PSNR & SSIM !"
		./tools/metrics_calc_lite -i1 $Input_File -i2 ./quality_test/JM_DecodeToYUV.yuv -w $Width -h $Height psnr ssim all > ./quality_test/psnr_ssim.log
	fi
	
    wait
    echo "Calculating PSNR & SSIM Done!"
    echo "Detail information Please reference: ./quality_test/psnr_ssim.log "

}

WriteToExcel()
{
 	col_DATE=1
	col_CASEID=2
	col_CASENAME=3
	col_CLIPS=4
	col_RESOLUTION=5
	col_IN_CODEC=6
	col_CODEC=7
	col_PROFILE=8
	col_LEVEL=9
	col_GOP=10
	col_GOPTYPE=11
	col_RATECONTRL=12 
	col_MAXBITTATE=13
	col_CABAC=13
	col_TU=14 
	col_MBBRC=15 
	col_LA=16 
	col_LA_DEPTH=17 
	col_FrameRate=18 
	col_BITRATE=19 
	col_PSNR=20 
	col_YPSNR=21 
	col_UPSNR=22 
	col_VPSNR=23 
	col_SSIM=24 
	col_YSSIM=25 
	col_USSIM=26 
	col_VSSIM=27 
	col_APP=28 
	col_ARCH=29 
	col_PROCESSOR=30 
	col_GPU=31 
	col_GPU_MAXFREQ=32 
	col_TURBO=33 
	col_MEMORY=34 
	col_OS=35 
	col_KERNEL=36 
	col_DRIVER_BUILD=37 
	col_APP_TYPE=38 
	col_APP_VERSION=39

	if [ "${rcMode%%_*}" = "LA" ];then
		laEnabled="on"
	else
		laEnabled="off"
	fi
	
    #get Case_Row by caseid
	"$EXEC_PATH"tools/parse_excel $outputExcel $sheet all 3 >./quality_test/AllCases.log
	echo "$EXEC_PATH tools/parse_excel $outputExcel $sheet all 3 >./quality_test/AllCases.log"
	Case_Row=`cat ./quality_test/AllCases.log | grep  "$caseid" | cut -d ' ' -f 1`

	if [ "$Case_Row" = "" ];then
		Case_Row=`cat ./quality_test/AllCases.log | sed -n '$p'|cut -d ' ' -f 1`
		Case_Row=$((Case_Row+1))
		"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_CASEID "$caseid " 0
		"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_CASENAME "$case_name " 0
	fi

	echo "case_row: $Case_Row"
	# write config information to excel
	#
    "$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_CLIPS "$Input_File_Name " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_CODEC "$Output_Format " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_PROFILE "$Profile " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_LEVEL $Level  0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_RESOLUTION $Resolution  0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_RATECONTRL "$rcMode " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_APP "$encoder " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_IN_CODEC "$input_color_format " 0

	cabac_exist=false
	val_3_14=`"$EXEC_PATH"tools/parse_excel $outputExcel $sheet 3 14`
	if [ "$val_3_14" = "CABAC" ];then
			"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_CABAC "$cabac" 0
	else
		"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_MAXBITTATE "$maxBitrate" 0
	fi
	
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_GOP  $gop 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_GOPTYPE "$gopType" 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_TU $optionTargetUsage 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_MBBRC "$mbbrcEnabled " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_LA "$laEnabled " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_LA_DEPTH $laDepth 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_BITRATE $optionBitrate 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_FrameRate $frameRate 0

	# write quality metrics to excel
	value_PSNR=`grep "PSNR" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '4p'`
	value_YPSNR=`grep "PSNR" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '1p'`
	value_UPSNR=`grep "PSNR" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '2p'`
	value_VPSNR=`grep "PSNR" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '4p'`

	value_SSIM=`grep "SSIM" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '4p'`
	value_YSSIM=`grep "SSIM" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '1p'`
	value_USSIM=`grep "SSIM" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '2p'`
	value_VSSIM=`grep "SSIM" ./quality_test/metrics.txt |sed 's/[ \t]*//g' |cut -d '=' -f 2 |sed -n '4p'`

	echo $outputExcel $sheet $value_PSNR
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_PSNR  $value_PSNR 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_YPSNR $value_YPSNR 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_UPSNR $value_UPSNR 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_VPSNR $value_VPSNR 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_SSIM  $value_SSIM 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_YSSIM $value_YSSIM 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_USSIM $value_USSIM 1
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_VSSIM $value_VSSIM 1

	time=`date '+%Y-%m-%d_%H:%M:%S'`
	echo "	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_DATE "$time" 0"
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_DATE "$time" 0

	#write env config to excel

	#get hardware info
	processor=`cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p'`

		
	Get_GPU_Info		
		
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_ARCH "$arch " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_PROCESSOR "$processor " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_GPU "$gpu " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_GPU_MAXFREQ "$gpuMaxFrequency " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_TURBO "$turbo " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_MEMORY "$memory " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_OS "$os " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_KERNEL "$kernel " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_DRIVER_BUILD "$driverBuild " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_APP_TYPE "$appType " 0
	"$EXEC_PATH"tools/write_excel $outputExcel $sheet $Case_Row $col_APP_VERSION "$appVersion " 0
}

Get_CPU_Arch()
{
	if [ `cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p' |cut -d ' ' -f 4 |cut -d '-' -f 1 |grep -i "^e3"` ];then
		arch="HSW"
	else
		if [ `cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p' |cut -d ' ' -f 3 |cut -d '-' -f 2 |grep -i "^2"` ];then
			arch="SNB"
		else
			if [ `cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p' |cut -d ' ' -f 3 |cut -d '-' -f 2 |grep -i "^3"` ];then
			arch="IVB"
			else
				if [ `cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p' |cut -d ' ' -f 3 |cut -d '-' -f 2 |grep -i "^4"` ];then
					arch="HSW"
				else
					arch="BDW"
				fi
			fi 
		fi 
	fi
}

Get_GPU_Info()
{
	short_processor=`cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p' |cut -d ' ' -f 3 |cut -d '-' -f 2`

	if [ "$short_processor" = "" ];then
		short_processor=`cat /proc/cpuinfo |grep "model name"|cut -d ':' -f 2| sed -n 's/^[ \t]*//p' |sed -n '1p' |cut -d ' ' -f 4 |cut -d '-' -f 2`
	fi
	
	if [ "3770K" = "$short_processor" -o "3570K" = "$short_processor" ];then
		gpu="GT2@HD4000"
	else
		if [ "4770K" = "$short_processor" -o "4700EQ" = "$short_processor" ];then
		gpu="GT2@HD4600"
		else
			if [ "4850EQ" = "$short_processor" ];then
				gpu="GT3e@Iris Pro 5200"
			else
				if [ "1285L" = "$short_processor" ];then
					gpu="GT2@P4700"
				else
					gpu="unknown"
				fi
			fi
		fi 
	fi 
}

Show_Config()
{
    echo "**********************************************************************"
    echo "Config Information :"
	echo "CaseID:   $caseid"           
    echo "CaseName: $case_name"
    echo -e "Clip     = $Input_File\nwidth    = $Width\nheight   = $Height\nprofile  = $Profile\nlevel    = $Level\nbitrate  = $optionBitrate "
	echo "Encoder :$encoder"
	echo "target usage: $optionTargetUsage"
	echo "result excel: $outputExcel"
	echo "result excel sheet :$sheet"
	echo "frame rate: $frameRate"
	echo "laDepth:$laDepth"
	echo "mbbrcEnabled:$mbbrcEnabled"
	echo "rcMode:$rcMode"
	echo "gop:$gop"
	echo "gopType:$gopType"
	echo "cabac:$cabac"
	echo "env config file :$envConfigFile"
	echo "dstw:$destWidth"
	echo "dsth:$destHeight"
	if [ "$encoder" = "LibVA App" ];then
		outputFileName="LibVA_Encode.$Output_Format"
	elif [ "$encoder" = "LMSDK" ];then
		outputFileName="LMSDK_Encode.$Output_Format"
	elif [ "$encoder" = "x264" ];then
		outputFileName="X264_Encode.$Output_Format"
	elif [ "$encoder" = "JM" ];then
		outputFileName="JM_Encode.$Output_Format"
	fi
	
    echo "Output   = ./quality_test/$outputFileName "
    echo "**********************************************************************"
}

Clean
#EXEC_PATH=${APP%Run_Quality_Test.sh}
Parse_External_Params $@
Show_Config
Run
mv dataDec.txt data.txt log.dat log.dec ./quality_test/ >/dev/null 2>&1
rm -rf ./codec/JM/test_dec.yuv
GetData >./quality_test/metrics.txt
WriteToExcel
GetData
