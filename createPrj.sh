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


project_e=`grep "(if (file-exists-p \"$curDir/${referFile}\"" ~/_emacs/projects.el`

if [ "$project_e" = "" ];then
echo "(if (file-exists-p \"$curDir/${referFile}\")
(ede-cpp-root-project \"$projectName\" :file \"$curDir/${referFile}\"
					  :include-path '( 
									   " >>~/_emacs/projects.el
find -iname "*.h"|sed -n 's/\/[-a-zA-Z0-9_+]*\.h//'p |sort |uniq |sed -n 's/\.\//"\//'p |sed -n 's/[-\"\/a-zA-Z_0-9\.]*/&\/"/'p >>~/_emacs/projects.el

echo ")
:system-include-path '( $sysInclude )
					  )
)" >>~/_emacs/projects.el

ede_e=`grep "ede-project-directories" ~/_emacs/projects.el`
if [ "$ede_e" = "" ];then
	echo "(setq ede-project-directories  '(\"$curDir\"))">>~/_emacs/projects.el
else
	echo "(add-to-list 'ede-project-directories (quote (\"$curDir\")))">>~/_emacs/projects.el
fi

ccsearch_e=`grep "cc-search-directories" ~/_emacs/projects.el`
if [ "$ccsearch_e" = "" ];then
echo "(setq cc-search-directories  '($sysInclude))">>~/_emacs/projects.el
fi 


semanticdb_e=`grep "semanticdb-project-roots" ~/_emacs/projects.el`
if [ "$semanticdb_e" = "" ];then
	echo "(setq semanticdb-project-roots '(\"$curDir\"))

">>~/_emacs/projects.el

else
	echo "(add-to-list 'semanticdb-project-roots \"$curDir\")

">>~/_emacs/projects.el
fi

rm $main $gccInfo
fi 

