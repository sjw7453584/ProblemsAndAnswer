#!/bin/bash
Platform=`lsb_release -a | grep -i "description:"|sed -n 's/[\t]\+//p'|cut -d ':' -f 2|cut -d ' ' -f 1 |tr '[A-Z]' '[a-z]'`
echo $Platform
if [ "$Platform" = "ubuntu" ];then
	sudo apt-get install expect ffmpeg
else
	if [ "$Platform" = "suse" ];then
		sudo zypper in expect ffmpeg 
	else
		sudo yum install expect ffmpeg 
	fi
fi 

APP=$0
APPDIR=${APP%Install_Prerequisites.sh}
cd "$APPDIR"Dependencies
pwd
if [ ! -e Crypt-RC4-2.02.tar.gz ];then
	wget http://search.cpan.org/CPAN/authors/id/S/SI/SIFUKURT/Crypt-RC4-2.02.tar.gz
fi 
tar -xvf Crypt-RC4-2.02.tar.gz
cd Crypt-RC4-2.02
perl Makefile.PL
make
make test
sudo make install

cd ..
if [ ! -e Digest-Perl-MD5-1.9.tar.gz ];then
	wget http://search.cpan.org/CPAN/authors/id/D/DE/DELTA/Digest-Perl-MD5-1.9.tar.gz
fi 
tar -xvf Digest-Perl-MD5-1.9.tar.gz
cd Digest-Perl-MD5-1.9
perl Makefile.PL
make
make test
sudo make install

cd ..
if [ ! -e OLE-Storage_Lite-0.19.tar.gz ];then
	wget http://search.cpan.org/CPAN/authors/id/J/JM/JMCNAMARA/OLE-Storage_Lite-0.19.tar.gz
fi  
tar -xvf OLE-Storage_Lite-0.19.tar.gz
cd OLE-Storage_Lite-0.19
perl Makefile.PL
make
make test
sudo make install

cd ..
if [ ! -e Spreadsheet-WriteExcel-2.38.tar.gz ];then
	wget http://search.cpan.org/CPAN/authors/id/J/JM/JMCNAMARA/Spreadsheet-WriteExcel-2.38.tar.gz
fi 
tar -xvf Spreadsheet-WriteExcel-2.38.tar.gz
cd Spreadsheet-WriteExcel-2.38
perl Makefile.PL
make
make test
sudo make install

cd ..
if [ ! -e Spreadsheet-ParseExcel-0.59.tar.gz ];then
	wget http://search.cpan.org/CPAN/authors/id/J/JM/JMCNAMARA/Spreadsheet-ParseExcel-0.59.tar.gz
fi 
tar -xvf Spreadsheet-ParseExcel-0.59.tar.gz
cd Spreadsheet-ParseExcel-0.59
perl Makefile.PL
make
make test
sudo make install
cd ..
