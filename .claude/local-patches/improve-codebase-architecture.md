# Патчи: improve-codebase-architecture

Два независимых патча на один скилл. Накладывать оба.

---

# Патч 1: отчёт публикуется артефактом

**Цель патча:** отчёт архитектурного ревью отдаётся пользователю как Claude Artifact
(приватная хостовая страница с ссылкой), а не как HTML-файл в OS temp, открываемый `open`.

Наложить на: `~/.claude/skills/improve-codebase-architecture/`
(файлы `SKILL.md` и `HTML-REPORT.md`).

## Что делает апстрим

1. `SKILL.md`, шаг «2. Present candidates as an HTML report» велит писать self-contained HTML
   в OS temp (`$TMPDIR` → `/tmp` → `%TEMP%`), открывать его `xdg-open`/`open`/`start`
   и сообщать пользователю абсолютный путь.
2. Тот же абзац и весь `HTML-REPORT.md` построены на **Tailwind через CDN**
   (`https://cdn.tailwindcss.com`) и **Mermaid через CDN**
   (`https://cdn.jsdelivr.net/npm/mermaid@11/...esm.min.mjs`), а вся вёрстка описана
   утилитарными классами Tailwind (`bg-stone-50`, `font-mono text-sm`, `h-12 border-l-4`,
   `text-xs uppercase tracking-wider` и т. п.).
3. `HTML-REPORT.md` даёт полный HTML-скелет с `<!doctype html>`, `<html>`, `<head>`, `<body>`.

## Почему это меняем

- Отчёт — законченный deliverable с аудиторией; артефакт даёт ссылку, которую видно
  с любого устройства и можно расшарить, а `/tmp`-файл живёт только на этой машине.
- **Технически апстримный HTML артефактом работать не может:** CSP артефактов режет любые
  внешние хосты, поэтому Tailwind и Mermaid с CDN не загрузятся — страница выйдет без стилей
  и без диаграмм. Именно поэтому патч не сводится к «вызови Artifact вместо open»:
  Tailwind надо заменить на инлайновый CSS, а Mermaid убрать вовсе — вьюер артефактов
  рендерит `<pre class="mermaid">` нативно.
- Артефакт оборачивает файл в свой `<!doctype html>…<head></head><body>`, так что собственные
  `<!DOCTYPE>`/`<html>`/`<head>`/`<body>` в файле быть не должны.
- Артефакт рендерится в теме зрителя → палитра должна быть на CSS-переменных с dark-оверрайдами.

## Правки

### SKILL.md

1. Во фронтматтере `description`: `present them as a visual HTML report`
   → `publish them as a visual HTML artifact`.

2. Шаг 2, первые два абзаца (про temp dir и про «uses Tailwind via CDN … Mermaid via CDN»)
   заменить на:

   - публикацию через инструмент `Artifact`: сначала загрузить скилл `artifact-design`,
     затем писать self-contained HTML в скратчпад сессии
     (`<scratchpad>/architecture-review-<timestamp>.html`, чтобы ничего не попало в репо),
     затем `Artifact` с этим `file_path` + `description` + `favicon`;
     сообщить пользователю URL артефакта;
     повторный `Artifact` с тем же `file_path` передеплоивает на тот же URL — так и делать
     правки, а не плодить новый файл;
   - требование self-contained: CSP блокирует внешние хосты, поэтому никакого Tailwind CDN
     и никакого импорта Mermaid — весь CSS инлайном в `<style>`, диаграммы через
     `<pre class="mermaid">` (вьюер рендерит их сам).

   Абзац про «Mix Mermaid with hand-crafted CSS/SVG visuals… Be visual.» сохранить.

3. В конце шага 2: `After the file is written` → `After the artifact is published`.
   Остаток этой строки (сам вопрос о кандидате) переписывает патч 2 — итоговый вид
   смотреть там.

### HTML-REPORT.md

1. Вступление: вместо «single self-contained HTML file in the OS temp directory. Tailwind and
   Mermaid both come from CDNs» — публикация через `Artifact`, **никаких внешних ресурсов**
   (CDN-тег молча даёт страницу без стилей), CSS инлайном, Mermaid не импортируется вовсе.
   Добавить требование загрузить `artifact-design` перед написанием файла.

2. Секция «Scaffold»: выкинуть `<!doctype html>`/`<html>`/`<head>`/`<body>`,
   `<script src="https://cdn.tailwindcss.com">` и mermaid-ESM-импорт. Новый скелет:
   `<title>` первым (короткое имя вида `Architecture review — {{repo}}`), затем инлайновый
   `<style>` с токенами палитры на голом `:root`, dark-оверрайдами в
   `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { … } }`
   **и** в `:root[data-theme="dark"]`, явным фоном на `body`; затем `<main>` с секциями
   `header` / `#candidates` / `#top-recommendation`.
   Оговорить, что палитра — стартовая точка, а не house style: финальную выбирает
   проход `artifact-design`.
   Добавить абзац про респонсивность: горизонтального скролла у body быть не должно,
   широкое (Mermaid, длинные списки файлов, таблицы) — в контейнер с `overflow-x: auto`,
   before/after-грид схлопывается в одну колонку на узком вьюпорте.

3. Везде заменить утилитарные классы Tailwind на собственные семантические классы,
   объявленные в том же `<style>`: `.card`, `.files`, `.badge`, `.label`, `.adr`,
   `.beforeafter`, `.scroll` (плюс сохранённые из апстрима `.seam`, `.leak`, `.deep`).
   Затронуты: «Candidate card» (`font-mono text-sm` → `.files`,
   `amber-tinted box` → `.adr`), «Cross-section» (`h-12 border-l-4` → описание словами),
   «Style guidance» (`text-xs uppercase tracking-wider` → `.label`).

4. Пример Mermaid: убрать обёртку из Tailwind-классов, оставить `<div class="card scroll">`.
   Пояснить, что скрипта и импорта нет, а тему задавать директивой первой строкой самой
   диаграммы — `%%{init: {'theme':'neutral'}}%%` — потому что `mermaid.initialize()` вызвать
   негде; цвета `classDef` должны читаться и на светлом, и на тёмном фоне.

5. «Hand-built boxes-and-arrows»: добавить, что stroke/fill берутся из CSS-переменных
   (`stroke: var(--ink)`), а не литеральные `black`/`#000`.

6. «Style guidance»: пункт «The only scripts are the Tailwind CDN and the Mermaid ESM import»
   заменить на «страница статична, никаких скриптов, шрифтов и картинок с внешних хостов»;
   добавить, что картинка при необходимости встраивается `data:`-URI, а вся страница
   должна остаться под 16 MB.

Секции «Header», «Top recommendation», «Tone» и словарь терминов апстрима не трогать.

## Проверка

```sh
grep -rn -E 'cdn\.tailwindcss|cdn\.jsdelivr|TMPDIR|xdg-open' ~/.claude/skills/improve-codebase-architecture/
```

Должно быть пусто. Плюс в `SKILL.md` должны встречаться `Artifact`, `artifact-design`
и `scratchpad`, а в `HTML-REPORT.md` — `<pre class="mermaid">` без `<script>`.

---

# Патч 2: вопросы задаются через AskUserQuestion

**Цель патча:** решения на шаге выбора кандидата и во всём grilling-цикле собираются
инструментом `AskUserQuestion`, а не текстовым списком `❓ Q1 / ➡️`.

Наложить на: `~/.claude/skills/improve-codebase-architecture/SKILL.md`.

## Что делает апстрим

1. Шаг 2 заканчивается прозаическим вопросом: `ask the user: "Which of these would you
   like to explore?"`.
2. Шаг 3 делегирует диалог скиллу `grilling`, а тот в блоке «Format a round like so»
   жёстко задаёт текстовый формат раунда: `❓ **Q1** - **<title>**: …` и строку
   `➡️ <recommended answer>`.

## Почему это меняем

- Вопрос в чате не даёт выбрать вариант — пользователь вынужден печатать ответ прозой,
  и рекомендация тонет в тексте. `AskUserQuestion` даёт кликабельные варианты и
  сохраняет ответы структурно.
- Патчить сам `grilling` нельзя: его загружают и другие скиллы (`code-review`,
  `issue-walk`, `coderabbit`), там текстовый формат уместен. Поэтому переопределение
  живёт в шаге 3 `improve-codebase-architecture` и должно быть **явным** — образец
  формата из `grilling` уже лежит в контексте и без прямого запрета перетягивает обратно.
- Дисциплина фронтира при этом не меняется: раунд целиком, ожидание ответов,
  пересчёт фронтира. Меняется только доставка.

## Правки

### SKILL.md, шаг 2

Последнюю строку (`Do NOT propose interfaces yet. After the artifact is published, ask
the user: …`) заменить на формулировку через `AskUserQuestion`: один вопрос, вариант на
кандидата, `label` — короткое имя кандидата, `description` — сила рекомендации и причина,
Top recommendation первым с пометкой `(Recommended)`.

### SKILL.md, шаг 3

После абзаца про вызов `grilling` добавить блок, который:

- запрещает формат `❓ Q1 / ➡️` прямым текстом и оставляет в силе существо `grilling`
  (фронтир, раунд целиком, ожидание ответов);
- задаёт отображение: один вызов на раунд, решение = вопрос, `➡️` = первый вариант
  с `(Recommended)`, `header` ≤12 символов называет решение, `label` 1–5 слов,
  аргумент — в `description`, свой вариант «Other» не добавлять, `multiSelect` для
  неисключающих веток, `preview` для сравнения конкретных артефактов (только single-select);
- оговаривает потолок в 4 вопроса: широкий фронтир разбивается на несколько вызовов
  **внутри одного раунда**, а не переносится в следующий;
- отправляет обрамление (замеры, контекст, почему фронтир такой) в обычный текст
  перед вызовом.

## Проверка

```sh
grep -n 'AskUserQuestion' ~/.claude/skills/improve-codebase-architecture/SKILL.md
grep -n '❓\|➡️' ~/.claude/skills/improve-codebase-architecture/SKILL.md
```

Первый должен дать совпадения в шагах 2 и 3. Второй — ровно две строки, и обе описывают
формат, а не применяют его: строка с запретом (`grilling` prints a round as …) и строка
правила отображения (`➡️` becomes the first option). Образца раунда — блока вида
`❓ **Q1** - **<title>**:` с телом вопроса — быть не должно. Скилл `grilling` при этом
не тронут.
