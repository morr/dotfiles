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

# Function to get the current window bounds
get_window_bounds() {
    osascript -e 'tell application "iTerm2" to get bounds of current window'
}

# Function to set the window bounds
set_window_bounds() {
    local bounds=$1
    osascript -e "tell application \"iTerm2\" to set bounds of current window to {$bounds}"
}

# Get the current window bounds
initial_bounds=$(get_window_bounds | awk -F", " '{print $1","$2","$3","$4}')
# Switch to the nvim profile
python3 ~/dotfiles/switch_profile.py "nvim" "start" &
wait %1
# Set the window bounds to the initial bounds after switching to nvim profile
set_window_bounds "$initial_bounds"

# Execute nvim
nvim "$@"

# Get the current window bounds
initial_bounds=$(get_window_bounds | awk -F", " '{print $1","$2","$3","$4}')
# Switch back to the default profile
python3 ~/dotfiles/switch_profile.py "Default" "end" &
wait %1

# Restore the initial window bounds after switching back to default profile
set_window_bounds "$initial_bounds"

# Deactivate the virtual environment
deactivate
