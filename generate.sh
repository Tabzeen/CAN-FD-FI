#!/bin/bash
#
# Convenience wrapper: bootstrap PDM, install deps, and regenerate the register artifacts.
# Equivalent to a one-time `source setupPdm.sh && pdm install` followed by `pdm generate`.

NOCOLOR='\033[0m'
RED='\033[0;31m'

# Run from this script's directory so the relative paths line up.
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" || exit 1

source ./setupPdm.sh

pdm install -q

cmd="pdm generate"
echo -e "$cmd"
eval $cmd

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate register artifacts!${NOCOLOR}"
    exit 1
fi
