#!/bin/bash
referFile=$1
if [ "$referFile" = "" ];then
	referFile="Makefile"
fi 
curDir=`pwd`
projectName=${curDir##*\/}
main=createPrj_test_main.cpp
gccInfo=createPrj_test_gccInfo

echo "int main(){return 0;}">$main
gcc -v $main 2>$gccInfo
sysInclude=`sed -n "/#include <\.\.\.> search starts here:/,/End of search list/"'p' $gccInfo|grep -v "search"|sed -n 's/[ \t]*//'p|sed -n 's/[-\"\/a-zA-Z_0-9\.+]*/\\"&\\"/'p`

echo "(if (file-exists-p \"$curDir/${referFile}\")
(ede-cpp-root-project \"$projectName\" :file \"$curDir/${referFile}\"
					  :include-path '( 
									   " >>~/_emacs/projects.el
find -iname "*.h"|sed -n 's/\/[-a-zA-Z0-9_+]*\.h//'p |sort |uniq |sed -n 's/\.\//"\//'p |sed -n 's/[-\"\/a-zA-Z_0-9\.]*/&\/"/'p >>~/_emacs/projects.el

echo ")
:system-include-path '( $sysInclude )
					  )
)" >>~/_emacs/projects.el

rm $main $gccInfo

