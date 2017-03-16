#!/bin/bash

#
# Script (str2base64.sh) to convert a string to base64 data in a way that it can be 
# used for properties as text <"desired text"> instead of <646573697265642074657874>
# 
#
# Version 1.1 - Copyright (c) 2013-2016 by Pike R. Alpha
#

#
# Get input from user.

#
read -p "Enter string to convert: " string

#
# Convert to postscript format.
#

data=$(echo -n "${string}"|xxd -ps|tr -d '\n')

#
# Add "00" to the data and convert it to base64 data.
#

echo -n "${data}00"|xxd -r -p|base64