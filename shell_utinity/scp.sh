#!/bin/bash
Usage()
{
    echo ""
    echo "Usage: ./scp.sh -s src_path -d dst_path relative to home [-r]"
    echo "[options]:"
    echo "-r whether reverse the cp direction ,default is from centos to ubuntu"
    echo "-h                 - Show this usage."
}


ParseArgs()
{
	while getopts ":s:d:r" optname
	do
		case "$optname" in
			"r")
				reverse="true"
				;;

			"s")
				src=$OPTARG
				;;

			"d")
				dst=$OPTARG
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
}

#main


if [ "$#" -lt "2" ];then
	Usage
	exit
fi 
ParseArgs $@
if [ "$reverse" != "true" ];then
	src_ip="sunjiwen@172.24.16.97"
	dst_ip="sjw@172.24.16.195"	

	src_path="/home/sunjiwen/"$src
	dst_path="/home/sjw/"$dst
else
	dst_ip="sunjiwen@172.24.16.97"
	src_ip="sjw@172.24.16.195"
	
	src_path="/home/sjw/"$src
	dst_path="/home/sunjiwen/"$dst
fi

echo "scp -r $src_ip:$src_path $dst_ip:$dst_path"
scp -r $src_ip:$src_path $dst_ip:$dst_path
