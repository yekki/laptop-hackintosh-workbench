#!/usr/bin/env bash

source "$YEKKI_HOME/bin/include.sh"
        
########## install command ##########

function _download_tool {

  local _FILE=$2

  [[ ! "$2" == *zip ]] && _FILE=$3

  _download $1 $2

  if _exists_one "${YEKKI_HOME}/stage/"${_FILE}; then
    unzip -o "${YEKKI_HOME}/stage/${_FILE}" -d "${YEKKI_HOME}/stage"
  else
     _error "failed to install ${_FILE}"
  fi
}

function _download_kexts {
  for k in ${KEXT_SUPPORTED_LIST[@]}; do _fetch_rehabman_kext $k; done
  _cleanup_dir "${YEKKI_HOME}/kexts"
  cp -Rf "${YEKKI_HOME}/stage/"*.kext "${YEKKI_HOME}/kexts"
  cp -Rf "${YEKKI_HOME}/stage/release/"*.kext "${YEKKI_HOME}/kexts"
  cp -Rf "${YEKKI_HOME}/stage/release/VoodooPS2Daemon" "${YEKKI_HOME}/kexts"
  _cp_if_exists "${YEKKI_HOME}/stage/org.rehabman.voodoo.driver.Daemon.plist" "${YEKKI_HOME}/kexts"
}

function _ssdtPRGen {

  _download_tool "https://codeload.github.com/Piker-Alpha/ssdtPRGen.sh/zip/Beta" "ssdtPRGen.sh-Beta.zip" &&
  rm -rf ~/Library/ssdtPRGen &&
  mv "${YEKKI_HOME}/stage/ssdtPRGen.sh-Beta" ~/Library/ssdtPRGen &&
  _info 'installed ssdtPRGen at ~/Library/ssdtPRGen'
}

function _acpi_tools {

  _download_tool os-x-maciasl-patchmatic RehabMan-patchmatic RehabMan-patchmatic*.zip
  _cp_if_exists "${YEKKI_HOME}/stage/patchmatic" /usr/local/bin/patchmatic &&
  _info "installed patchmatic at /usr/local/bin"
 
  _download_tool acpica iasl iasl.zip &&
  _cp_if_exists "${YEKKI_HOME}/stage/iasl" /usr/local/bin/iasl &&
  _info "installed iasl at /usr/local/bin"

  _download_tool os-x-ioio RehabMan-ioio RehabMan-ioio*.zip &&
  _cp_if_exists "${YEKKI_HOME}/stage/${KEXT_MODE}/ioio" /usr/local/bin/ioio &&
  _info "installed ioio at /usr/local/bin"
}

function _acpi_patches {

  git clone https://github.com/RehabMan/Laptop-DSDT-Patch.git
  git clone https://github.com/RehabMan/OS-X-ACPI-Debug.git
  
  _cleanup_dir "${YEKKI_HOME}/acpi/patches"
  _find_cp "${YEKKI_HOME}/stage/Laptop-DSDT-Patch" '*.txt' "${YEKKI_HOME}/acpi/patches/"
  _find_cp "${YEKKI_HOME}/stage/OS-X-ACPI-Debug" '*.txt' "${YEKKI_HOME}/acpi/patches/"
  
  _info "updated acpi patches at ${YEKKI_HOME}/acpi/patches"
}

function _clover_config {

  git clone https://github.com/RehabMan/OS-X-Clover-Laptop-Config.git &&
  _cleanup_dir "${YEKKI_HOME}/clover/templates" &&
  cp -f "${YEKKI_HOME}/stage/OS-X-Clover-Laptop-Config/"*.plist "${YEKKI_HOME}/clover/templates/"

  _info "updated clover configuration templates at ${YEKKI_HOME}/clover/templates"
}

function _clover_driver {
  
  _download https://github.com/JrCs/CloverGrowerPro/raw/master/Files/HFSPlus/X64/HFSPlus.efi &&
  _cleanup_dir "${YEKKI_HOME}/clover/drivers" &&
  _cp_if_exists "${YEKKI_HOME}/stage/HFSPlus.efi" "${YEKKI_HOME}/clover/drivers"

  _info "updated clover drivers at ${YEKKI_HOME}/clover/drivers"
}

function _exec {

  _exists_one "${YEKKI_HOME}/.yekki.installed" && _error "please uninstall ${APP_NAME} ${APP_VER} firstly."
  
  _init
  _acpi_tools
  _ssdtPRGen
  _acpi_patches
  _clover_config
  _clover_driver
  
  touch "${YEKKI_HOME}/.yekki.installed"

  _info "${APP_NAME} ${APP_VER} installed on your host, please enjoy it!"
}

_exec