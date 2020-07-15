# https://github.com/Homebrew/homebrew-bundle
# brew bundle -v

# - some cask packages and App Store applications ask for password
# - see comments before package or application for postinstallation setup
# - see `brew services` on how to manage services for supported forumalae

#-------------------------------------------------------------------------------
# Taps (third-party repositories)
#-------------------------------------------------------------------------------

tap 'homebrew/bundle'
tap 'homebrew/services'
tap 'puma/puma'

#-------------------------------------------------------------------------------
# Homebrew
#-------------------------------------------------------------------------------

brew 'coreutils'
brew 'curl'
brew 'git'
brew 'wget'
brew 'asdf'

brew 'overmind'
brew 'tmux'

brew 'gpg'
brew 'htop'
brew 'imagemagick'
brew 'jq'
# provides rsvg-convert utility to convert svg to png
# brew 'librsvg'

brew 'mas'
brew 'memcached', restart_service: :changed
brew 'mc'
# brew 'mpv' # media player
brew 'node'

# https://github.com/Homebrew/brew/blob/master/docs/Versions.md
# brew 'postgresql@9.5', restart_service: :changed

# for psql
#brew 'postgresql', restart_service: :changed
# after installation:
# - `sudo puma-dev -setup`
# - `puma-dev -install`
# - add symlinks to _~/.puma-dev/_
# - add `gem 'puma'` to _Gemfile_ of all symlinked applications
#   (for development and test groups only)
brew 'puma/puma/puma-dev'
# - it's much easier to install pow manually:
#   `curl get.pow.cx | sh`
# - create symlinks for all required projects:
#   `ln -s ~/dev/reenter_builder ~/.pow`
#brew 'pow'
# http://tap349.github.io/rbenv/ruby/chef/capistrano/2016/03/30/rbenv
brew 'rbenv'
brew 'redis', restart_service: :changed
brew 'ripgrep'

brew 'yarn'
# - make it a login shell: `chsh -s /bin/zsh`
#   (all available shells are listed in /etc/shells,
#   current shell can be printed with `echo $0` command)
# - install oh-my-zsh:
#   - https://github.com/robbyrussell/oh-my-zsh#via-curl
# - install oh-my-zsh plugins:
#   - https://github.com/zsh-users/zsh-autosuggestions#oh-my-zsh
#   - https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
brew 'zsh'

#-------------------------------------------------------------------------------
# Homebrew-Cask
#-------------------------------------------------------------------------------

cask 'java'
cask 'homebrew/cask-versions/adoptopenjdk8'

cask_args appdir: '/Applications'

cask 'macvim'
cask 'karabiner-elements'
cask 'iterm2'
cask 'mucommander'

# cask 'google-chrome'
# cask 'iterm2'
# cask 'skype'

# cask 'steam'

# - `open /usr/local/Caskroom/utorrent/latest/uTorrent.app`
# - system preferences:
#   - Users & Groups -> Login Items: remove (don't hide)
# cask 'utorrent'

#-------------------------------------------------------------------------------
# App Store
#
# mas search Trello
#-------------------------------------------------------------------------------

# - link to dropbox account and sync (Replace Local Data)
# - app preferences:
#   - General:
#     - Quick Entry: <C-S-a>
#   - Appearance:
#     - Font Size: Big
#     - [ ] Show notes under tasks
#   - Sync:
#     - Setup:
#       - Link Dropbox Account
# mas '2Do', id: 477670270
# on first run:
# - select ~/Documents folder
#   (Cloud Mail.Ru subfolder will be created automatically)
# - select to start application on system startup
# - select folders to synchronize (books/, videos/, education/)
# mas 'Cloud Mail.Ru', id: 893068358
# to add Safari extension first open Dashlane, then Safari -
# you'll be prompted to install Dashlane extension
#
# - app preferences:
#   - General:
#     - [x] Start Dashlane at login
mas 'Dashlane - Password Manager, Secure Digital Wallet', id: 552383089
# mas 'Evernote', id: 406056744
# - on first run agree to start Flexiglass every time systems starts
#
# - system preferences:
#   - Security & Privacy -> Privacy -> Accessibility
# - app preferences:
#   - Window Mover:
#     - Move: <S-M> + one finger (+ Left Mouse Button for mouse)
#     - Resize: <S-M> + two fingers (+ Right Mouse Button for mouse)
#   - Layouts:
#     - Maximize: <S-M-CR>
#   - Preferences:
#     - [ ] Show icon in Dock
mas 'Flexiglass', id: 426410278
# - app preferences:
#   - General:
#     - After upload:
#       - [ ] Open in browser
#     - [x] Launch at login
#   - Hotkeys:
#     - Capture area: <M-1>
#   - Account (to be able to upload screenshots):
#     - Login -> Login with Facebook (a***.t***.i***@gmail.com)
mas 'Monosnap', id: 540348655
# mas 'Pomodoro Timer', id: 872515009
# - system preferences:
#   - Users & Groups -> Login Items: add (don't hide)
# - app preferences:
#   - Shortcuts:
#     - General -> Show Magnifier: <M-2>
mas 'Sip', id: 507257563
mas 'Telegram Desktop', id: 946399090
mas 'Xcode', id: 497799835
