#!/usr/bin/env bash

########## internal functions ##########


function _info {
  echo "INFO: $1"
}

function _defined {
  [[ ${!1-X} == ${!1-Y} ]]
}

function _native_injector_ {

  _ensure_admin

  eval _TARGET=( '"${'${1}'[@]}"' )

  local _KEXT_NAME=${_TARGET[0]}
  local _CATALOG=${_TARGET[1]}
  local _ORIG_PID=${_TARGET[2]}
  local _ORIG_VID=${_TARGET[3]}

  local _TARGET_PID=$2
  local _TARGET_VID=$3


}

function _laptop {
  source "${YEKKI_HOME}/laptop/${1}/conf/common.properties"

  _info "${LAPTOP_BRAND} ${LAPTOP_MODEL} ${LAPTOP_SERIES}"
}

#
# returns 0 if a variable is defined (set) and value's length > 0
# returns 1 otherwise
#
function _has_value {
  if defined $1; then
    if [[ -n ${!1} ]]; then
        return 0
    fi
  fi
  return 1
}

function _rebuild_cache {

  _ensure_admin
  kextcache -system-prelinked-kernel > /dev/null 2>&1
  kextcache -system-caches > /dev/null 2>&1
}

function _exists_in_array {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

function _str_replace {
  local ORIG="$1"
  local DEST="$2"
  local DATA="$3"

  echo "$DATA" | sed "s/$ORIG/$DEST/g"
}

function _fetch_rehabman_kext {

  local _KEXT_VAR=KEXT_$1[@]
  local _KEXT_VARS=(${!_KEXT_VAR})
  
  IFS='|' read -r -a FILES <<< ${_KEXT_VARS[3]}

  for f in ${FILES[@]}
  do
    if [ -z $2 ]
    then
      _download ${_KEXT_VARS[0]} RehabMan-${_KEXT_VARS[1]}
      _unzip_if_exists "${YEKKI_HOME}/stage/RehabMan-${_KEXT_VARS[1]}"*.zip "${YEKKI_HOME}/stage" &&
      _cp_if_any_exists "${YEKKI_HOME}/stage/${KEXT_MODE}/${f}" "${YEKKI_HOME}/output" &&
      _cp_if_any_exists "${YEKKI_HOME}/stage/Universal/${f}" "${YEKKI_HOME}/output" &&
      _cp_if_any_exists "${YEKKI_HOME}/stage/${f}" "${YEKKI_HOME}/output" &&
      _info "downloaded kext:$1"
    else
      _cp_if_any_exists "${YEKKI_HOME}/kexts/${f}" "${YEKKI_HOME}/output" && _info "prepared kext:$1" || _error "can't find kext: $1"
    fi    
  done
}

#
# Replace string of text in file.
# Uses the ed editor to replace the string.
#
# arg1 = string to be matched
# arg2 = new string that replaces matched string
# arg3 = file to operate on.
#
function _str_replace_in_file {
    local ORIG="$1"
    local DEST="$2"
    local FILE="$3"

    has_value FILE 
    die_if_false $? "Empty argument 'file'"
    file_exists "$FILE"
    die_if_false $? "File does not exist"

    printf ",s/$ORIG/$DEST/g\nw\nQ" | ed -s "$FILE" > /dev/null 2>&1
    return "$?"
}

function _error {
  _info "ERROR: $1" && exit -1
}

function _tolower {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

function _toupper {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

function _is_empty_str {
  [[ -z "${1// }" ]]
}

function _is_empty_dir {
  
  [ ! "$(ls -A $1)" ]
}

function _exists_one {
  [[ $# -eq 1 && -f $1 ]]
}

function _op_if_exists {
  
  _exists_one $1 && eval "$3"
}

function _cp_if_exists {

  _op_if_exists $1 $2 "cp $1 $2"
}

function _mv_if_exists {
 
  _op_if_exists $1 $2 "mv $1 $2"
}

function _unzip_if_exists {

  _op_if_exists $1 $2 "unzip -o $1 -d $2 > /dev/null 2>&1"
}

function _find_cp {
 
  if [ ! -d $1 ]; then _error "directory $1 isn't exist."; fi
  if [ ! -d $3 ]; then _error "directory $3 isn't exist."; fi

  find $1 -type f -name $2 -exec cp '{}' "$3" ';'
}

function _append_if_exists {

  _exists_one $1 && cat $1 >> $2
}

function _ensure_admin {

  [ "$(id -u)" != "0" ] && _error 'please run as root, for example: sudo -E ./yekki [cmd] [arg]'
}

function _check_url {

  resp=$(curl --write-out %{http_code} --silent --output /dev/null $1)

  [ "${resp}" = "404" ] && _error 'resources does not exist.'
}

function _cleanup_dir {
  
  [ -d $1 ] && rm -Rf $1/* || mkdir -p $1
}

function _unzip_all {

  for file in `ls $1/*.zip`; do
    unzip ${file} -d "${YEKKI_HOME}/output"
  done
}

function _init {

  _cleanup_dir "${YEKKI_HOME}/output" && _cleanup_dir "${YEKKI_HOME}/stage" && cd "${YEKKI_HOME}/stage"
}

# example:
# _download os-x-eapd-codec-commander RehabMan-CodecCommander
# _download http://sourceforge.net/projects/osx86drivers/files/latest/download?source=files AppleIntelE1000e.kext.zip 
#TODO: BUG -  _download https://github.com/vit9696/AppleALC/releases/download/${HDA_ALC_VER}/${HDA_ALC_VER}.RELEASE.zip
function _download {
  case $1 in 
    http* )
      _info "downloading $1"
      _check_url $1
      if [ "$2" == "" ]; then
        curl --remote-name --insecure --progress-bar --location $1
      else
        curl --output $2 --insecure --progress-bar --location $1
      fi
      ;;
    * )
      _info "downloading $2:"
      local user=RehabMan
      local output=""

      if [[ "$3" == *".zip" ]]; then
        output=$3
      elif [ "$3" != "" ]; then
        user=$3;
        if [ "$4" != "" ] && [[ "$4" == *".zip" ]]; then output=$4;fi
      fi

      curl --location --silent --insecure --output /tmp/me.yekki.hackintosh-download.txt https://bitbucket.org/${user}/$1/downloads
      scrape=`grep -o -m 1 href\=\".*$2.*\.zip.*\" /tmp/me.yekki.hackintosh-download.txt|perl -ne 'print $1 if /href\=\"(.*)\"/'`
      url=https://bitbucket.org$scrape

      _check_url $url
      if [ "${output}" == "" ]; then
        curl --remote-name --insecure --progress-bar --location "${url}"
      else
        curl --output $output --insecure --progress-bar --location "${url}"
      fi

      rm -rf /tmp/me.yekki.hackintosh-download.txt
      ;;
  esac
}

function _installer {

  case ${YEKKI_OSX_VER} in
    10.11 )
      echo "Install OS X El Capitan"
      ;;
    10.12 )
      echo "Install macOS Sierra"
  esac
}

function _cp_if_any_exists {

  [[ -d $1 || -f $1 ]] && ( cp -Rf $1 $2 )
}

function _join_by {
  local IFS="$1"
  shift
  echo "$*"
}

function _fetch_tool {

  local _APP_VAR=TOOL_$1[@]
  local _APP_VARS=(${!_APP_VAR})
  local _APP_ARGS=`_join_by ' ' ${_APP_VARS[@]}`

  _download $_APP_ARGS
}

function _cleanup_zip {

  [ -d $1 ] && rm -rf "$1/__MACOSX" ".DS_Store"
}

function _post {
  sudo chown -R ${APP_OWNER} "${YEKKI_HOME}/stage" "${YEKKI_HOME}/output"
  _info "recovery file system owner:${APP_OWNER}"
}
