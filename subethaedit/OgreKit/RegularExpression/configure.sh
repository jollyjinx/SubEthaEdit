#!/bin/csh

if ($1 == "clean") then
    rm -rf "RegularExpression/oniguruma"
endif

if (-e "RegularExpression/oniguruma") then
	echo "oniguruma already exists."
else
	echo "oniguruma is not found. Extracting oniguruma..."
	cd RegularExpression
	tar zxvf onigd20040514.tar.gz
#	echo "Applying patch..."
#	cp 20040414.patch oniguruma/.
#	cd oniguruma
#	cp regexec.c regexec.c.original
#	patch < 20040414.patch
#	cd ..
	cd ..
endif

if (-e "RegularExpression/oniguruma/config.h") then
	echo "config.h already exists."
else
	echo "config.h is not found. Creating config.h..."
	cd RegularExpression/oniguruma
	./configure
endif

exit

# Name: configure.sh
# Project: OgreKit
#
# Creation Date: Sep 7 2003
# Author: Isao Sonobe <sonobe@gauge.scphys.kyoto-u.ac.jp>
# Copyright: Copyright (c) 2003 Isao Sonobe, All rights reserved.
# License: OgreKit License
#
# Tabsize: 4

