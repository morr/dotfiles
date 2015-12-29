#-------------------------------------------------------------------------------
# ingate projects
#-------------------------------------------------------------------------------
alias ingate_chef="cd ~/develop/chefuptimus"
alias uptimus="cd ~/develop/uptimus"
alias umka="cd ~/develop/umka"
alias sibas="cd ~/develop/sibas"

alias u="umka"

alias caravan="ssh devops@94.77.64.80"
alias linode="ssh devops@176.58.123.252"
alias linode2="ssh devops@178.79.156.106"
alias nostradamus="ssh devops@176.58.113.204"

#-------------------------------------------------------------------------------
# home projects
#-------------------------------------------------------------------------------
alias shiki="cd ~/develop/shikimori"

alias hetzner="ssh devops@78.46.50.20"

#-------------------------------------------------------------------------------
# common aliases
#-------------------------------------------------------------------------------

alias psf='ps aux|grep $1'
alias ll='ls -l'

#-------------------------------------------------------------------------------
# rails
#-------------------------------------------------------------------------------
alias r='rails'

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
# search aliases
#-------------------------------------------------------------------------------
alias gr=grep_find
alias f=my_find
alias fvim=my_find_vim
alias files='find . -maxdepth 1 -type f | wc -l'

grep_find() {
  fgrep -ir "$*" .
}
my_find() {
  find . -type f \
    \( -name "*.rb" -or -name "*.erb" -or -name "*.rss" -or -name "*.xml" -or \
       -name "*.slim" -or -name "*.haml" -or -name "*.html" -or \
       -name "*.js" -or -name "*.coffee" -or -name "*.ejs" -or -name "*.jst" \
       -or -name "*.eco" -or -name "*.css" -or -name "*.scss" \
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
# zsh basic configuration
#-------------------------------------------------------------------------------
ZSH=$HOME/.oh-my-zsh
ZSH_THEME="ys"
CASE_SENSITIVE="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

plugins=(rails ruby bundler capistrano gem osx zeus rvm ssh-agent rake brew \
  command-not-found compleat composer cp history history-substring-search \
  git-remote-branch git git-flow git-extras github pow)

HISTSIZE=100000
HISTFILESIZE=200000
TERM="xterm-256color"

source $ZSH/oh-my-zsh.sh

#-------------------------------------------------------------------------------
# locales configuration
#-------------------------------------------------------------------------------
LANG="ru_RU.UTF-8"
LC_COLLATE="ru_RU.UTF-8"
LC_CTYPE="ru_RU.UTF-8"
LC_MESSAGES="ru_RU.UTF-8"
LC_MONETARY="ru_RU.UTF-8"
LC_NUMERIC="ru_RU.UTF-8"
LC_TIME="ru_RU.UTF-8"
LC_ALL="ru_RU.UTF-8"

#-------------------------------------------------------------------------------
# RVM
#-------------------------------------------------------------------------------
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

#-------------------------------------------------------------------------------
# PATH for Bundler and NodeJS
#-------------------------------------------------------------------------------
export PATH=/usr/local/bin:/usr/local/share/npm/bin:$PATH
