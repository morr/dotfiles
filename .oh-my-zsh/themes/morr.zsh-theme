# Based on ys theme

# Get the current ruby version in use with RVM:
if [ -e ~/.rvm/bin/rvm-prompt ]; then
  local ruby_info="%{$fg[white]%}rvm:%{$fg[blue]%}\$(~/.rvm/bin/rvm-prompt s i v g)%{$reset_color%} "
else
  if which rbenv &> /dev/null; then
    local ruby_info="%{$fg[white]%}rbenv:%{$fg[blue]%}\$(rbenv version | sed -e 's/ (set.*$//')%{$reset_color%} "
  fi
fi

# Git info
local git_info='$(git_prompt_info)'
# ZSH_THEME_GIT_PROMPT_PREFIX="${YS_VCS_PROMPT_PREFIX1}git${YS_VCS_PROMPT_PREFIX2}"
# ZSH_THEME_GIT_PROMPT_SUFFIX="$YS_VCS_PROMPT_SUFFIX"
# ZSH_THEME_GIT_PROMPT_DIRTY="$YS_VCS_PROMPT_DIRTY"
# ZSH_THEME_GIT_PROMPT_CLEAN="$YS_VCS_PROMPT_CLEAN"

function git_commits_ahead () {
  if __git_prompt_git rev-parse --git-dir &> /dev/null
  then
    local commits="$(__git_prompt_git rev-list --count @{upstream}..HEAD 2>/dev/null)"
    if [[ -n "$commits" && "$commits" != 0 ]]
    then
      echo "$ZSH_THEME_GIT_COMMITS_AHEAD_PREFIX$ZSH_THEME_GIT_COMMITS_AHEAD_SYMBOL$ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX"
      # echo "$ZSH_THEME_GIT_COMMITS_AHEAD_PREFIX$commits$ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX"
    fi
  fi
}

function git_prompt_info () {
  local ref
  if [[ "$(__git_prompt_git config --get oh-my-zsh.hide-status 2>/dev/null)" != "1" ]]
  then
    ref=$(__git_prompt_git symbolic-ref HEAD 2> /dev/null)  || ref=$(__git_prompt_git rev-parse --short HEAD 2> /dev/null)  || return 0
    echo "$ZSH_THEME_GIT_PROMPT_PREFIX${ref#refs/heads/}$(parse_git_dirty)$(git_commits_ahead)$ZSH_THEME_GIT_PROMPT_SUFFIX"
  fi
}

ZSH_THEME_GIT_COMMITS_AHEAD_PREFIX="$FG[200]"
ZSH_THEME_GIT_COMMITS_AHEAD_SYMBOL="ᛋ"
ZSH_THEME_GIT_COMMITS_AHEAD_SUFFIX="%{$reset_color%}"

ZSH_THEME_GIT_PROMPT_PREFIX="$FG[116] ("
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_DIRTY="$FG[214]*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="$FG[116])%{$reset_color%}"

# local shell_level=" %{$fg[white]%}L:%{$fg[magenta]%}%L"
local shell_level=""
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
${git_info}\
 \
%{$FG[248]%}[%*] \
$shell_level
%{$terminfo[bold]$fg[red]%}$ %{$reset_color%}"
# %{$fg[white]%}L:%{$fg[magenta]%}%L %{$fg[white]%}C:%{$fg[magenta]%}$exit_code
# %{$fg[magenta]%}tty:%l L:%L N:%i C:$exit_code

RPROMPT="$return_code"
