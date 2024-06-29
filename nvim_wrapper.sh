#!/bin/bash

# Define the virtual environment path
VENV_PATH=~/dotfiles/iterm2_venv

# Check if the virtual environment exists, create it if it does not
if [ ! -d "$VENV_PATH" ]; then
    python3 -m venv "$VENV_PATH"
    source "$VENV_PATH/bin/activate"
    pip install iterm2
else
    source "$VENV_PATH/bin/activate"
fi

# Switch to the nvim profile
python3 ~/dotfiles/switch_profile.py "nvim" "start" &

# Execute nvim
nvim "$@"

# Switch back to the default profile
python3 ~/dotfiles/switch_profile.py "Default" "end"

# Deactivate the virtual environment
deactivate
