# zsh mechanics behind the shell rules

Reference for debugging a Bash call that failed oddly. The two mandatory forms live in
`~/.claude/CLAUDE.md` and `~/.zcode/AGENTS.md`; this file is the mechanics behind them —
read it when a command failed in a way you don't recognise, not when composing one.

Agent shells on this machine get bash-compatible equals/glob semantics from `~/.zshenv`:
for non-interactive zsh it unsets `EQUALS` and `NOMATCH`, so a bare `=`-word and an
unmatched glob pass through as literals instead of killing the command line. The first two
sections describe the option mechanics themselves — still live in interactive shells and on
machines without this dotfiles setup.

## `=` at the start of a word (EQUALS)

With `EQUALS` on — zsh's default — a word starting with `=` is replaced by the full path to
the command of that name (`echo =ls` → `/bin/ls`); a word with no such command behind it
fails at parse time (`(eval):1: == not found`), so the rest of the line never runs. If you
need the expansion, or the command has to survive an interactive shell too, quote the word:
`echo '==='`.

## An unmatched glob (NOMATCH)

With `NOMATCH` on — zsh's default — a glob with no matches is an error (`no matches found`)
rather than a literal, and it kills the whole command before it runs. This is the option
`~/.zshenv` turns off for agent shells, which is why an unquoted `--include=*.rb` now
reaches grep intact there. One behavior survives the option either way: a separate-word glob
like `-name *.yml` expands against the *current* directory whenever a file there matches —
silently changing what find sees — so flag-value globs stay quoted.

## A probe at the tail of a chain

A `;`-chain reports the exit code of its **last** command only. If the chain ends with a
probe that legitimately "fails" — a listing of a missing file, a `grep` with no matches,
`[ -f … ]` — the whole Bash call shows "Exit code 1" even though every earlier part ran and
printed fine. Before treating such a call as broken, check whether the tail was an existence
probe answering "no". The fix is form 2: phrase every probe as
`[ -d x ] && echo yes || echo no` (or `[ -f x ] && … `), which answers and exits 0 in one shape,
so it never matters where in the chain it landed.

## Related gotchas

`~` inside quotes is not expanded. macOS `cat` is BSD: there is no `-A`, only `-e` / `-t` /
`-vet`; watch for the same GNU-vs-BSD flag gap in other coreutils.
