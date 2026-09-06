# NOTE
# There is a program called PDM from Xilinx (power distribution manager), which is in the PATH if
# the Xilinx environment is loaded.
# Therefore we don't check for a pre-existing `pdm` on the PATH, but install our own from scratch
# into a local .local-pdm/ directory. It only takes a few seconds.

# check if the file pdm exists at ${PWD}/.local-pdm/bin
if [ -f "${PWD}/.local-pdm/bin/pdm" ]; then
    echo "Using existing pdm installation at ${PWD}/.local-pdm/bin/pdm"
else
    echo "Installing pdm to ${PWD}/.local-pdm/bin"
    curl -sSL https://pdm-project.org/install-pdm.py | python3 - --path .local-pdm
fi

# prepending to path
export PATH=${PWD}/.local-pdm/bin:$PATH
echo "Using pdm: $(command -v pdm)"
