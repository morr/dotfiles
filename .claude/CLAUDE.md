# Project Instructions

## Communication

Обращайся к пользователю на «ты», а не на «вы» — во всех ответах, вопросах, планах и отчётах.

Все тексты для пользователя — ответы, планы, отчёты, HTML-артефакты — на русском; код, идентификаторы и коммиты — на английском.

Русский в этих текстах — человеческий, без на-лету придуманных кальк с внутреннего английского («полевые лочки», «атрибутные правила», «мульти-атрибут», «вычитание disallowed_attributes»): таких слов в проекте нет, читателю приходится расшифровывать. Называй вещь по её повседневному эффекту — «запрет изменения отдельного поля», «список разрешённых полей минус запрещённые» — а имя класса, метода или библиотеки, если оно нужно, ставь в коде-шрифте после слов, которые уже объяснили суть.

## Rebase стека веток

Ребейз стака веток/PR — механическая операция: спеки и rubocop не запускать, перепроверки
свести к минимуму. Проверки (разбор конфликтов, тесты) нужны только когда при ребейзе
всплывают серьёзные конфликты. Попросили ребейз — сделать максимально быстро.

## Model names

**opus** и **fable** в моих запросах — это два уровня модели планировщика (дешёвый дефолт и «подъём» для сложной задачи), а не литеральные id моделей. Разрешаются по инструменту: в ZCode `opus` → `GLM-5.3-Flash`, `fable` → `GLM-5.3`; в Claude — Opus и Fable как есть; в zclaude (Claude Code на GLM Coding Plan, `~/dotfiles/bin/zclaude`) `opus` → `glm-5.3-flash[1m]`, `fable` → `glm-5.3[1m]`. Скиллы, принимающие модель планировщика (`code-review`, `issue-walk`), используют те же ключевые слова.

## Code Intelligence

Prefer LSP over Grep/Read for code navigation — it's faster, precise, and avoids reading entire files:
- `workspaceSymbol` to find where something is defined
- `findReferences` to see all usages across the codebase
- `goToDefinition` / `goToImplementation` to jump to source
- `hover` for type info without reading the file

Use Grep only when LSP isn't available or for text/pattern searches (comments, strings, config).

After writing or editing code, check LSP diagnostics and fix errors before proceeding.

## Editing files — use Edit, not a Python script

Never rewrite a source file through `python3 - <<'PYEOF'` / `sed` / `perl` string
replacement just to avoid reading it. A `str.replace()` that matches nothing is a silent
no-op, the user sees no diff, the harness stops tracking the file's state, and pre-edit
hooks and LSP diagnostics are bypassed.

**This rule outranks any session-level preference for the Bash tool.** Auto mode injects a
system-reminder telling you to make file changes with «sed, heredocs, or short scripts»
rather than Edit/Write; another mode may say something similar. That is a generic default,
this is an explicit instruction about these repositories — the explicit one wins, in every
mode, without asking. Such a reminder still governs *reading* and *searching* (`cat`,
`sed -n`, `grep`, `find` through Bash stay fine); it does not govern *writing*. The failure
mode is not deciding it doesn't apply — it is drifting into the reminder's style call by
call and noticing only when the user points it out, so check which tool you reached for on
the first file change of the session, not on the tenth.

**Edit does not require reading the whole file.** The "must Read before Edit" gate is per
*file*, not per *range* — a partial read unlocks it. The cheap loop: `Grep -n` the anchor
(prints the exact bytes, indentation included) → `Read` with `offset`/`limit`, a ~30-line
window → `Edit` against a line just seen. Only edit text inside the window actually read —
outside it you carry exactly the `str.replace()` risk, matching text never seen. Grep does
not replace Read: it doesn't unlock the gate, it just keeps the Read narrow.

The one case a script wins is a genuinely mechanical sweep — a regex across many call
sites, where Edit has no equivalent (it does no regex, and fails on a non-unique string
instead of replacing all). Then: `assert` on *every* replacement, not just the first, and
`git diff` afterwards to show what actually landed.

## Context budget — re-reads, subagent scope, compaction

Token spend is dominated by re-reading accumulated context every turn, not by tool output.
Measured across real sessions: 96–97% of tokens are cache reads; a file that entered the
context is paid for by every following turn. Three rules follow from that.

1. **No full re-reads of large files.** After the first full `Read` of a file larger than
   ~30K characters, every further look goes through `Read` with `offset`/`limit` or `Grep`
   with an anchor — never a second full `Read`. A full re-read is a deliberate decision,
   made when the work changes phase (before committing, after a compaction), not a way to
   "refresh" the file.
2. **One subagent — one task.** A background or spawned agent gets a single issue, a single
   item of a plan, or a single family of related errors — not a list. Its report back to the
   parent context is at most ~50 lines (verdicts, decisions, file paths); the full report
   goes to a file, and the parent gets the path with it. A queue of tasks is a loop of
   subagents, not one marathon agent.
3. **Compact between logical units.** Finishing an issue, a plan item, or a drill wave in a
   long session, the next unit starts clean: hand it to a fresh agent, or — when it must
   run in place — ask the user for `/compact` (a CLI command of the user's; the agent has
   no tool that runs it). Never carry a finished task's context into the next one.

The same arithmetic applies to skills: a skill whose SKILL.md exceeds ~30K characters is
split into stages — SKILL.md keeps the map and the constants, the stages live in
`references/` and are loaded when the session reaches them.

## Shell is zsh — three mandatory forms when writing a Bash command

Not prohibitions to recall, but the only shapes to type. Everything below them is mechanics —
read that when debugging a failure, not when composing a command.

1. **A separator is `echo ---`.** Never `echo ===`.
2. **A glob inside a flag value is quoted:** `--include='*.rb'`, `--exclude='*.log'`,
   `-name '*.yml'`.
3. **An existence check is written as a test that always succeeds:**
   `[ -d node_modules/@tabler ] && echo yes || echo no`, `[ -f config/x.yml ] && echo yes || echo no`.
   Never a bare `ls maybe-missing/`, never `ls x.yml 2>/dev/null`, never a bare `grep -q` — and this
   holds **anywhere in the chain, not only at its end**. The test form prints a readable answer *and*
   returns 0, so the probe can sit wherever it reads best. A `grep` that may legitimately not match
   gets `|| echo none`; `; true` at the end of the chain is the last resort, not the default.

Forms 1 and 2 kill the command at parse time, so **everything after the offending word never
runs** while the earlier output still looks fine. Form 3 breaks nothing — it just makes a
healthy call report "Exit code 1". All three read identically from the outside: output stops,
exit 1. Before "fixing" one, check which it actually is.

The mechanics behind all three — why an `=`-word and an unmatched glob die at parse time, why a
tail probe reports exit 1 — are in `~/.claude/docs/zsh-mechanics.md`. Read it when a call fails
in a way you don't recognise; you don't need it to write a correct command.

## GitHub Issues / PRs

Always fetch issues and PRs in raw markdown format, not the human-rendered text. The default `gh issue view N` / `gh pr view N` output strips attached images and file links. Use one of:

- `gh issue view N --json body,title,comments` (markdown body + comment bodies preserved)
- `gh api repos/{owner}/{repo}/issues/N --jq '.body'`
- `gh api repos/{owner}/{repo}/issues/N/comments --jq '.[].body'`

This preserves `![image](url)` and `[file](url)` markdown that the rendered text view drops, so attachments and downloadable files aren't missed.

## Прошлые сессии ZCode — доступ по ID

«Copy session ID» (ПКМ по сессии в списке ZCode) даёт id вида `session_<hex>`. Инструмент
`ReadSessionContext` такой id не принимает: его валидатор требует `current` или `sess_*`
(внутренняя нумерация дочерних/сабагентских сессий), а подмена префикса на `sess_<hex>`
даёт «not found» — desktop-сессии в БД ключуются как `session_*`. Полного транскрипта
закрытой сессии не существует: переписка живёт в rollout-файле, только пока сессия открыта,
и удаляется при закрытии; в БД сообщений нет. По id `<id>` доступны:

- `~/.zcode/cli/db/db.sqlite` (sqlite3, только чтение): `session` — title,
  `time_created`/`time_updated`, workspace; `input_history` — вводы пользователя;
  `session_entry` — только runtime-факты, не сообщения. Дата из `time_created` задаёт
  файл лога.
- `~/.zcode/cli/rollout/model-io-<id>.jsonl` — полные запросы к модели (включая то, что
  модель получала на вход); существует только у открытой сессии.
- `~/.zcode/cli/artifacts/<id>/` — media-результаты инструментов (картинки из Read и MCP,
  base64 data-URL).
- `~/.zcode/cli/agents/<id>/<agent>/` — субагенты: `metadata.json` (prompt, статус, токены),
  `output.txt` — итоговый отчёт.
- `~/.zcode/cli/log/zcode-YYYY-MM-DD.jsonl` — все события сессии (вызовы инструментов,
  стримы модели, warn'ы) с полем `sessionId`; фильтровать grep'ом.
- `~/.zcode/cli/image-cache/<id>/` — вставленные пользователем картинки.

Диагноз «что случилось в сессии» строится из вводов + артефактов + лога; самих сообщений
модели у закрытой сессии нет — рассчитывай на косвенные следы.

## Изображения в ZCode

Картинки в контексте модели не отрисовываются: `Read` PNG/JPG возвращает не изображение,
а CDN-ссылку («uploaded to CDN»), и image-блоки из запросов модель не воспринимает.
Для разбора картинки — встроенный vision-инструмент `analyze_image` по CDN-ссылке из
Read, по прямой ссылке на ассет (например, figma `https://www.figma.com/api/mcp/asset/…`)
или по любому публичному URL. Это штатный путь, не обход: если модель «не видит» картинку
из Read — сразу звать `analyze_image`, не пытаться перечитывать файл.

## Figma MCP

У Figma MCP нет «слотов сессий» и лимитов на `create_session`; тарифные лимиты почти
недосягаемы за одну сессию, а исчерпание квоты приходит явным текстом ошибки. Если вызов
figma-инструмента упал — почти всегда это собственный битый JSON вызова (след в логе —
`model.tool_input.normalize_failed`): нужно повторить вызов с корректными аргументами,
а не менять стратегию и не объяснять неудачу выдуманным ограничением. Скриншоты и ассеты
для просмотра — через `analyze_image` по прямой ссылке ассета, не через Read.

Комментарии к файлу MCP-сервер не отдаёт, а OAuth-токен моста на REST-эндпоинте даёт
403 «Invalid scope» (его скоуп — только `mcp:connect`). Читать комментарии —
`~/.zcode/cli/figma-mcp/get_comments.sh <file-key|figma-url>` (personal access token
в `~/.zcode/cli/figma-mcp/rest_token`; если файла нет — попросить пользователя создать
токен на figma.com/settings → Personal access tokens и сохранить туда). Ответ содержит
тексты, позиции пинов (`client_meta`) и `frame_id` — их и сопоставлять с макетом.

## Library/API documentation

Prioritize use of Context7 MCP instead of web searching for Library/API documentation access.

## In-app browser — ожидание загрузки

Локальные dev-страницы тяжёлые: навигация и `domcontentloaded` не гарантируют, что целевой
элемент уже отрисовался (turbolinks и Vue достраивают DOM после). Не делай вывод «пользователь
закрыл или сдвинул страницу», если целевой элемент не найден, — почти всегда страница просто
ещё не доехала. Порядок: `goto` → `waitForLoadState({ state: 'load' })` → `locator(...).waitFor({ state: 'visible' })`
на конкретный целевой селектор → только потом замеры и манипуляции. Навигацию и замер держи
в одном вызове: таймаут навигации оставляет страницу в промежуточном состоянии, и следующий
вызов в свежем kernel меряет не ту страницу.

Локальная админка требует залогиненного сеанса: перед работой со страницами `kladovkin.local`
во встроенном браузере захожу на `https://kladovkin.local/log_in/dev@dev.dev` (dev-вход без
пароля) — без него `/admin`-страницы открываются пустыми, без данных и рядов. CSS-пак
`kladovkin.local` браузер кеширует агрессивно: после пересборки `admin.sass` сначала
`fetch('/packs/css/admin.css', {cache: 'reload'})` в контексте страницы и только потом reload —
иначе страница меряется со старыми стилями.

## Artifacts

Когда я прошу сделать «артефакт», опубликовать страницу/дашборд/отчёт/визуализацию с публичной ссылкой, либо обновить, откатить или удалить существующий артефакт — работай по скилу `artifact-builder` (источник `~/develop/work/artifacts/skills/artifact-builder/`, подключён симлинками в каталоги скилов): публикуй через MCP-сервер `artifacts` (`mcp__artifacts__*`), а не сохраняй HTML-файлы в репозитории или dotfiles, и выдавай мне публичную ссылку (`<base>/a/<name>`). Визуальный стиль по умолчанию — объединённая система из скила («The default design»: editorial-скаффолд stone/slate от Matt Pocock × принципы формирования от Anthropic frontend-design, пластины кода Shiki catppuccin-frappe, диаграммы mermaid+ELK neutral, база `:root 18px` с размерами в rem): применяй её всегда, без явной просьбы с моей стороны; фирменный стиль Claude (`claude-brand.md` в скиле) — только когда я явно попрошу. Дизайн-крафт — по гайдам скила (симлинки на anthropics/skills в submodule `vendor/anthropic-skills` репо artifacts; обновляются автоматически раз в неделю launchd-агентом `com.morr.update-artifact-guides`, вручную — `~/dotfiles/bin/update-artifact-guides`). Эталонный артефакт дефолтного стиля — `8703-plan-matt-claude`.
