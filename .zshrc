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

plugins=(asdf ruby bundler capistrano gem macos npm rbenv ssh-agent rake brew \
  command-not-found compleat cp history history-substring-search \
  git git-extras pow npm yarn docker rust)

HISTSIZE=10000000
HISTFILESIZE=10000000
SAVEHIST=10000000
setopt appendhistory
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
TERM="xterm-256color"

if [[ $(uname -m) == 'arm64' ]]; then
  export LOCAL_BREW=/opt/homebrew
else
  export LOCAL_BREW=/usr/local
fi

export JAVA_HOME="$LOCAL_BREW/Cellar/openjdk/18/bin/"
export EDITOR="mvim"
# some shit to enable erlang history
export ERL_AFLAGS="-kernel shell_history enabled"
export NODE_OPTIONS=--openssl-legacy-provider

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
alias vimfiles="cd ~/.vim/"
alias nvimfiles="cd ~/.config/nvim/"

#-------------------------------------------------------------------------------
# work projects
#-------------------------------------------------------------------------------
alias cwd="cd ~/develop/work/cardwiz-data/"
alias chef-cwd="cd ~/develop/work/chef-cardwiz-data/"

alias cw="cd ~/develop/work/cardwiz/"
alias chef-cw="cd ~/develop/work/chef-cardwiz/"

alias cwb="cd ~/develop/work/cardwiz-blog/"

alias ms="cd ~/develop/work/minisklad/"
alias ms-app="cd ~/develop/work/minisklad-app//"
alias franchise="cd ~/develop/work/franchise/"
alias chef-ms="cd ~/develop/work/chef-minisklad/"

alias cb="cd ~/develop/work/cardwiz-blog/"
alias cs="cd ~/develop/work/cardwiz-shared/"

#-------------------------------------------------------------------------------
# home projects
#-------------------------------------------------------------------------------
alias dev="cd ~/develop"
alias zxc="cd ~/develop/zxc"
alias bevy="cd ~/develop/bevy"
alias chef-shiki="cd ~/develop/chef-shiki"
alias shiki="cd ~/develop/shikimori"
alias shiki-editor="cd ~/develop/shiki-editor"
alias mal_parser="cd ~/develop/mal_parser"
alias neko="cd ~/develop/neko-achievements"

alias mount_hetzner='mkdir -p /Volumes/hetzner; sshfs shiki:/ /Volumes/hetzner'

backup_shikimori_images() {
  local local_path=/Volumes/backup/shikimori_new
  local shiki_path_1=/mnt/store/uploads
  local shiki_path_2=/home/apps/shikimori/production/shared/public/system
  local shiki_path_3=/mnt/store/system

  unalias ssh 

  for shiki_path in $shiki_path_1
  do
    echo "starting process $shiki_path ..."
    [ ! -d $local_path/uploads ] && mkdir $local_path/uploads
    for dir in $(ssh shiki ls $shiki_path)
    do
      if [[ "$dir" == "cache" ]]; then
        echo "skipping $dir ($shiki_path/$dir) ..."
        continue
      fi

      echo "processing $dir ($shiki_path/$dir) ..."
      [ ! -d $local_path/uploads/$dir ] && mkdir $local_path/uploads/$dir
      for subdir in $(ssh shiki ls $shiki_path/$dir)
      do
        echo "processing $dir/$subdir ($shiki_path/$dir/$subdir) ..."
        rsync -urv --delete --exclude "*-*" -e ssh shiki:$shiki_path/$dir/$subdir $local_path/uploads/$dir
      done
    done
  done

  for shiki_path in $shiki_path_2 $shiki_path_3
  do
    echo "starting process $shiki_path ..."
    [ ! -d $local_path/system ] && mkdir $local_path/system
    for dir in $(ssh shiki ls $shiki_path)
    do
      if [[ "$dir" == "list_imports" ]]; then
        local subdir="lists"
      else
        local subdir="original"
      fi

      echo "processing $dir/$subdir ($shiki_path/$dir/$subdir) ..."
      rsync -urv --delete --include "$dir/" --include "$dir/$subdir/***" --exclude "*" -e ssh shiki:$shiki_path/$dir $local_path/system/
    done
  done
}
alias shikibackup=backup_shikimori_images

backup_shikimori_images_v2() {
  local local_path=/Volumes/backups_2tb/shikimori
  local shiki_path_1=/mnt/store/uploads
  local shiki_path_2=/home/apps/shikimori/production/shared/public/system
  local shiki_path_3=/mnt/store/system

  unalias ssh 

  for shiki_path in $shiki_path_1
  do
    echo "starting process $shiki_path ..."
    [ ! -d $local_path/uploads ] && mkdir $local_path/uploads
    for dir in $(ssh shiki ls $shiki_path)
    do
      if [[ "$dir" == "cache" ]]; then
        echo "skipping $dir ($shiki_path/$dir) ..."
        continue
      fi

      echo "processing $dir ($shiki_path/$dir) ..."
      [ ! -d $local_path/uploads/$dir ] && mkdir $local_path/uploads/$dir
      for subdir in $(ssh shiki ls $shiki_path/$dir)
      do
        echo "processing $dir/$subdir ($shiki_path/$dir/$subdir) ..."
        rsync -urv --delete --exclude "*-*" -e ssh shiki:$shiki_path/$dir/$subdir $local_path/uploads/$dir
      done
    done
  done

  for shiki_path in $shiki_path_2 $shiki_path_3
  do
    echo "starting process $shiki_path ..."
    [ ! -d $local_path/system ] && mkdir $local_path/system
    for dir in $(ssh shiki ls $shiki_path)
    do
      if [[ "$dir" == "list_imports" ]]; then
        local subdir="lists"
      else
        local subdir="original"
      fi

      echo "processing $dir/$subdir ($shiki_path/$dir/$subdir) ..."
      rsync -urv --delete --include "$dir/" --include "$dir/$subdir/***" --exclude "*" -e ssh shiki:$shiki_path/$dir $local_path/system/
    done
  done
}
alias shikibackup_v2=backup_shikimori_images_v2

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
alias ww='if [ -f ./bin/watch ]; then ./bin/watch; elif [ -f ./bin/shakapacker-dev-server ]; then ./bin/shakapacker-dev-server; elif [ -f ./bin/webpacker-dev-server ]; then ./bin/webpacker-dev-server; else ./bin/webpack-dev-server; fi'

#-------------------------------------------------------------------------------
# elixir aliases
#-------------------------------------------------------------------------------
alias iex='iex -S mix'

#-------------------------------------------------------------------------------
# git aliases
#-------------------------------------------------------------------------------
alias g='git status'
alias gl="git log --graph --pretty=format:'%Cred%h%Creset %C(yellow)%d%Creset %s - %C(bold blue)%an%Creset, %Cgreen%cr' --abbrev-commit"
alias gp='git push'
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
       -or -name "*.vue" \
       -or -name "*.jsx" -or -name "*.jst" \
       -or -name "*.jade" -or -name "*.eco" \
       -or -name "*.css" -or -name "*.scss" \
       -or -name "*.sass" -or -name "*.yml" -or -name "*.vim" \
       -or -name "*.rabl" -or -name "*.builder"  -or -name "*.txt" \) \
    -exec grep -l "$*" {} \;
}
my_find_vim() {
  mvim `f "$*"`
}

#-------------------------------------------------------------------------------
# shikimori aliases
#-------------------------------------------------------------------------------
shiki_exec() {
  ssh devops@shiki_web "source /home/devops/.zshrc && cd /home/apps/shikimori/production/current && RAILS_ENV=production bundle exec rails runner \"$*\""
}

shiki_exec_ap() {
  ssh devops@shiki_web "source /home/devops/.zshrc && cd /home/apps/shikimori/production/current && RAILS_ENV=production bundle exec rails runner \"ap($*)\""
}

#-------------------------------------------------------------------------------
# other
#-------------------------------------------------------------------------------
alias fix-spotlight="cd $HOME; find . -type d -path './.*' -prune -o -path './Pictures*' -prune -o -path './Library*' -prune -o -path '*node_modules/*' -prune -o -type d -name 'node_modules' -exec touch '{}/.metadata_never_index' \; -print"

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
export PATH="$LOCAL_BREW/bin:$LOCAL_BREW/share/npm/bin:$PATH"

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
    if [[ "$1" =~ "^(guard$|yarn test|rspec|rails parallel:spec)" ]]; then
      tab-color 255 177 0
    elif [[ "$1" =~ "^(rc|rails console|hc$|hanami console$|iex|command iex|pry|irb)" ]]; then
      tab-color 90 255 55
    elif [[ "$1" =~ "^(ys|yarn start|yarn dev)$" ]]; then
      tab-color 0 255 192
    elif [[ "$1" =~ "^(sidekiq|forman|docker-compose|^os$|^OVERMIND_PROCESSES=)" ]]; then
      # tab-color 128 51 170
      tab-color 150 100 255
    elif [[ "$1" =~ "^(webpack|ww|./bin/webpack-dev-server)$" ]]; then
      tab-color 121 174 238
    elif [[ "$1" =~ "^(rails|yarn|bundle)" ]]; then
      tab-color 255 128 128
    elif [[ "$1" =~ "^(deploy|cap (production|staging )?deploy|mix deploy|git push && BRANCH=staging cap staging deploy|./do_releas|yarn upgrade|bundle upgrade|shiki_exec)" ]]; then
      tab-color 255 0 0
    elif [[ "$1" =~ "^(shikibackup)" ]]; then
      tab-color 255 174 174
    # elif [[ "$1" =~ "^nvim" ]]; then
    #   tab-color 110 110 190
    fi
  }

  autoload -U add-zsh-hook
  add-zsh-hook precmd  iterm2_tab_precmd
  add-zsh-hook preexec iterm2_tab_preexec
fi

#-------------------------------------------------------------------------------
# background colors
#-------------------------------------------------------------------------------
# if [[ -n "$ITERM_SESSION_ID" ]]; then
#   function tabc() {
#     NAME=$1; if [ -z "$NAME" ]; then NAME="Default"; fi # if you have trouble with this, change
#                                                         # "Default" to the name of your default theme
#     echo -e "\033]50;SetProfile=$NAME\a"
#   }
#   function colorssh() {
#     # trap "tab-reset" INT EXIT
#     tabc SSH
#     tab-color 255 0 0
#     ssh $*
#     tab-reset
#     tabc
#   }
#   alias ssh="colorssh"
# fi

#-------------------------------------------------------------------------------
# rust
#-------------------------------------------------------------------------------
. "$HOME/.cargo/env"

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

#-------------------------------------------------------------------------------
# ZSH
#-------------------------------------------------------------------------------
export PATH="$LOCAL_BREW/sbin:$PATH"

#-------------------------------------------------------------------------------
# ASDF
#-------------------------------------------------------------------------------
export ASDF_DIR=$LOCAL_BREW/opt/asdf/libexec
. ${LOCAL_BREW}/opt/asdf/libexec/asdf.sh

# append completions to fpath
fpath=(${ASDF_DIR}/completions $fpath)
# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit
