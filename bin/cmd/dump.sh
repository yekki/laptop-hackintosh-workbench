#!/usr/bin/env bash

source "$YEKKI_HOME/bin/include.sh"

function _kext_status {

	local _OUTPUT="${YEKKI_HOME}/stage/kextstat_output.txt"

	touch "${_OUTPUT}"

	kextstat|grep -y acpiplat >> "${_OUTPUT}"
	kextstat|grep -y appleintelcpu >> "${_OUTPUT}"
	kextstat|grep -y applelpc >> "${_OUTPUT}"
	kextstat|grep -y applehda >> "${_OUTPUT}"

	_info 'kext status logged'
}

function _kext_cache {

	local _OUTPUT="${YEKKI_HOME}/stage/kextcache_output.txt"

	touch "${_OUTPUT}"
	touch /System/Library/Extensions >> "${_OUTPUT}" 2>&1 
	kextcache -u / >> "${_OUTPUT}" 2>&1
	_info 'kext cache rebuilt and logged'
}

function _dump_clover {

	mount EFI

	cp -R /Volumes/EFI/EFI/CLOVER "${YEKKI_HOME}/stage"

	rm -rf "${YEKKI_HOME}/stage/CLOVER/ACPI/WINDOWS"
	rm -rf "${YEKKI_HOME}/stage/CLOVER/doc"
	rm -rf "${YEKKI_HOME}/stage/CLOVER/misc"
	rm -rf "${YEKKI_HOME}/stage/CLOVER/themes"
	rm -rf "${YEKKI_HOME}/stage/CLOVER/tools"
	rm -rf "${YEKKI_HOME}/stage/CLOVER/OEM"
	rm -rf "${YEKKI_HOME}/stage/CLOVER/ROM"
	_info 'clover dumped'
}

function _zip_dump {

	cd "${YEKKI_HOME}/stage"
	zip -r -D -X -q "${YEKKI_HOME}/output/${LAPTOP_BRAND}_${LAPTOP_MODE}_${YEKKI_LAPTOP_SERIES}_${YEKKI_OSX_VER}_$(date '+%Y%m%d_%H%M%S').zip" ./*
}

function _exec {

	_ensure_admin

	_init
	_dump_clover
	_kext_status
	_kext_cache

	chown -R `logname` "${YEKKI_HOME}/stage"

	_zip_dump
}

_exec