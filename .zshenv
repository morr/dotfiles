# Sourced by every zsh, including the non-interactive `zsh -c` that agent
# harnesses (ZCode, Claude Code) use for their Bash tool. Give those shells
# bash-compatible equals/glob semantics: a word like `===` and an unmatched
# `--include=*.rb` stay literals instead of killing the whole command line
# (`== not found` / `no matches found` parse failures in agent session logs).
# Interactive shells keep stock zsh behavior.
. "$HOME/.cargo/env"

if [[ ! -o interactive ]]; then
  unsetopt equals nomatch
fi
