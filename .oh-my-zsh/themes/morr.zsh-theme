# Based on ys theme

# Get the current ruby version in use with RVM:
if [ -e ~/.rvm/bin/rvm-prompt ]; then
  local ruby_info="%{$fg[white]%}rvm:%{$fg[blue]%}\$(~/.rvm/bin/rvm-prompt s i v g)%{$reset_color%} "
else
  if which rbenv &> /dev/null; then
    local ruby_info="%{$fg[white]%}rbenv:%{$fg[blue]%}\$(rbenv version | sed -e 's/ (set.*$//')%{$reset_color%} "
  fi
fi

# VCS
YS_VCS_PROMPT_PREFIX1=" %{$fg[white]%}on%{$reset_color%} "
YS_VCS_PROMPT_PREFIX2=":%{$fg[cyan]%}"
YS_VCS_PROMPT_SUFFIX="%{$reset_color%}"
YS_VCS_PROMPT_DIRTY=" %{$fg[red]%}x"
YS_VCS_PROMPT_CLEAN=" %{$fg[green]%}o"

# Git info
local git_info='$(git_prompt_info)'
ZSH_THEME_GIT_PROMPT_PREFIX="${YS_VCS_PROMPT_PREFIX1}git${YS_VCS_PROMPT_PREFIX2}"
ZSH_THEME_GIT_PROMPT_SUFFIX="$YS_VCS_PROMPT_SUFFIX"
ZSH_THEME_GIT_PROMPT_DIRTY="$YS_VCS_PROMPT_DIRTY"
ZSH_THEME_GIT_PROMPT_CLEAN="$YS_VCS_PROMPT_CLEAN"

# HG info
local hg_info='$(ys_hg_prompt_info)'
ys_hg_prompt_info() {
	# make sure this is a hg dir
	if [ -d '.hg' ]; then
		echo -n "${YS_VCS_PROMPT_PREFIX1}hg${YS_VCS_PROMPT_PREFIX2}"
		echo -n $(hg branch 2>/dev/null)
		if [ -n "$(hg status 2>/dev/null)" ]; then
			echo -n "$YS_VCS_PROMPT_DIRTY"
		else
			echo -n "$YS_VCS_PROMPT_CLEAN"
		fi
		echo -n "$YS_VCS_PROMPT_SUFFIX"
	fi
}

local shell_level=" %{$fg[white]%}L:%{$fg[magenta]%}%L"
local return_code="%(?..%{$fg[red]%}%? ↵)%{$reset_color%}"

# Prompt format:
#
# PRIVILEGES USER @ MACHINE in DIRECTORY on git:BRANCH STATE rvm: RUBY VERSION [TIME] tty:$TTY L:$SHELL_LEVEL N:LINE_NUM C:LAST_EXIT_CODE
# $ COMMAND
#
# For example:
#
# % ys @ ys-mbp in ~/.oh-my-zsh on git:master x [21:47:42] tty:s000 L:1 N:12 C:0
# $
PROMPT="
%{$terminfo[bold]$fg[blue]%}#%{$reset_color%} \
%(#,%{$bg[yellow]%}%{$fg[black]%}%n%{$reset_color%},%{$fg[cyan]%}%n) \
%{$fg[white]%}@ \
%{$fg[green]%}%m \
${ruby_info}\
%{$fg[white]%}in \
%{$terminfo[bold]$fg[yellow]%}%~%{$reset_color%}\
${hg_info}\
${git_info}\
 \
%{$fg[white]%}[%*] \
$shell_level
%{$terminfo[bold]$fg[red]%}$ %{$reset_color%}"
RPROMPT='${return_code}'
# %{$fg[white]%}L:%{$fg[magenta]%}%L %{$fg[white]%}C:%{$fg[magenta]%}$exit_code
# %{$fg[magenta]%}tty:%l L:%L N:%i C:$exit_code
