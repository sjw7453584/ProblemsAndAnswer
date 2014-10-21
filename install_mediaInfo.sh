#!/bin/bash

Zen_Make()
{
    numprocs=1
    if test -e /proc/stat; then
        numprocs=`egrep -c ^cpu[0-9]+ /proc/stat || :`
        if [ "$numprocs" = "0" ]; then
            numprocs=1
        fi
    fi
    if type sysctl &> /dev/null; then
        numprocs=`sysctl -n hw.ncpu`
        if [ "$numprocs" = "0" ]; then
            numprocs=1
        fi
    fi
    make -s -j$numprocs
}

APP=$0
APPDIR=${APP%%install_mediaInfo.sh}
mkdir ${APPDIR}mediainfo
cd ${APPDIR}mediainfo
#Download mediainfo libs
if [ ! -e MediaInfo_GUI_0.7.61_GNU_FromSource.tar.bz2 ];then
	wget -O MediaInfo_GUI_0.7.61_GNU_FromSource.tar.bz2 http://downloads.sourceforge.net/project/mediainfo/binary/mediainfo-gui/0.7.61/MediaInfo_GUI_0.7.61_GNU_FromSource.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fmediainfo%2Ffiles%2Fsource%2Fmediainfo%2F&ts=1371619321&use_mirror=nchc 
fi 

#Download mediainfo
if [ ! -e mediainfo_0.7.63.tar.gz ];then
	wget -O mediainfo_0.7.63.tar.gz http://downloads.sourceforge.net/project/mediainfo/source/mediainfo/0.7.63/mediainfo_0.7.63.tar.gz?r=http%3A%2F%2Fsourceforge.net%2Fprojects%2Fmediainfo%2Ffiles%2Fsource%2Fmediainfo%2F0.7.63%2F&ts=1371619389&use_mirror=jaist  
fi


tar -xvf MediaInfo_GUI_0.7.61_GNU_FromSource.tar.bz2

tar -xvf mediainfo_0.7.63.tar.gz

rm -r MediaInfo_GUI_GNU_FromSource/MediaInfo
mv MediaInfo MediaInfo_GUI_GNU_FromSource

cd MediaInfo_GUI_GNU_FromSource/ZenLib/Project/GNU/Library
./autogen
./configure --enable-shared --prefix=/usr
make clean
Zen_Make
sudo make install

cd ../../../../MediaInfoLib/Project/GNU/Library/
./configure --enable-shared --prefix=/usr
make clean
Zen_Make
sudo make install

cd ../../../../


sed -i '/Stream_Other/d' MediaInfo/Source/Common/Core.cpp

cd MediaInfo/Project/GNU/CLI/
./autogen
./configure --enable-staticlibs --prefix=/usr
make clean
Zen_Make
sudo make install


rm -rf mediainfo

