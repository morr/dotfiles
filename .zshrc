#export PATH=/usr/local/bin:/usr/bin
#export PATH=/usr/local/bin:/usr/bin:$HOME/.rvm/bin # Add RVM to PATH for scripting
#source "$HOME/.rvm/scripts/rvm"

# Customize to your needs...
export PATH=$PATH:/bin:/usr/sbin:/sbin:/usr/local/share/npm/bin
#echo $PATH

# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="ys"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(rails ruby bundler capistrano gem osx zeus rvm ssh-agent rake brew command-not-found compleat composer cp history history-substring-search git-remote-branch git git-flow git-extras github pow)

HISTSIZE=100000
HISTFILESIZE=200000
TERM="xterm-256color"

source $ZSH/oh-my-zsh.sh

#-----------------------------------------------------------------------------------------
# zsh-autosuggestions
#-----------------------------------------------------------------------------------------

#source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
#source ~/.zsh/zsh-autosuggestions/autosuggestions.zsh

#zle-line-init() {
  #zle autosuggest-start
#}

#zle -N zle-line-init

## NOTE don't use along with zsh-autosuggestions!
#COMPLETION_WAITING_DOTS='false'

#-----------------------------------------------------------------------------------------
# aliases
#-----------------------------------------------------------------------------------------

# mysqlfix
#DYLD_LIBRARY_PATH="/usr/local/mysql/lib:$DYLD_LIBRARY_PATH"

alias chef="cd ~/Develop/chefuptimus/"
alias reactor="cd ~/Develop/reactor"
alias uptimus="cd ~/Develop/uptimus"
alias umka="cd ~/Develop/umka"
alias sibas="cd ~/Develop/sibas"
#alias site="umka"
alias u="umka"
#alias judge="cd ~/Develop/judge"
#alias j="judge"
#alias houston="cd ~/Develop/houston"
#alias h="houston"

alias caravan="ssh devops@94.77.64.80"
alias linode="ssh devops@176.58.123.252"
alias linode2="ssh devops@178.79.156.106"
alias nostradamus="ssh devops@176.58.113.204"

alias psf='ps aux|grep $1'
alias r='rails'
alias g='git status'
alias finalize='git rebase --interactive --autosquash master'
#alias gl='git log --pretty=format:"%Cred%h%Creset %ad | %s%d [%an]" --graph --date=short'
alias gl="git log --graph --pretty=format:'%Cred%h%Creset %C(yellow)%d%Creset %s - %C(bold blue)%an%Creset, %Cgreen%cr' --abbrev-commit"
alias gput="git push origin HEAD"
#alias gup="git pull --rebase --stat"
alias gup="git-up" # https://github.com/aanand/git-up
alias ll='ls -l'
#alias hetzner='ssh -t morr@178.63.23.138 zsh'
alias files='find . -maxdepth 1 -type f | wc -l'
alias update='git add -A && git commit -m "updates"'
alias bugfix='git add -A && git commit -m "bugfixes"'
#alias pdeploy='git push && cap production deploy'
#alias sdeploy='git push && cap staging deploy'
alias migrate='rake db:migrate && RAILS_ENV=test rake db:migrate'
alias rollback='rake db:rollback STEP=1 && RAILS_ENV=test rake db:rollback STEP=1'

fpath=(path/to/zsh-completions/src $fpath)
zstyle ':completion:*:processes' command 'ps -ax'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;32'
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

zstyle ':completion:*:processes-names' command 'ps -e -o comm='
zstyle ':completion:*:*:killall:*' menu yes select
zstyle ':completion:*:killall:*'   force-list always

git_commit_m() {
  git add -A && git commit -m "$*"
}
alias gcm=git_commit_m

alias gr=grep_find
grep_find() {
  fgrep -ir "$*" .
}

alias f=my_find
alias fvim=my_find_vim

my_find() {
  find . -type f \
    \( -name "*.rb" -or -name "*.erb" -or -name "*.rss" -or -name "*.xml" -or -name "*.slim" -or -name "*.haml" -or \
       -name "*.html" -or -name "*.js" -or -name "*.coffee" -or -name "*.ejs" -or -name "*.jst" -or -name "*.eco" -or \
       -name "*.css" -or -name "*.scss" -or -name "*.sass" -or -name "*.yml" -or -name "*.vim" -or -name "*.rabl" -or \
       -name "*.builder"  -or -name "*.txt" \) \
    -exec grep -l "$*" {} \;
}

my_find_vim() {
  mvim `f "$*"`
}

git_delete_branch() {
  git branch -d $1 && git push origin :$1
}
git_delete_branch_force() {
  (git branch -D $1 && git push origin :$1) || git push origin :$1
}
alias gbd=git_delete_branch
alias gbdf=git_delete_branch_force
#alias mvim=/usr/local/Cellar/macvim/7.3-65/MacVim.app/Contents/MacOS/MacVim

#source ~/.profile

#rvm use default
#PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
PATH=$PATH:/usr/local/sbin # Add homebrew sbin to PATH for scripting
#EDITOR=/usr/local/Cellar/macvim/7.3-65/MacVim.app/Contents/MacOS/MacVim

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

LANG="ru_RU.UTF-8"
LC_COLLATE="ru_RU.UTF-8"
LC_CTYPE="ru_RU.UTF-8"
LC_MESSAGES="ru_RU.UTF-8"
LC_MONETARY="ru_RU.UTF-8"
LC_NUMERIC="ru_RU.UTF-8"
LC_TIME="ru_RU.UTF-8"
LC_ALL="ru_RU.UTF-8"
