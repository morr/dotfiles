# HOWTO
# install zsh: sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# fish syntax highlight: cd ~/.oh-my-zsh && git clone git://github.com/zsh-users/zsh-syntax-highlighting.git

#-------------------------------------------------------------------------------
# zsh basic configuration
#-------------------------------------------------------------------------------
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="../../dotfiles/.oh-my-zsh/themes/morr"
# ZSH_THEME="ys"

CASE_SENSITIVE="true"

# Uncomment following line if you want to disable autosetting terminal title. # DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

plugins=(rails ruby bundler capistrano gem osx npm rbenv ssh-agent rake brew \
  command-not-found compleat cp history history-substring-search \
  git-remote-branch git git-flow git-extras github pow npm yarn docker)

HISTSIZE=100000
HISTFILESIZE=200000
TERM="xterm-256color"

export EDITOR="mvim"
# some shit to enable erlang history
export ERL_AFLAGS="-kernel shell_history enabled"

# oh-my-zsh
source $ZSH/oh-my-zsh.sh
# fish syntax highlight
#source ~/.oh-my-zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# fix lag on paste text into console
unset zle_bracketed_paste

#-------------------------------------------------------------------------------
# configs projects
#-------------------------------------------------------------------------------
alias dotfiles="cd ~/dotfiles/"
alias vimfiles="cd ~/.vim"

#-------------------------------------------------------------------------------
# work projects
#-------------------------------------------------------------------------------
alias chef-erebor="cd ~/develop/work/chef-erebor"
alias erebor="cd ~/develop/work/erebor"
alias e="erebor"

alias chef-bidon="cd ~/develop/work/chef-bidon"
alias bidon="cd ~/develop/work/bidon"
alias b="bidon"

alias chef-grin="cd ~/develop/work/chef-grin"
alias as="cd ~/develop/work/amazing-supplies/"

alias grin="cd ~/develop/work/grin/"

#-------------------------------------------------------------------------------
# home projects
#-------------------------------------------------------------------------------
alias chef-shiki="cd ~/develop/chef-shiki"
alias shiki="cd ~/develop/shikimori"
alias mal_parser="cd ~/develop/mal_parser"
alias neko="cd ~/develop/neko-achievements"

alias mount_hetzner='mkdir -p /Volumes/hetzner; sshfs shiki:/ /Volumes/hetzner'

# shikimori sync commands
sync_shikimori_images() {
  local local_path=~/shikimori.org/images/
  local shiki_path=/home/apps/shikimori/production/shared/public/system/

  for dir in $(ssh shiki ls $shiki_path)
  do
    if [[ "$dir" == "image" || "$dir" == "user_image" || "$dir" == "screenshot" || "$dir" == "cosplay_image" || "$dir" == "webm_video" ]]; then
      echo "skipping $dir"
      continue
    else
      echo "processing $dir ..."
      rsync -urv -e ssh shiki:$shiki_path$dir $local_path
    fi
  done
}
alias shikisync=sync_shikimori_images

backup_shikimori_images() {
  local local_path=/Volumes/HDD/shikimori/
  local shiki_path=/home/apps/shikimori/production/shared/public/system/

  for dir in $(ssh shiki ls $shiki_path)
  do
    echo "processing $dir ..."
    rsync -urv -e ssh shiki:$shiki_path$dir $local_path
  done
}
alias shikibackup=backup_shikimori_images

#-------------------------------------------------------------------------------
# common aliases
#-------------------------------------------------------------------------------
alias psf='ps aux|grep $1'
alias ll='ls -lAh'

#-------------------------------------------------------------------------------
# rails aliases
#-------------------------------------------------------------------------------
alias r='rails'
alias log='tail -f log/development.log'
alias foreman='honcho'
alias hs='honcho start'

#-------------------------------------------------------------------------------
# elixir aliases
#-------------------------------------------------------------------------------
alias iex='iex -S mix'

#-------------------------------------------------------------------------------
# git aliases
#-------------------------------------------------------------------------------
alias g='git status'
alias gl="git log --graph --pretty=format:'%Cred%h%Creset %C(yellow)%d%Creset %s - %C(bold blue)%an%Creset, %Cgreen%cr' --abbrev-commit"
alias finalize='git rebase --interactive --autosquash master'

alias update='git add -A && git commit -m "updates"'
alias bugfix='git add -A && git commit -m "bugfixes"'

alias migrate='rake db:migrate && RAILS_ENV=test rake db:migrate'
alias rollback='rake db:rollback STEP=1 && RAILS_ENV=test rake db:rollback STEP=1'

alias deploy='git push && cap production deploy'

alias gcm=git_commit_m
alias gbd=git_delete_branch
alias gbdf=git_delete_branch_force

git_commit_m() {
  git add -A && git commit -m "$*"
}
git_delete_branch() {
  git branch -d $1 && git push origin :$1
}
git_delete_branch_force() {
  (git branch -D $1 && git push origin :$1) || git push origin :$1
}

#-------------------------------------------------------------------------------
# search&replace aliases
#-------------------------------------------------------------------------------
alias gr=grep_find
alias f=my_find
alias fvim=my_find_vim
alias files='find . -maxdepth 1 -type f | wc -l'
alias replace='function _replace(){ ag -0 -l $1 | xargs -0 sed -i "" -e "s/$1/$2/g"; };_replace'

grep_find() {
  fgrep -ir "$*" .
}
my_find() {
  find . \
    -type d \( \
      -path ./node_modules \
      -or -path ./public/packs \
      -or -path ./public/assets \
      -or -path ./tmp \) \
    -prune \
    -or \
    -type f \( \
       -name "*.rb" -or -name "*.erb" -or -name "*.rss" -or -name "*.xml" \
       -or -name "*.slim" -or -name "*.haml" -or -name "*.html" \
       -or -name "*.js" -or -name "*.coffee" -or -name "*.ejs"  \
       -or -name "*.jsx" -or -name "*.jst" \
       -or -name "*.jade"  -or -name "*.eco" \
       -or -name "*.css" -or -name "*.scss" \
       -or -name "*.sass" -or -name "*.yml" -or -name "*.vim" \
       -or -name "*.rabl" -or -name "*.builder"  -or -name "*.txt" \) \
    -exec grep -l "$*" {} \;
}
my_find_vim() {
  mvim `f "$*"`
}

#-------------------------------------------------------------------------------
# zsh-completions
#-------------------------------------------------------------------------------
fpath=(path/to/zsh-completions/src $fpath)
zstyle ':completion:*:processes' command 'ps -ax'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;32'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

zstyle ':completion:*:processes-names' command 'ps -e -o comm='
zstyle ':completion:*:*:killall:*' menu yes select
zstyle ':completion:*:killall:*'   force-list always

#-------------------------------------------------------------------------------
# locales configuration
#-------------------------------------------------------------------------------
export LANG="ru_RU.UTF-8"
export LC_COLLATE="ru_RU.UTF-8"
export LC_CTYPE="ru_RU.UTF-8"
export LC_MESSAGES="ru_RU.UTF-8"
export LC_MONETARY="ru_RU.UTF-8"
export LC_NUMERIC="ru_RU.UTF-8"
export LC_TIME="ru_RU.UTF-8"
export LC_ALL="ru_RU.UTF-8"

#-------------------------------------------------------------------------------
# PATH for Bundler and NodeJS
#-------------------------------------------------------------------------------
export PATH=/usr/local/bin:/usr/local/share/npm/bin:$PATH

#-------------------------------------------------------------------------------
# iterm2 colors
#-------------------------------------------------------------------------------
tab-color() {
  echo -ne "\033]6;1;bg;red;brightness;$1\a"
  echo -ne "\033]6;1;bg;green;brightness;$2\a"
  echo -ne "\033]6;1;bg;blue;brightness;$3\a"
}
tab-reset() {
  echo -ne "\033]6;1;bg;*;default\a"
  trap - INT EXIT
}
# ssh
color-ssh() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 255 0 0
    # if [[ "$*" =~ "production|ec2-.*compute-1" ]]; then
      # tab-color 255 0 0
    # else
      # tab-color 0 255 0
    # fi
  fi
  ssh $*
}
compdef _ssh color-ssh=ssh
alias ssh=color-ssh
# guard
color-guard() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 237 179 107
  fi
  guard $*
}
compdef _guard color-guard=guard
alias guard=color-guard
# rails console
color-rc() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 90 255 55
  fi
  rc $*
}
compdef _rc color-rc=rc
alias rc=color-rc
# hanami console
color-hc() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 125 255 90
  fi
  hanami console $*
}
compdef _hc color-hc=hc
alias hc=color-hc
# docker-compose
color-docker-compose() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 128 51 170
  fi
  docker-compose $*
}
compdef _docker-compose color-docker-compose=docker-compose
alias docker-compose=color-docker-compose
# rails
color-rails() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 255 128 128
  fi
  rails $*
}
compdef _rails color-rails=rails
alias rails=color-rails
# sidekiq
color-sidekiq() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 150 100 255
  fi
  sidekiq $*
}
compdef _sidekiq color-sidekiq=sidekiq
alias sidekiq=color-sidekiq
# foreman
color-foreman() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 150 100 255
  fi
  foreman $*
}
compdef _foreman color-foreman=foreman
alias foreman=color-foreman
# honcho
color-honcho() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 150 100 255
  fi
  honcho $*
}
compdef _honcho color-honcho=honcho
alias honcho=color-honcho
# webpack
color-webpack() {
  if [[ -n "$ITERM_SESSION_ID" ]]; then
    trap "tab-reset" INT EXIT
    tab-color 121 174 238
  fi
  bin/webpack-dev-server $*
}
compdef _webpack color-webpack=webpack
alias ww=color-webpack

function tabc() {
  NAME=$1; if [ -z "$NAME" ]; then NAME="Default"; fi # if you have trouble with this, change
                                                      # "Default" to the name of your default theme
  echo -e "\033]50;SetProfile=$NAME\a"
}
function colorssh() {
  tabc SSH
  ssh $*
  tabc
}
alias ssh="colorssh"

#-------------------------------------------------------------------------------
# rbenv
#-------------------------------------------------------------------------------
eval "$(rbenv init -)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
