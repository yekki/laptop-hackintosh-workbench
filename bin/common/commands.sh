#!/usr/bin/env bash

########## all supported commands ##########

function version {

  _info "${APP_NAME} v${APP_VER} Author:${APP_AUTHOR}"
}

function _debug {
  echo "This command is for debugging."

  str1=a
  str2=a

  if [ "$str1"="$str2" ]; then echo OK; fi
}

function reinstall {

  rm -rf "${YEKKI_HOME}/.yekki.installed"

  "${YEKKI_HOME}/bin/cmd/install.sh"
}

function str2base64 {
  read -p "Enter string to convert: " string

  #
  # Convert to postscript format.
  #

  data=$(echo -n "${string}"|xxd -ps|tr -d '\n')

  #
  # Add "00" to the data and convert it to base64 data.
  #

  echo -n "${data}00"|xxd -r -p|base64
}

function enable_ps2_test {
  ioio -s ApplePS2Keyboard LogScanCodes 1
  open -a Console
}

function disable_ps2_test {
  ioio -s ApplePS2Keyboard LogScanCodes 0
}

# TODO: Bug - Duplicate download
function kexts {
  _init

  if [ -z $1 ]
  then
    for k in ${KEXT_LIST[@]}
    do
      if _exists_in_array $k "${KEXT_SUPPORTED_LIST[@]}"
      then
        if [ -f "${YEKKI_HOME}/laptop/common/injectors/$k.zip" ]
        then
          _cp_if_any_exists "${YEKKI_HOME}/laptop/common/injectors/$k.zip" "${YEKKI_HOME}/stage"
          _unzip_if_exists "${YEKKI_HOME}/stage/${k}.zip" "${YEKKI_HOME}/output"
        else
          _fetch_rehabman_kext $k
        fi
      else
        _error "kext $k doesn't be supported."
      fi
    done

    # ADB & PS2 re-mapping
    if [ -d "${YEKKI_HOME}/output/VoodooPS2Controller.kext" ]
    then
      if [ "${#KB_PS2[@]}" -ne 0 ]
      then
        for m in ${KB_PS2[@]}
        do
          /usr/libexec/PlistBuddy -c "Add ':IOKitPersonalities:ApplePS2Keyboard:Platform Profile:Default:Custom PS2 Map:0' string '$m'" "${YEKKI_HOME}/output/VoodooPS2Controller.kext/Contents/PlugIns/VoodooPS2Keyboard.kext/Contents/Info.plist"
        done
        _info 'applied PS/2 mapping successful'
      fi

      if [ "${#KB_ADB[@]}" -ne 0 ]
      then
        for m in ${KB_ADB[@]}
        do
          /usr/libexec/PlistBuddy -c "Add ':IOKitPersonalities:ApplePS2Keyboard:Platform Profile:Default:Custom ADB Map:0' string '$m'" "${YEKKI_HOME}/output/VoodooPS2Controller.kext/Contents/PlugIns/VoodooPS2Keyboard.kext/Contents/Info.plist"
        done
        _info 'applied ADB mapping successful'
      fi
    fi 
  else
    _fetch_rehabman_kext $1
  fi
}

function bt {

  _init

  case $DEVICE_BT in
    bcm94352z|bcm20702)
      _fetch_rehabman_kext BrcmPatchRAM

      mkdir -p "${YEKKI_HOME}/output/le"
      
      cp -Rf "${YEKKI_HOME}/output/BrcmFirmwareRepo.kext" "${YEKKI_HOME}/output/BrcmPatchRAM2.kext" "${YEKKI_HOME}/output/le"
      
      rm -rf "${YEKKI_HOME}/output/BrcmFirmwareRepo.kext"

      [ $DEVICE_BT = bcm94352z ] && _fetch_rehabman_kext FakePCIID_Broadcom_WiFi
      ;;
    *)
      _error "unsupported bluetooth patcher for device:${DEVICE_BT}"
  esac
}

function hda {

  _init

  case $DEVICE_HDA_PATCHER in
    injector)
      "${YEKKI_HOME}/bin/cmd/hda_injector.sh"
      return
      ;;
    voodoo)
       local _URL="http://sourceforge.net/projects/voodoohda/files/VoodooHDA-${HDA_VOODOO_VER}.pkg.zip/download"
      _check_url $_URL
      _download $_URL "VoodooHDA-${HDA_VOODOO_VER}.pkg.zip"
      
      if _exists_one "${YEKKI_HOME}/stage/VoodooHDA-${HDA_VOODOO_VER}.pkg.zip"; then
        unzip -o "${YEKKI_HOME}/stage/VoodooHDA"*.zip -d "${YEKKI_HOME}/output"
        rm -rf "${YEKKI_HOME}/output/__MACOSX"
      fi
      ;;
    alc)
      local _URL="https://github.com/vit9696/AppleALC/releases/download/${HDA_ALC_VER}/${HDA_ALC_VER}.RELEASE.zip"
      _check_url $_URL
      _download $_URL
      
      if _exists_one "${YEKKI_HOME}/stage/${HDA_ALC_VER}.RELEASE.zip"; then
        unzip -o "${YEKKI_HOME}/stage/${HDA_ALC_VER}.RELEASE.zip" -d "${YEKKI_HOME}/stage"
        cp -R "${YEKKI_HOME}/stage/AppleALC.kext" "${YEKKI_HOME}/output"
      fi
      ;;
    patcher)
      git clone https://github.com/Mirone/AppleHDAPatcher.git "${YEKKI_HOME}/stage/applehda"
      local _CODEC=`_toupper $LAPTOP_CODEC`
      if [ -d "${YEKKI_HOME}/stage/applehda/Patches/Laptop/${_CODEC}" ]; then
        cp -R "${YEKKI_HOME}/stage/applehda/Patches/Laptop/${_CODEC}" "${YEKKI_HOME}/output"
        cp -R "${YEKKI_HOME}/stage/applehda/AppleHDAPatcher.app" "${YEKKI_HOME}/output"
      fi
      ;;
    *)
      _error "unsupported HDA patcher:${DEVICE_HDA_PATCHER}"
      ;;
  esac
}

function bt_inject {

  _ensure_admin

  if [ -z ${LAPTOP_BT} ]
  then
    _info 'there is no bluetooth device defination in this laptop.'
  else
    local _KEXT_NAME
    local _CATALOG
    
    IFS=' _ ' read -ra DEVICE <<< ${LAPTOP_BT}

    if _exists_in_array ${LAPTOP_BT} ${BT_IOBluetoothHostControllerUSBTransport_LIST[@]}
    then
      _KEXT_NAME=IOBluetoothHostControllerUSBTransport
      _CATALOG=EricssonROK101
    elif _exists_in_array ${LAPTOP_BT} ${BT_BroadcomBluetoothHostControllerUSBTransport_LIST[@]}
    then
      _KEXT_NAME=BroadcomBluetoothHostControllerUSBTransport
      _CATALOG=Broadcom2045FamilyUSBBluetoothHCIController_D
    else
      _error "unsupported bt device: ${LAPTOP_BT} (pid_vid)"
    fi

    local _PLIST=/System/Library/Extensions/IOBluetoothFamily.kext/Contents/PlugIns/${_KEXT_NAME}.kext/Contents/Info.plist

    /usr/libexec/PlistBuddy -c "Set IOKitPersonalities:${_CATALOG}:idProduct ${DEVICE[0]}" ${_PLIST}
    /usr/libexec/PlistBuddy -c "Set IOKitPersonalities:${_CATALOG}:idVendor ${DEVICE[1]}" ${_PLIST}

    local _PID=`/usr/libexec/PlistBuddy -c "print IOKitPersonalities:${_CATALOG}:idProduct" ${_PLIST}` 
    local _VID=`/usr/libexec/PlistBuddy -c "print IOKitPersonalities:${_CATALOG}:idVendor" ${_PLIST}` 
    
    if (_PID=${DEVICE[0]}) && (_VID=${DEVICE[1]})
    then
      _rebuild_cache
      _info 'updated successfully, please reboot make it works'
    else
      _error "failed update device: ${LAPTOP_BT}"
    fi   
  fi
}


function codec {
  
  _laptop $YEKKI_LAPTOP_WORKBENCH

  # if HDEF
  HDEF=$(ioreg -rw 0 -p IODeviceTree -n HDEF | grep -o "HDEF@")
  
  if [ ${HDEF:0:5} == "HDEF@" ]
  then
    HDEF=$(ioreg -rw 0 -p IODeviceTree -n HDEF | awk '{ print $2 }' )
    echo $HDEF
  else
    _error "no HDEF device found in DSDT"
  fi

  VendorID=($(ioreg -rxn IOHDACodecDevice | grep VendorID | awk '{ print $4 }' ))
  RevisionID=($(ioreg -rxn IOHDACodecDevice | grep RevisionID | awk '{ print $4 }'))
  CodecAddress=($(ioreg -rxn IOHDACodecDevice | grep IOHDACodecAddress | awk '{ print $4 }'))
  PinConfigurations=$(ioreg -rw 0 -p IODeviceTree -n HDEF | grep PinConfigurations | awk '{ print $3 }' | sed -e 's/.*<//' -e 's/>//')
  layout_id=$(ioreg -rw 0 -p IODeviceTree -n HDEF | grep layout-id | sed -e 's/.*<//' -e 's/>//')
  layout_id="0x${layout_id:6:2}${layout_id:4:2}${layout_id:2:2}${layout_id:0:2}"
  
  let Layout=$layout_id
  
  echo "Layout, hex:" $layout_id ", dec:" $Layout
  echo
  echo "PinConfigurations:"
  echo $PinConfigurations

  N=${#VendorID[@]}
  echo
  echo "Codecs Found:" $N
  N=$(($N-1))
  for i in $(seq 0 $N)
  do
    if [[ ${VendorID[$i]} == *"1002"* ]] || [[ ${VendorID[$i]} == *"10de"* ]] || [[ ${VendorID[$i]} == *"8086"* ]]
    then
      echo "HDMI:"
      HDAU=$i
      let CodecID=${VendorID[$HDAU]}
      echo $HDAU "CodecAddress:"${CodecAddress[$HDAU]}
      echo "VendorID:" ${VendorID[$HDAU]}
      echo "RevisionID:" ${RevisionID[$HDAU]}
      echo "CodecID:" $CodecID
      echo
    else
      echo "HDA:"
      HDEF=$i
      let CodecID=${VendorID[$HDEF]}
      echo $HDEF "CodecAddress:"${CodecAddress[$HDEF]}
      echo "VendorID:" ${VendorID[$HDEF]}
      echo "RevisionID:" ${RevisionID[$HDEF]}
      echo "CodecID:" $CodecID
      var1=${VendorID[$HDEF]}
      let Revisiond=${RevisionID[$HDEF]}
      echo "Revision(dec):"=$Revisiond
      id="0x${var1:6:4}"
      ven="0x${var1:2:4}"
      echo "Id="$id
      let idd=${id}
      echo "Id(dec)="$idd
      echo "Vendor="$ven
      let vend=${ven}
      echo "Vendor(dec)="$vend
      echo
    fi
  done
}

function archive_clover {

  _cleanup_dir "${YEKKI_HOME}/output"

  _is_empty_str $1 && _error "please input clover version, for example: ./yekki zip_clover 3899"
  [ ! -d "${YEKKI_HOME}/stage/EFI" ] && _error "please put EFI to ${YEKKI_HOME}/stage"

  rm -rf "${YEKKI_HOME}/stage/EFI/APPLE"
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/"config*.plist
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/ACPI/patched/"*
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/ACPI/origin/"*
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/doc"
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/OEM"
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/ROM"
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/kexts/"*/*
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/misc/"*
  rm -rf "${YEKKI_HOME}/stage/EFI/CLOVER/themes/${CLOVER_THEME}"

  cd "${YEKKI_HOME}/stage"

  zip -r -D -X -q "${YEKKI_HOME}/output/${CLOVER_PREFIX}${1}.zip" EFI
}

function archive_kexts {

  _cleanup_dir "${YEKKI_HOME}/output"

  if [ -d "${YEKKI_HOME}/stage/${YEKKI_OSX_VER}" ]
  then
    cd "${YEKKI_HOME}/stage"
    zip -r "${YEKKI_HOME}/output/${YEKKI_OSX_VER}.zip" "${YEKKI_OSX_VER}" -x "*.DS_Store" -x "__MACOSX"
  else
    _error "please put kexts to ${YEKKI_HOME}/stage/${YEKKI_OSX_VER}"
  fi
}

function ignore_updates {

  _ensure_admin

  
  for up in ${OSX_IGNORE_UPDATE_LIST[@]}; do
    softwareupdate --ignore $up
  done
}

function ntp_sync {

  _ensure_admin

  ntpdate -u $OSX_NTP_SERVER
}

function disable_hibernate {
  
  sudo pmset -a hibernatemode 0
  sudo rm -rf /private/var/vm/sleepimage
}

function cleanup {

  if [[ -n "${YEKKI_HOME}" ]]; then
    rm -Rf "${YEKKI_HOME}/output"
    rm -Rf "${YEKKI_HOME}/stage"
  else
    _info 'lost ${YEKKI_HOME} environment variable'
  fi
}

function scaffold {

  if _is_empty_str $1; then _error "usage: yekki scaffold [laptop series]"; fi

  if [ -d "${YEKKI_HOME}/laptop/$1" ]; then _error "the laptop series '$1' is already exist, please change to another one"; fi

  mkdir -p "${YEKKI_HOME}/laptop/${1}"/{codec,solution/clover/patched,solution/kexts,acpi/{origin/{linux,clover},patches}}

cat > "${YEKKI_HOME}/laptop/$1/default.properties" <<EOL
# the folloing is for sample purpose, please change it according your requirements

# laptp settings
LAPTOP_CPU_ARCH=
LAPTOP_CPU=
LAPTOP_GRAPHIC=
LAPTOP_CODEC=
LAPTOP_BRAND=
LAPTOP_MODEL=
LAPTOP_SERIES=
LAPTOP_BIOS_VER=
LAPTOP_EC_VER=

KEXT_MODE=Release
KEXT_LIST=()

ACPI_SOURCE=clover
ACPI_SSDT_LIST=()
ACPI_DSDT_PATCHE_LIST=()
ACPI_CUST_LIST=()

KB_ADB=()
KB_PS2=()

EOL
}

function uninstall {

  _cleanup_dir "${YEKKI_HOME}/acpi/patches"
  _cleanup_dir "${YEKKI_HOME}/clover/templates"
  _cleanup_dir "${YEKKI_HOME}/clover/drivers"
  
  rm -rf ~/Library/ssdtPRGen 
  rm -rf /usr/local/bin/{iasl,patchmatic,ioio}
  rm -rf "${YEKKI_HOME}/.yekki.installed"
  
  cleanup
  
  _info "$APP_NAME $APP_VER has been removed from your host."
}

function tools {

  _init
  
  for tool in ${TOOL_LIST[@]}
  do
    if _exists_in_array $tool "${TOOL_SUPPORTED_LIST[@]}"
    then
      _fetch_tool $tool
    else
      _error "tool $tool doesn't be supported."
    fi
  done 
  
  _unzip_all "${YEKKI_HOME}/stage" "${YEKKI_HOME}/output"
  
  _cleanup_zip "${YEKKI_HOME}/output"
}

function profile {
cat << EOF
$(version)

OSX Version: v${YEKKI_OSX_VER}
Clover Version: v${CLOVER_VER}
Laptop: ${LAPTOP_BRAND} ${LAPTOP_MODEL} ${LAPTOP_SERIES}

EOF
  exit 0
}

function help {
cat << EOF
usage: ./yekki [cmd] [arg]

commands:
install: install Hackintosh Laptop Workbench System

uninstall: uninstall  Hackintosh Laptop Workbench System

bootloader: make usb boot loader with clover

installer: make osx usb installer

kexts: prepare all kexts for some laptop model

acpi: apply patches and compile DSDT/SSDT

mount: mount EFI partition
  usage: ./yekki mount [VOLUME_NAME](for example: install_osx, default /)
umount: un-mount EFI partition

cleanup: cleanup stage & output working folders

scaffold: create a stub laptop model for testing

profile: print profile of Hackintosh Laptop Workbench System

clover: download clover pkg

disable_hibernate: disable hibernate model

ntp_sync: sync system time with remote ntp server

ignore_updates: ignore system updates

tools: download tool apps

version: show app version

help: print help and exit

EOF
  exit 0
}

function umount {

  _ensure_admin

  if [ -d /Volumes/EFI ]; then diskutil umount /Volumes/EFI; fi
}

function mount {

  _ensure_admin

  if [ "$1" == "" ]; then
      DestVolume=/
  else
      DestVolume="$1"
  fi
  DiskDevice=$(LC_ALL=C diskutil info "${DestVolume}" 2>/dev/null | sed -n 's/.*Part [oO]f Whole: *//p')
  if [ -z "${DiskDevice}" ]; then
      _error "can't find volume with the name ${DestVolume}"
  fi

  # Check if the disk is a GPT disk
  PartitionScheme=$(LC_ALL=C diskutil info "${DiskDevice}" 2>/dev/null | sed -nE 's/.*(Partition Type|Content \(IOContent\)): *//p')
  if [ "${PartitionScheme}" != "GUID_partition_scheme" ]; then
      _error "volume $DestVolume is not on GPT disk"
  fi

  # Get the index of the EFI partition
  EFIIndex=$(LC_ALL=C /usr/sbin/gpt -r show "/dev/${DiskDevice}" 2>/dev/null | awk 'toupper($7) == "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" {print $3; exit}')
  [ -z "${EFIIndex}" ] && EFIIndex=$(LC_ALL=C diskutil list "${DiskDevice}" 2>/dev/null | awk '$2 == "EFI" {print $1; exit}' | cut -d : -f 1)
  [ -z "${EFIIndex}" ] && EFIIndex=$(LC_ALL=C diskutil list "${DiskDevice}" 2>/dev/null | grep "EFI"|awk '{print $1}'|cut -d : -f 1)
  [ -z "${EFIIndex}" ] && EFIIndex=1 # if not found use the index 1

  # Define the EFIDevice
  EFIDevice="${DiskDevice}s${EFIIndex}"

  # Get the EFI mount point if the partition is currently mounted
  EFIMountPoint=$(LC_ALL=C diskutil info "${EFIDevice}" 2>/dev/null | sed -n 's/.*Mount Point: *//p')

  code=0
  if [ ! "${EFIMountPoint}" ]; then
      # try to mount the EFI partition
      EFIMountPoint="/Volumes/EFI"
      [ ! -d "${EFIMountPoint}" ] && mkdir -p "${EFIMountPoint}"
      diskutil mount -mountPoint "${EFIMountPoint}" /dev/${EFIDevice} >/dev/null 2>&1
      code=$?
  fi
  _info ${EFIMountPoint}
  return $code
}

function clover {

  [ $# -ne 1 ] && _error "please input clover version."
  
  _init
  local _CLOVER="${CLOVER_PREFIX}${1}"
  local _URL="https://sourceforge.net/projects/cloverefiboot/files/Installer/${_CLOVER}.zip/download"
  
  _download $_URL "${_CLOVER}.zip"
  if [ -f "${YEKKI_HOME}/stage/${_CLOVER}.zip" ]; then
    unzip -o "${YEKKI_HOME}/stage/${_CLOVER}.zip"
    mv "${YEKKI_HOME}/stage/"*.pkg "${YEKKI_HOME}/output"
  else
    _error "failed to download clover installer, ${_CLOVER} does not exist."
  fi
}

function fix_recovery {

  _ensure_admin

  diskutil mount /dev/${OSX_RECOVERY_HD}
  
  rm -rf "/Volumes/Recovery HD/com.apple.recovery.boot/prelinkedkernel"

  cp /System/Library/PrelinkedKernels/prelinkedkernel "/Volumes/Recovery HD/com.apple.recovery.boot/"

  touch "/Volumes/Recovery HD/com.apple.recovery.boot/prelinkedkernel"
}

function installer {

  _ensure_admin

  local _INST_APP=`_installer`
  local _CREATOR="/Applications/${_INST_APP}.app/Contents/Resources/createinstallmedia"
  local _VOLUME=install_macOS

  [ -d "/Volumes/${_INST_APP}" ] && _VOLUME=${_INST_APP}

  if [ -d "/Volumes/${_VOLUME}" ]; then
    if [ -f "${_CREATOR}" ]; then
      "${_CREATOR}" --volume  "/Volumes/${_VOLUME}" --applicationpath "/Applications/${_INST_APP}.app" --nointeraction
    else
      _error "no osx installer app, please get it from AppStore firstly."
    fi
  else
    _error "please make bootloader firstly. plug your usb device and run: sudo -E ./yekki bootloader [disknumber]"
  fi
}

function main {

  [ $# -eq 0 ] && help

  if [ -f "${YEKKI_HOME}/.yekki.installed" ]
  then
    [ $1 == install ] && _error "please uninstall or reinstall ${APP_NAME} ${APP_VER} firstly."
  else
    [[ $1 != *install ]] && _error 'please run: "./yekki install" firstly.'
  fi

  for c in ${APP_CMD_LIST[@]}; do
    if [ "${c}" = "${1}" ]; then
      if _exists_one "${YEKKI_HOME}/bin/cmd/${1}.sh"; then
        "${YEKKI_HOME}/bin/cmd/${1}.sh" $2
      else
        "${1}" "${2}"
      fi
      exit 0;
    fi
  done

  help
}