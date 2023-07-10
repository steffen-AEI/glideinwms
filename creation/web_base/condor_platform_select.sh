#!/bin/bash

# SPDX-FileCopyrightText: 2009 Fermi Research Alliance, LLC
# SPDX-License-Identifier: Apache-2.0

#
# Project:
#   glideinWMS
#
# File Version:
#
# Description:
#   This script will select the appropriate condor tarball
#   Must be listed in the file_list before the condor tarballs
#   as it turns on one of them
#

glidein_config="$1"
tmp_fname="${glidein_config}.$$.tmp"

# import add_config_line function
add_config_line_source=$(grep -m1 '^ADD_CONFIG_LINE_SOURCE ' "$glidein_config" | cut -d ' ' -f 2-)
# shellcheck source=./add_config_line.source
. "$add_config_line_source"

error_gen=$(gconfig_get ERROR_GEN_PATH "$glidein_config")

condor_vars_file=$(gconfig_get CONDOR_VARS_FILE "$glidein_config")

condor_os=$(gconfig_get CONDOR_OS "$glidein_config")
if [ -z "$condor_os" ]; then
    condor_os="default"
fi

findversion_redhat() {
  # content of /etc/redhat-release
  #Scientific Linux release 6.2 (Carbon)
  #Red Hat Enterprise Linux Server release 5.8 (Tikanga)
  #Scientific Linux SL release 5.5 (Boron)
  #CentOS release 4.2 (Final)
  #
  #Do we support FC:Fedora Core release 11 ... ?
  #
  # should I check that it is SL/RHEL/CentOS ?
  # no
  grep -q 'release 9.' /etc/redhat-release && condor_os='linux-rhel9,rhel9' && return
  grep -q 'CentOS Stream release 8' /etc/redhat-release && condor_os='linux-rhel8,rhel8' && return
  grep -q 'release 8.' /etc/redhat-release && condor_os='linux-rhel8,rhel8' && return
  grep -q 'release 7.' /etc/redhat-release && condor_os='linux-rhel7,rhel7' && return
  grep -q 'release 6.' /etc/redhat-release && condor_os='linux-rhel6,rhel6' && return
  grep -q 'release 5.' /etc/redhat-release && condor_os='linux-rhel5,rhel5' && return
}

findversion_debian() {
  #cat /etc/os-release
  #PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
  #NAME="Debian GNU/Linux"
  #VERSION_ID="11"
  #VERSION="11 (bullseye)"
  #VERSION_CODENAME=bullseye
  #ID=debian
  #HOME_URL="https://www.debian.org/"
  #SUPPORT_URL="https://www.debian.org/support"
  #BUG_REPORT_URL="https://bugs.debian.org/"
  #
  #NAME="Ubuntu"
  #VERSION="20.04.6 LTS (Focal Fossa)"
  #ID=ubuntu
  #ID_LIKE=debian
  #PRETTY_NAME="Ubuntu 20.04.6 LTS"
  #VERSION_ID="20.04"
  #HOME_URL="https://www.ubuntu.com/"
  #SUPPORT_URL="https://help.ubuntu.com/"
  #BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
  #PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
  #VERSION_CODENAME=focal
  #UBUNTU_CODENAME=focal

  # source /etc/os-release instead of parsing lines
  dist_id=$(. /etc/os-release; echo ${ID})
  dist_rel=$(. /etc/os-release; echo ${VERSION_ID})
  if [[ ${dist_id} == "debian" ]]; then
    condor_os="linux-${dist_id}${dist_rel}"
  elif [[ ${dist_id} == "ubuntu" ]]; then
    condor_os="linux-${dist_id}${dist_rel:0:2}"
  fi
}

if [[ "$condor_os" == "auto" ]]; then
    if [ -f "/etc/redhat-release" ]; then
    # rhel, now determine the version
        # default RHEL
        condor_os='linux-rhel7,rhel7'
        findversion_redhat
	#strings /lib/libc.so.6  |grep -q GLIBC_2.4
	#if [ $? -ne 0 ]; then
	#    # pre-RHEL5
	#    condor_os='linux-rhel3'
	#else
	#    # I am not aware of anything newer right now
	#    condor_os='linux-rhel5'
	#fi
    elif [ -f "/etc/os-release" ]; then
    # debian/ubuntu, now determine the version
        # default debian
        condor_os='linux-debian10'
        findversion_debian
#    elif [ -f "/etc/debian_version" ]; then
#    # debian, now determine the version
#    grep -q '^5' /etc/debian_version
#    if [ $? -ne 0 ]; then
#        # pre-Debian 5
#	     condor_os='linux-debian40'
#	     else
#	         # I am not aware of anything newer right now
#		     condor_os='linux-debian50'
#		     fi

    else
        #echo "Not a RHEL not Debian compatible system. Autodetect not supported"  1>&2
        STR="Not a RHEL not Debian compatible system. Autodetect not supported"
        "$error_gen" -error "condor_platform_select.sh" "Config" "$STR" "SupportAutodetect" "False" "OSType" "Unknown"
        exit 1
    fi

    # Dry run for the generic solution that uses /etc/os-release . Source is
    # https://github.com/htcondor/htcondor/blob/7ecce4e5c16072162903844eef817b11c6e9b960/src/condor_scripts/condor_remote_cluster#L284-L310
    # Ticket: https://github.com/glideinWMS/glideinwms/issues/97
    echo "###OS RELEASE INFORMATION###"
    if [ -f "/etc/os-release" ]; then
      os_release=`cat /etc/os-release`
      dist_id=`echo "$os_release" | awk -F '=' '/^ID=/ {print $2}'`
      dist_id_like=`echo "$os_release" | awk -F '=' '/^ID_LIKE=/ {print $2}'`
      ver=`echo "$os_release" | awk -F '=' '/^VERSION_ID=/ {print $2}' | tr -d '"'`
      major_ver="${ver%%.*}"

      if [[ $dist_id_like =~ (rhel|centos|fedora) ]]; then
        echo "linux-rhel${major_ver},rhel${major_ver}"
      else
        case "$dist_id" in
            debian)
                echo "linux-debian${major_ver}" ;;
            ubuntu)
                echo "linux-ubuntu${major_ver}" ;;
            *)
                echo "Unknown dist id"
        esac
      fi
    else
      echo "/etc/os-release does not exists."
    fi
    echo "$condor_os"
    echo "###END RELEASE INFORMATION###"
fi

condor_arch=$(gconfig_get CONDOR_ARCH "$glidein_config")
if [ -z "$condor_arch" ]; then
    condor_arch="default"
fi

if [[ "$condor_arch" == "auto" ]]; then
    condor_arch=$(uname -m)
    if [[ "$condor_arch" == "x86_64" ]]; then
        condor_arch="x86_64,x86"
    elif [[ "$condor_arch" == "i386" || "$condor_arch" == "i486" || "$condor_arch" == "i586" || "$condor_arch" == "i686" ]]; then
        condor_arch="x86"
    elif [[ "$condor_arch" == "ppc64le" ]]; then
        condor_arch="ppc64le"
    elif [[ "$condor_arch" == "ppc64" ]]; then
        condor_arch="ppc64"
    elif [[ "$condor_arch" == "aarch64" ]]; then
        condor_arch="aarch64"
    else
        #echo "Not a x86 or PPC compatible system. Autodetect not supported"  1>&2
        STR="Not a x86, ARM or PPC compatible system. Autodetect not supported"
        "$error_gen" -error "condor_platform_select.sh" "Config" "$STR" "SupportAutodetect" "False" "ArchType" "Unknown"
        exit 1
    fi
fi

condor_version=$(gconfig_get CONDOR_VERSION "$glidein_config")
if [ -z "$condor_version" ]; then
    condor_version="default"
fi

condor_platform_check=""
for version_el in $(echo "$condor_version" | tr ',' ' '); do
  if [ -z "$condor_platform_check" ]; then
    # not yet found, try to find it
    for os_el in $(echo "$condor_os" | tr ',' ' '); do
      if [ -z "$condor_platform_check" ]; then
        # not yet found, try to find it
        for arch_el in $(echo "$condor_arch" | tr ',' ' '); do
          if [ -z "$condor_platform_check" ]; then
            # not yet found, try to find it
            # combine the three
            condor_platform="${version_el}-${os_el}-${arch_el}"
            condor_platform_id="CONDOR_PLATFORM_$condor_platform"

            condor_platform_check=$(gconfig_get "$condor_platform_id" "$glidein_config")
          fi
        done
      fi
    done
  fi
done

if [ -z "$condor_platform_check" ]; then
    # uhm... all tries failed
    STR="Cannot find a supported platform\n"
    STR+="CONDOR_VERSION '$condor_version'\n"
    STR+="CONDOR_OS      '$condor_os'\n"
    STR+="CONDOR_ARCH    '$condor_arch'\n"
    STR+="Quitting"
    STR1=`echo -e "$STR"`
    "$error_gen" -error "condor_platform_select.sh" "Config" "$STR1" "ReqVersion" "$condor_version" "ReqOS" "$condor_os" "ReqArch" "$condor_arch"
    exit 1
fi

# this will enable this particular Condor version to be downloaded and unpacked
gconfig_add "$condor_platform_id" "1"

"$error_gen" -ok "condor_platform_select.sh" "Condor_platform" "${version_el}-${os_el}-${arch_el}"

exit 0
