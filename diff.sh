#!/usr/bin
find -iregex ".*\.\(cpp\|hpp\|h\)" |xargs --verbose -i svn diff {} >diff.txt
