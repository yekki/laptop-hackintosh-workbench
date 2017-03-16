 #!/usr/bin/env bash

source "$YEKKI_HOME/bin/include.sh"
        
########## bootloader command ##########

function _kext {

  local _KEXTS_DIR="/Volumes/EFI/EFI/CLOVER/kexts/${YEKKI_OSX_VER}"
  _cleanup_dir "${_KEXTS_DIR}"
  kexts
  cp -R "${YEKKI_HOME}/output/"*.kext "${_KEXTS_DIR}"
}

function _config {

  local _VAR1="${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/solution/clover/config"
  local _VAR2=/Volumes/EFI/EFI/CLOVER/config.plist
  local _VAR3="${_VAR1}/${YEKKI_OSX_VER}_config.plist"

  _exists_one ${_VAR2} && mv ${_VAR2} ${_VAR2}.orig && _info "backup ${_VAR2} to config.plist.orig"
  _exists_one ${_VAR3} && cp ${_VAR3} ${_VAR2} && _info 'updated config.plist successfully' || _error "${_VAR3} not found."
}

function _acpi {

  local _VAR1=/Volumes/EFI/EFI/CLOVER/ACPI/patched
  local _VAR2="${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/solution/clover/patched"

  if [ -d "${_VAR2}/${LAPTOP_BIOS_VER}" ]; then _VAR2="${_VAR2}/${LAPTOP_BIOS_VER}"; fi

  _cleanup_dir "${_VAR1}"
  
  if [ -d "${_VAR2}" ]; then
    find "${_VAR2}/" -type f -exec cp {} "${_VAR1}" \;
    _info 'updated DSDT/SSDT files successfully'
  else
    _error "no DSDT/SSDT for:${YEKKI_LAPTOP_SERIES}"
  fi
}

function _driver {

  local _HFSPlus="${YEKKI_HOME}/clover/drivers/HFSPlus.efi"
  local _DRIVER=/Volumes/EFI/EFI/CLOVER/drivers64UEFI

  if [ ! -d "${_DRIVER}" ]; then mkdir -p "${_DRIVER}"; fi

  _cp_if_exists "${_HFSPlus}" "${_DRIVER}"
}

function _theme {
  local _THEME_DIR="/Volumes/EFI/EFI/CLOVER/themes/${CLOVER_THEME}"
  mkdir -p "${_THEME_DIR}"
  _unzip_if_exists "${YEKKI_HOME}/clover/themes/${CLOVER_THEME}.zip" "${_THEME_DIR}"
}

function _custom_clover {

  if [ -d /Volumes/EFI/EFI/CLOVER ]
  then
    _config && _driver && _acpi && _kext && _theme
  else
    _error 'please install clover bootloader firstly'
  fi
}

function _format {

  if [ -n "$1" ] ;then  
    
    read -p "Are you sure to erase disk$1?[Y/n] " response

    case ${response} in [yY]) 

        diskutil partitionDisk /dev/disk$1 1 GPT HFS+J "install_macOS" R
        ;;
    *)
        _info canceld
        ;;
    esac
  else
    _error "please add disk number(will be erased) to your command. for example: sudo -E ./yekki bootloader 1"
  fi  
}

function _cleanup_efi {
  read -p "Are you sure to erase EFI(disk$1s1)?[Y/n] " response

  case ${response} in [yY]) 

      rm -rf /Volumes/EFI/*
      ;;
  *)
      _error canceld
      ;;
  esac
}

function _post_check {

  [ ! -d "/Volumes/EFI/EFI/CLOVER/themes/${CLOVER_THEME}" ] && _error "lost clover theme"
  [ ! -f "/Volumes/EFI/EFI/CLOVER/config.plist" ] && _error "lost clover config file"
  [ ! -d "/Volumes/EFI/EFI/CLOVER/kexts/${YEKKI_OSX_VER}/FakeSMC.kext" ] && _error "lost core kext: FakeSMC.kext"
}

function _exec {
  
  [ ! -f "${YEKKI_HOME}/clover/archives/${CLOVER_PREFIX}${CLOVER_VER}.zip" ] && _error "please prepare ${CLOVER_PREFIX}${CLOVER_VER} archive firstly"

  _ensure_admin
  
  _format $1
  
  mount install_macOS
  
  _cleanup_efi $1
  
  _unzip_if_exists "${YEKKI_HOME}/clover/archives/${CLOVER_PREFIX}${CLOVER_VER}.zip" /Volumes/EFI

  _custom_clover

  _post_check
}

_exec $1