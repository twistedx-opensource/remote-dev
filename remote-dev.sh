#!/usr/bin/env bash

# Copyright 2022 Jason Scheunemann

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

SCRIPT_FULL_PATH="$(realpath "${0}")"
SCRIPT_DIR_PATH="$(dirname ${SCRIPT_FULL_PATH})"
SCRIPT_NAME="$(basename "${SCRIPT_FULL_PATH%.*}")"
SCRIPT_VERSION="0.1.0"

if [ $(command -v fswatch | wc -l) -eq 0 ]; then
    echo "Please install the fswatch program."
    echo "See http://emcrisostomo.github.io/fswatch/"
    exit 1
fi

function usage() {
    echo "Usage: ${SCRIPT_NAME} <watch-dir> <target> [OPTIONS...]"
    echo "  watch-dir:            path to a local directory to watch"
    echo "  target:               an scp target specification, e.g."
    echo "                        user@host.domain:/var/tmp"
    echo "  --host-ip ip-address: optional ip address for unsupported"
    echo "                        operating systems or VPNs"
    echo "  --check-host-key:     Enforce host key checking"
    echo "  -y, --yes:            Assume yes for all prompts"
}

VERSION=$(cat <<-END
${SCRIPT_NAME} v${SCRIPT_VERSION}
Copyright (C) $(date +'%Y') Jason Scheunemann
END
)


function version() {
    echo -e "${VERSION}"
}

if [[ "${1}" =~ "-v"|"--version" ]]; then
    version
    exit 0
fi

if [[ ! -d "${1}" ]]; then
    usage
    exit 0
fi

if [ -z "${2}" ]; then
    usage
    exit 2
fi

WATCH_DIR="${1}"
SCP_TARGET="${2}"
FULL_DIR_PATH="$(realpath ${WATCH_DIR})"
SUB_DIRECTORY="$(basename ${WATCH_DIR})"
PARENT_DIRECTORY="$(dirname ${FULL_DIR_PATH})/"
SCRIPT_NAME=$(basename $0)
DESTINATION="~/$(echo ${SCP_TARGET} | cut -d: -f2)/"
DESTINATION_PREFIX=$(echo ${SCP_TARGET} | cut -d: -f1)
DESTINATION_SUFFIX=$(echo ${SCP_TARGET} | cut -d: -f2)
RED_TEXT="\033[0;31m"
GREEN_TEXT="\033[0;32m"
NORMAL_TEXT="\033[0m"
HOST_KEY_CHECKING="-o StrictHostKeyChecking=no"

shift
shift

POSITIONAL=()
while [[ ${#} -gt 0 ]]; do
    key="${1}"

    case ${key} in
        -h | --help)
            usage
            exit 0;;
        -v | --version)
            version
            exit 0;;
        -y | --yes)
            ASSUME_YES=1
            shift;;
        --host-ip)
            HOST_IP="${2}"
            shift
            shift;;
        --check-host-key)
            unset HOST_KEY_CHECKING
            shift;;
        *)
            printf "Unknown option ${1}, "
            help
            exit 1;
   esac
done

if [ -z "${HOST_IP}" ]; then
    if [[ $(uname -s) = 'Linux' ]]; then
        echo "Operation on Linux has not been verified. Use the --ip-address fommand line arguement, exiting now."
        exit 1
        HOST_IP=$(cat /proc/net/dev | grep : | sort -k 2,2 | head -1 | cut -d: -f1 | awk '{print $1}')
    elif [[ $(uname -s) = 'Darwin' ]]; then
        HOST_IP=$(ifconfig -l | xargs -n1 ipconfig getifaddr)
    else
        echo "Your operating system is not supported"
        exit 3
    fi
fi

if [[ $(echo ${SCP_TARGET} | cut -d: -f2) = '' ]]; then
    DESTINATION="~/"
elif [[ ${DESTINATION_SUFFIX::1} == "/" ]]; then
    DESTINATION=${DESTINATION_SUFFIX}
fi

upload() {
    FILE_NAME=${1}

    if [[ $(echo ${FILE_NAME} | grep '/.git/' | wc -l) -eq 0 ]]; then
        # Hackery to get around the differences between relative and absolute paths
        PREFIX=''

        if [[ ! $(echo ${SCP_TARGET} | cut -d: -f2) = '' ]]; then
            PREFIX="/"
        fi

        FILE_OP_LABEL="[INFO] Syncing $(basename ${FILE_NAME}) => ${SCP_TARGET%/}${PREFIX}$(echo ${FILE_NAME} | sed -e "s|${PARENT_DIRECTORY}||g") "

        scp "${FILE_NAME}" "${SCP_TARGET%/}${PREFIX}$(echo ${FILE_NAME} | sed -e "s|${PARENT_DIRECTORY}||g")" > /dev/null 2>&1
        [ ${?} -eq 0 ] && printf "${FILE_OP_LABEL} [ ${GREEN_TEXT}✓${NORMAL_TEXT} ]\n" || printf "${FILE_OP_LABEL} [ ${RED_TEXT}✗${NORMAL_TEXT} ]\n"
    fi
}

function setup() {
    echo "Verifying setup, please be patient..."

    if [ $(ssh ${HOST_KEY_CHECKING} ${DESTINATION_PREFIX} "ssh ${HOST_KEY_CHECKING} $(whoami)@${HOST_IP} echo \\$(realpath ${WATCH_DIR})" 2> /dev/null | grep -wc $(realpath ${WATCH_DIR})) -eq 0 ]; then
        if [ $(ssh ${DESTINATION_PREFIX} "[ -d \$(echo ${DESTINATION} | sed 's/~/\\\${HOME}/') ] && echo 1" | wc -l) -eq 0 ]; then
            if [ -z "${ASSUME_YES}" ]; then
                read -p "The destination directory \"${DESTINATION}\" does not exist, would you like to fix this issue now [Y/n]? " CONFIRM
            fi

            if [ ! -z "${ASSUME_YES}" ] || [[ ! "${CONFIRM}" =~ [Nn](o)? ]]; then
                echo "[INFO] Creating ${DESTINATION} on ${DESTINATION_PREFIX}"
                ssh ${DESTINATION_PREFIX} "mkdir -p ${DESTINATION}"
            fi

            if [ $(ssh ${DESTINATION_PREFIX} "[ -d \$(echo ${DESTINATION} | sed 's/~/\\\${HOME}/') ] && echo 1" | wc -l) -eq 0 ]; then
                echo "You must create \"${DESTINATION}\" on the remote computer before continuing, exiting now."
                exit 1
            fi
        fi

        if [ $(ssh ${DESTINATION_PREFIX} "[ -f \${HOME}/.ssh/id_rsa.* ] && echo 1" | wc -l) -eq 0 ]; then
            if [ -z "${ASSUME_YES}" ]; then
                read -p "User SSH keys do not exist on the remote host (${DESTINATION_PREFIX}), would you like to fix this issue now [Y/n]? " CONFIRM
            fi

            if [ ! -z "${ASSUME_YES}" ] || [[ ! "${CONFIRM}" =~ [Nn](o)? ]]; then
                echo "[INFO] Generating user SSH keys on ${DESTINATION_PREFIX}"
                ssh ${DESTINATION_PREFIX} "ssh-keygen -t rsa -q -f \"\${HOME}/.ssh/id_rsa\" -N \"\""
            else
                echo "SSH keys must be generated on the destination server before continuing, exiting now."
                exit 1
            fi
        fi

        SSH_CERT=$(ssh ${DESTINATION_PREFIX} "cat \${HOME}/.ssh/id_rsa.pub")

        if [ $(grep -wc "${SSH_CERT}" ~/.ssh/authorized_keys) -eq 0 ]; then
            if [ -z "${ASSUME_YES}" ]; then
                read -p "User SSH keys from ${DESTINATION_PREFIX} not present in this host's ${HOME}/.ssh/authorized_keys file, would you like to fix this issue now [Y/n]? "  CONFIRM
            fi

            if [ ! -z "${ASSUME_YES}" ] || [[ ! "${CONFIRM}" =~ [Nn](o)? ]]; then
                echo "[INFO] Adding the user's SSH keys from ${DESTINATION_PREFIX} to this host's ${HOME}/.ssh/authorized_keys file"
                echo "${SSH_CERT}" >> ~/.ssh/authorized_keys
            else
                echo "User SSH keys must be added to this host's ${HOME}/.ssh/authorized_keys file before continuing, exiting now."
                exit 1
            fi
        fi

        if [ $(ssh ${HOST_KEY_CHECKING} ${DESTINATION_PREFIX} "ssh ${HOST_KEY_CHECKING} $(whoami)@${HOST_IP} echo \\$(realpath ${WATCH_DIR})" 2> /dev/null | grep -wc $(realpath ${WATCH_DIR})) -eq 0 ]; then
            echo "Error during initial configuration"
            exit 1
        fi
    fi

    if [ $(ssh ${HOST_KEY_CHECKING} ${DESTINATION_PREFIX} "ssh ${HOST_KEY_CHECKING} $(whoami)@${HOST_IP} echo \\$(realpath ${WATCH_DIR})" 2> /dev/null | grep -wc $(realpath ${WATCH_DIR})) -eq 0 ]; then
        echo "You may be on an unexected network, add your host's IP address as the third command line argument and run again, exiting now"
    fi

}

setup

if [ $(ssh ${DESTINATION_PREFIX} "[ -d \$(echo ${DESTINATION} | sed 's/~/\\\${HOME}/') ] && echo 1" | wc -l) -eq 0 ]; then
    if [ -z "${ASSUME_YES}" ]; then
        read -p "The destination directory \"${DESTINATION}\" does not exist, would you like to fix this issue now [Y/n]? " CONFIRM
    fi

    if [ ! -z "${ASSUME_YES}" ] || [[ ! "${CONFIRM}" =~ [Nn](o)? ]]; then
        echo "[INFO] Creating ${DESTINATION} on ${DESTINATION_PREFIX}"
        ssh ${DESTINATION_PREFIX} "mkdir -p ${DESTINATION}"
    fi

    if [ $(ssh ${DESTINATION_PREFIX} "[ -d \$(echo ${DESTINATION} | sed 's/~/\\\${HOME}/') ] && echo 1" | wc -l) -eq 0 ]; then
        echo "You must create \"${DESTINATION}\" on the remote computer before continuing, exiting now."
        exit 1
    fi
fi

function cleanup() {
    echo ""
    echo "Exiting..."
    exit 0
}

trap cleanup SIGINT

echo
echo "watching: ${FULL_DIR_PATH}"
echo "target:   ${SCP_TARGET}"
echo ""
echo "[INFO] Syncing repository to ${DESTINATION_PREFIX}, please be patient..."
ssh ${DESTINATION_PREFIX} "ssh $(whoami)@${HOST_IP} \"tar --exclude=${WATCH_DIR}/.git --no-xattrs -cC ${PARENT_DIRECTORY} ${SUB_DIRECTORY}\" | tar -xC ${DESTINATION}" 2>&1 | grep -v 'SCHILY'
echo "[INFO] Repository sync complete"
echo
echo "Note: Press [ctrl + c] to quit"
echo

fswatch -e "${WATCH_DIR}/.git" -e ${0} ${WATCH_DIR} | while read f; do upload "$f"; done
