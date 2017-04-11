#!/usr/bin/env bash

source "$YEKKI_HOME/bin/include.sh"
        
########## acpi command ##########

#arg1:target arg2:patch
function _apply_patch_if_exists {

  _op_if_exists $1 $2 "patchmatic $1 $2 $1"
}

function _patch_head {

  echo \#$(date) > $1

  [ ! -f $1 ] &&  _error "fail to initialize file $1."
}

function _decompile {

  local _NATIVE_ACPI_DIR="${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/acpi/origin/${ACPI_SOURCE}"

  ! ( _is_empty_str $LAPTOP_BIOS_VER ) && _NATIVE_ACPI_DIR="${_NATIVE_ACPI_DIR}/${LAPTOP_BIOS_VER}"

  [ ! -d "${_NATIVE_ACPI_DIR}" ] && _error "directory ${_NATIVE_ACPI_DIR} isn't exist."

  for f in ${ACPI_SSDT_LIST[@]}; do
    
    local _SSDT_NAME=${f}.aml

    [ "${ACPI_SOURCE}" = "linux" ] && _SSDT_NAME=SSDT${f#SSDT-}
    
    _cp_if_exists "${_NATIVE_ACPI_DIR}/${_SSDT_NAME}" "${YEKKI_HOME}/stage/${f}"
 
  done

  local _DSDT_NAME=DSDT.aml
  
  if [ "${ACPI_SOURCE}" = "linux" ]; then DSDT_NAME=DSDT; fi

  _cp_if_exists "${_NATIVE_ACPI_DIR}/${_DSDT_NAME}" "${YEKKI_HOME}/stage/"
  
  _cp_if_exists "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/acpi/patches/refs.txt" "${YEKKI_HOME}/stage"
   
  iasl -da -dl "${YEKKI_HOME}/stage/"*
  
  [[ -f "${YEKKI_HOME}/stage/"*.dsl ]] &&  _error 'failed to decompile acpi files.'
}

function _apply_dsdt_patches {

  _patch_head "${YEKKI_HOME}/stage/DSDT_PATCHES.txt"
  
  $YEKKI_DEBUG && ACPI_DSDT_PATCHE_LIST+=(${ACPI_DEBUG_LIST[@]})
  
  for patch in ${ACPI_DSDT_PATCHE_LIST[@]}; do
    _append_if_exists "${YEKKI_HOME}/acpi/patches/${patch}.txt" "${YEKKI_HOME}/stage/DSDT_PATCHES.txt"
    _append_if_exists "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/acpi/patches/${patch}.txt" "${YEKKI_HOME}/stage/DSDT_PATCHES.txt"
  done
  
  _apply_patch_if_exists "${YEKKI_HOME}/stage/DSDT.dsl" "${YEKKI_HOME}/stage/DSDT_PATCHES.txt"
}

function _apply_ssdt_patches {

  # it's dynamic check SSDT-(1..20) patches
  for i in {0..20}; do
    local _SSDT=SSDT_$i
    local _SSDT_VALUE=ACPI_$_SSDT

    if [ -n "${!_SSDT_VALUE}" ]; then
      local _PATCHES="$_SSDT_VALUE[@]"

      _patch_head "${YEKKI_HOME}/stage/${_SSDT}_PATCHES.txt"

      for patch in "${!_PATCHES}"; do
        _append_if_exists "${YEKKI_HOME}/acpi/patches/${patch}.txt" "${YEKKI_HOME}/stage/${_SSDT}_PATCHES.txt"
        _append_if_exists "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/acpi/patches/${patch}.txt" "${YEKKI_HOME}/stage/${_SSDT}_PATCHES.txt"
      done
      
      _apply_patch_if_exists "${YEKKI_HOME}/stage/SSDT-${i}.dsl" "${YEKKI_HOME}/stage/${_SSDT}_PATCHES.txt"
    fi
  done
}

function _post_check {

  local _SSDTS=("${ACPI_SSDT_LIST[@]}" DSDT "${ACPI_CUST_LIST[@]}")

  [ "${YEKKI_LAPTOP_SERIES}" = "${YEKKI_LAPTOP_WORKING}" ] && _SSDTS+=(SSDT)

  for f in ${_SSDTS[@]}; do
    ! _exists_one "${YEKKI_HOME}/output/${f}.aml" && _error "failed to patch & compile $f"
  done
}

function _apply_ssdtPRGen {
  echo n|~/Library/ssdtPRGen/ssdtPRGen.sh

  _cp_if_exists ~/Library/ssdtPRGen/ssdt.aml "${YEKKI_HOME}/output/SSDT.aml"
}

function _add_cust_dsl {

  for f in ${ACPI_CUST_LIST[@]}; do 
    _cp_if_exists "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/acpi/patches/${f}.dsl" "${YEKKI_HOME}/stage"
  done
}

function _compile {

  local _SSDTS=(DSDT "${ACPI_SSDT_LIST[@]}" "${ACPI_CUST_LIST[@]}")
  for f in ${_SSDTS[@]}; do iasl -vr -w1 -p "${YEKKI_HOME}/output/${f}.aml" "${YEKKI_HOME}/stage/${f}.dsl"; done
}

function _add_cust_aml {

  for f in ${ACPI_CUST_LIST[@]}; do 
    _cp_if_exists "${YEKKI_HOME}/laptop/${YEKKI_LAPTOP_SERIES}/acpi/patches/${f}.aml" "${YEKKI_HOME}/output"
  done
}

function _exec {
  _init

  _decompile
  _apply_dsdt_patches
  _apply_ssdt_patches
  _add_cust_dsl
  _compile
  _add_cust_aml
  
  [ "${YEKKI_LAPTOP_SERIES}" = "${YEKKI_LAPTOP_WORKBENCH}" ] && _apply_ssdtPRGen || _info "your working laptop isn't target laptop, you have to generate SSDT.aml manually"
  
  _post_check
  _info Done.
}

_exec
