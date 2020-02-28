#!/bin/bash

##
# List all known projects.
# Project is identified with relative path to project's root directory from repository root.
# 
# Projects are defined in file `projects.txt` under ci script's root directory (one level up from this script).
# This file should contain lines with glob patters pointing to root directories of all supported projects.
#
# Usage:
#   list-projects.sh
##

set -e

# Find script directory (no support for symlinks)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Just resolve all patterns in projects file
for PROJECT in $(cat ${DIR}/../projects.txt); do 
	echo ${PROJECT} 
done
