# Why the three zsh forms exist

Reference for debugging a Bash call that died oddly. The three mandatory forms live in
`~/.claude/CLAUDE.md`; this file is the mechanics behind them — read it when a command
failed in a way you don't recognise, not when composing one.

## `=` at the start of a word (form 1)

The Bash tool runs **zsh**, where the `EQUALS` option is on by default: a word starting with
`=` is replaced by the full path to the command of that name (`echo =ls` → `/bin/ls`). So
`echo ===` fails with `(eval):1: == not found` and exits 1. Worse, the expansion happens at
parse time, so **the rest of the command line never runs** — it reads as "git worked, then
grep silently printed nothing", and the failure becomes the exit code of the whole call.

Write separators as `echo ---` (zsh leaves a leading hyphen alone) or quote them:
`echo '==='`. Same rule for any bare argument with a leading `=`.

## An unmatched glob (form 2)

A glob with no matches is an error (`no matches found`) rather than a literal, and it kills the
whole command before it runs — quote it or use `ls`/`find`. **This bites hardest when the glob
sits inside a flag value, where it doesn't read as a glob:** an unquoted `--include=*.rb` dies
with `(eval):1: no matches found`, because zsh expands the pattern against the *current*
directory, not against grep's search target. Always quote it — `--include='*.rb'`,
`--exclude='*.log'`, `-name '*.yml'`. The symptom is identical to the `=`-expansion one above
(output stops right after the preceding `echo ---`), so check which of the two it actually is
before "fixing" the separator.

## A probe at the tail of a chain (form 3)

A `;`-chain reports the exit code of its **last** command only. If the chain ends with a
probe that legitimately "fails" — a listing of a missing file, a `grep` with no matches,
`[ -f … ]` — the whole Bash call shows "Exit code 1" even though every earlier part ran and
printed fine. Before treating such a call as broken, check whether the tail was an existence
probe answering "no". The fix is form 3: phrase every probe as
`[ -d x ] && echo yes || echo no` (or `[ -f x ] && … `), which answers and exits 0 in one shape,
so it never matters where in the chain it landed.

## Related gotchas

`~` inside quotes is not expanded. macOS `cat` is BSD: there is no `-A`, only `-e` / `-t` /
`-vet`; watch for the same GNU-vs-BSD flag gap in other coreutils.
