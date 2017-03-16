#!/usr/bin/env bash

########## load global & series specs meta data ##########
source "${YEKKI_HOME}/conf/default.properties"
source "${YEKKI_HOME}/laptop/default.properties"

source "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/conf/common.properties"

if [ -f "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/conf/${YEKKI_OSX_VER}.properties" ]
then
	source "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/conf/${YEKKI_OSX_VER}.properties"
else
	echo "ERROR: your target $YEKKI_LAPTOP_SERIES doesn't support macOS version:$YEKKI_OSX_VER"
	exit -1
fi

########## load internal functions ##########
source "${YEKKI_HOME}/bin/common/functions.sh"

########## load 3rd device functions ##########
#source "${YEKKI_HOME}/bin/common/devices.sh"

########## load supported commands##########
source "$YEKKI_HOME/bin/common/commands.sh"
