#!/bin/bash
curDir=`pwd`
projectName=${curDir##*\/}
echo "(if (file-exists-p \"$curDir/Makefile\")
(ede-cpp-root-project \"$projectName\" :file \"$curDir/Makefile\"
					  :include-path '( 
									   " >>~/_emacs/projects.el
find -iname "*.h"|sed -n 's/\/[-a-zA-Z0-9_]*\.h//'p |sort |uniq |sed -n 's/\.\//"\//'p |sed -n 's/[-\"\/a-zA-Z_]*/&\/"/'p >>~/_emacs/projects.el

echo ")
:system-include-path '( \"/usr/include/\" \"/usr/lib/gcc/x86_64-linux-gnu/4.6/include/\" \"/usr/local/include/\" \"/usr/lib/gcc/x86_64-linux-gnu/4.6/include-fixed/\" \"/usr/include/x86_64-linux-gnu/\" \"/usr/include/c++/4.6/\" \"/usr/include/c++/4.6/x86_64-linux-gnu/\" \"/usr/include/c++/4.6/backward/\" \"/usr/lib/syslinux/com32/include/\")
					  )
)" >>~/_emacs/projects.el

