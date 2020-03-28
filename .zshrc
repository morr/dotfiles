# HOWTO
# install zsh: sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# fish syntax highlight: cd ~/.oh-my-zsh && git clone git://github.com/zsh-users/zsh-syntax-highlighting.git
#set rubydll=/System/Library/Frameworks/Ruby.framework/Versions/2.6/usr/lib/libruby.2.6.dylib
#-------------------------------------------------------------------------------
# zsh basic configuration
#-------------------------------------------------------------------------------
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="../../dotfiles/.oh-my-zsh/themes/morr"
# ZSH_THEME="ys"

CASE_SENSITIVE="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

plugins=(ruby bundler capistrano gem osx npm rbenv ssh-agent rake brew \
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
# ubuntu config
#-------------------------------------------------------------------------------
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
  zstyle :omz:plugins:ssh-agent identities id_rsa github_2_rsa
  # xmodmap -e "keycode 94 = asciitilde"
  alias mvim="gvim"

  export PATH=$HOME/.local/bin:$PATH
fi

#-------------------------------------------------------------------------------
# configs projects
#-------------------------------------------------------------------------------
alias dotfiles="cd ~/dotfiles/"
alias vimfiles="cd ~/.vim"

#-------------------------------------------------------------------------------
# work projects
#-------------------------------------------------------------------------------
alias erebor="cd ~/develop/work/erebor"
alias e="erebor"
alias chef-erebor="cd ~/develop/work/chef-erebor"

alias bidon="cd ~/develop/work/bidon"
alias b="bidon"
alias chef-bidon="cd ~/develop/work/chef-bidon"

alias as="cd ~/develop/work/amazing-supplies/"
alias chef-as="cd ~/develop/work/chef-as"

alias grin="cd ~/develop/work/grin/"
alias chef-grin="cd ~/develop/work/chef-grin"

alias grin-landing="cd ~/develop/work/grin-landing/"

alias cwd="cd ~/develop/work/cardwiz-data/"
alias chef-cwd="cd ~/develop/work/chef-cardwiz-data/"

alias cw="cd ~/develop/work/cardwiz/"
alias chef-cw="cd ~/develop/work/chef-cardwiz/"

alias ms="cd ~/develop/work/minisklad/"
alias ms-app="cd ~/develop/work/minisklad-app//"
alias chef-ms="cd ~/develop/work/chef-minisklad/"

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
  local local_path=/Volumes/backup/shikimori_new/
  local shiki_path=/home/apps/shikimori/production/shared/public/system/
  local shiki_path_2=/mnt/store/system/

  unalias ssh
  for dir in $(ssh shiki_web ls $shiki_path)
  do
    echo "processing $dir ..."
    rsync -urv -e ssh shiki_web:$shiki_path$dir $local_path
    # --exclude=keepall --delete
    # https://unix.stackexchange.com/questions/18564/asking-rsync-to-delete-files-on-the-receiving-side-that-dont-exist-on-the-sendic
  done

  for dir in $(ssh shiki_web ls $shiki_path_2)
  do
    echo "processing $dir ..."
    rsync -urv -e ssh shiki_web:$shiki_path_2$dir $local_path
  done

  alias ssh="colorssh"
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
alias rc='rails console'
alias log='tail -f log/development.log'
alias foreman='honcho'
alias os='overmind start'
alias ys='yarn start'
alias ww='./bin/webpack-dev-server'

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
# export LANG="ru_RU.UTF-8"
# export LC_COLLATE="ru_RU.UTF-8"
# export LC_CTYPE="ru_RU.UTF-8"
# export LC_MESSAGES="ru_RU.UTF-8"
# export LC_MONETARY="ru_RU.UTF-8"
# export LC_NUMERIC="ru_RU.UTF-8"
# export LC_TIME="ru_RU.UTF-8"
# export LC_ALL="ru_RU.UTF-8"

export LANG="en_US.UTF-8"
export LC_COLLATE="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_MESSAGES="en_US.UTF-8"
export LC_MONETARY="en_US.UTF-8"
export LC_NUMERIC="en_US.UTF-8"
export LC_TIME="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

#-------------------------------------------------------------------------------
# PATH for Bundler and NodeJS
#-------------------------------------------------------------------------------
export PATH=/usr/local/bin:/usr/local/share/npm/bin:$PATH

#-------------------------------------------------------------------------------
# tab colors
#-------------------------------------------------------------------------------
if [[ -n "$ITERM_SESSION_ID" ]]; then
  tab-color() {
    echo -ne "\033]6;1;bg;red;brightness;$1\a"
    echo -ne "\033]6;1;bg;green;brightness;$2\a"
    echo -ne "\033]6;1;bg;blue;brightness;$3\a"
  }
  tab-red() { tab-color 255 0 0 }
  tab-green() { tab-color 0 255 0 }
  tab-blue() { tab-color 0 0 255 }
  tab-reset() { echo -ne "\033]6;1;bg;*;default\a" }

  function iterm2_tab_precmd() {
    tab-reset
  }

  function iterm2_tab_preexec() {
    if [[ "$1" =~ "^(guard$|yarn test)" ]]; then
      tab-color 255 177 0
    elif [[ "$1" =~ "^(rc|rails console|hc|hanami console|iex)$" ]]; then
      tab-color 90 255 55
    elif [[ "$1" =~ "^(ys|yarn start)$" ]]; then
      tab-color 0 255 192
    elif [[ "$1" =~ "^(sidekiq|forman|docker-compose|os$)" ]]; then
      # tab-color 128 51 170
      tab-color 150 100 255
    elif [[ "$1" =~ "^(webpack|ww|./bin/webpack-dev-server)$" ]]; then
      tab-color 121 174 238
    elif [[ "$1" =~ "^(rails|yarn)" ]]; then
      tab-color 255 128 128
    elif [[ "$1" =~ "^(deploy|cap (production|staging )?deploy|mix deploy)" ]]; then
      tab-color 255 0 0
    elif [[ "$1" =~ "^(shikibackup)" ]]; then
      tab-color 255 174 174
    fi
  }

  autoload -U add-zsh-hook
  add-zsh-hook precmd  iterm2_tab_precmd
  add-zsh-hook preexec iterm2_tab_preexec
fi

#-------------------------------------------------------------------------------
# background colors
#-------------------------------------------------------------------------------
if [[ -n "$ITERM_SESSION_ID" ]]; then
  function tabc() {
    NAME=$1; if [ -z "$NAME" ]; then NAME="Default"; fi # if you have trouble with this, change
                                                        # "Default" to the name of your default theme
    echo -e "\033]50;SetProfile=$NAME\a"
  }
  function colorssh() {
    # trap "tab-reset" INT EXIT
    tabc SSH
    tab-color 255 0 0
    ssh $*
    tab-reset
    tabc
  }
  alias ssh="colorssh"
fi

#-------------------------------------------------------------------------------
# rbenv
#-------------------------------------------------------------------------------
eval "$(rbenv init -)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

#-------------------------------------------------------------------------------
# GPG
#-------------------------------------------------------------------------------
export GPG_TTY=$(tty)

export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
