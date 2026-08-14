#!/bin/bash
#
# Перебирает стратегии tpws для порта 443 и выбирает рабочую — на случай, когда
# провайдер меняет DPI и записанная в config_custom стратегия перестаёт брать
# сайты. Скрипт по очереди подставляет каждого кандидата в config_custom,
# перезапускает сервис (без пароля — правило sudoers) и замеряет, открываются ли
# заблокированные хосты. В конце показывает таблицу и предлагает применить лучшую.
#
# Ничего необратимого по умолчанию не делает: как бы он ни завершился — по Ctrl-C,
# по ошибке или штатно без применения — исходный config_custom возвращается на
# место и сервис перезапускается с ним. Новую стратегию скрипт оставляет, только
# если ты явно согласился её применить.
#
# Прочитай README.md рядом, раздел «Подбор стратегии», прежде чем запускать:
# там про то, почему нельзя долбить заблокированный хост подряд и как читать
# результаты. Весь вывод дублируется в лог-файл.
#
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPT_DIR="/opt/darkware-zapret"
ZAPRET_CTL="$OPT_DIR/init.d/macos/zapret"
CONFIG="$OPT_DIR/config_custom"
TEMPLATE="$DOTFILES_DIR/config_custom.working"
TPWS_BIN="$OPT_DIR/tpws/tpws"
CHROME_BIN="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LOG_FILE="$HOME/dpi-bypass-tuning-$(date +%Y%m%d-%H%M%S).log"

# ─────────────────────────── кандидаты для 443 ───────────────────────────
# Список намеренно короткий: каждый кандидат — это по одному TLS-хендшейку к
# каждому целевому хосту, а после ~15 подряд провайдер режет хост наглухо на
# час-другой (README, «Тупики»). Порядок — от текущей рабочей к более редким.
# Правится руками: подставляется между `--filter-tcp=443` и `<HOSTLIST>`.
# Только сокетные приёмы — на macOS пакетных (TTL/MSS/десинк ответа) нет.
STRATEGIES=(
    "--split-pos=midsld --disorder"          # текущая рабочая
    "--split-pos=1,midsld --disorder"        # дефолт GUI — берёт YouTube
    "--split-pos=midsld"                      # split в обычном порядке
    "--split-pos=1 --disorder"
    "--split-pos=2 --disorder"
    "--split-pos=sniext+1 --disorder"        # разрез по расширению SNI
    "--split-pos=host+1 --disorder"          # разрез сразу после имени хоста
    "--split-pos=midsld --oob"               # out-of-band байт вместо переупорядочивания
    "--split-pos=1,midsld --disorder --oob"
)

# Целевые хосты — те, что SNI-блокировкой режутся, но чинятся обходом (в README
# они в «работает»). rutracker/x.com/discord сюда не годятся: их душат по входящему
# потоку, обходом не лечится, они провалят любую стратегию и только испортят замер.
# Добавить ещё цели можно флагом --host (тогда хендшейки размажутся по нескольким).
TARGETS=(www.youtube.com)
# Контрольный хост — не в блок-листе, идёт через tpws нетронутым и обязан
# отвечать всегда. Если он не отвечает, значит лёг сам туннель или DNS, и
# провал целей в этом прогоне ничего не говорит о стратегии.
CONTROL=example.com

PAUSE=8              # пауза между замерами, чтобы не долбить хост подряд
CURL_TIMEOUT=15
MIN_SIZE=2000        # 200 с телом меньше этого — подозрение на заглушку
DRY_RUN=0
ASSUME_YES=0
USE_CHROME=1
CUSTOM_TARGETS=()

usage() {
    cat <<EOF
Использование: $0 [опции]

Перебирает стратегии tpws для 443 и выбирает рабочую. По умолчанию —
измеряет, показывает таблицу и спрашивает, применять ли лучшую.

  --host HOST        целевой хост (можно повторять; заменяет список по умолчанию:
                     ${TARGETS[*]})
  --control HOST     контрольный незаблокированный хост (по умолчанию $CONTROL)
  --pause SEC        пауза между замерами (по умолчанию $PAUSE)
  --timeout SEC      таймаут curl на запрос (по умолчанию $CURL_TIMEOUT)
  --min-size BYTES   минимум тела при коде 200, иначе считаем заглушкой (по умолчанию $MIN_SIZE)
  --no-chrome        не перепроверять победителя через headless Chrome
  --dry-run          только измерить и показать, ничего не применять
  --yes              применить лучшую стратегию без вопроса
  -h, --help         эта справка

Без единого ключа скрипт спросит, что делать, сам. Любой переданный ключ отключает
опрос. Исходный config_custom при любом исходе возвращается на место; новая стратегия
остаётся, только если ты согласился её применить. Лог: ~/dpi-bypass-tuning-*.log
EOF
}

# Без аргументов — интерактивный режим: спросим план перед перебором. Любой ключ
# опрос отключает (как в uninstall.sh).
ASK=0
[ $# -eq 0 ] && ASK=1

while [ $# -gt 0 ]; do
    case "$1" in
        --host)     CUSTOM_TARGETS+=("$2"); shift 2 ;;
        --control)  CONTROL="$2"; shift 2 ;;
        --pause)    PAUSE="$2"; shift 2 ;;
        --timeout)  CURL_TIMEOUT="$2"; shift 2 ;;
        --min-size) MIN_SIZE="$2"; shift 2 ;;
        --no-chrome) USE_CHROME=0; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        --yes)      ASSUME_YES=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) printf 'Неизвестный аргумент: %s (см. --help)\n' "$1"; exit 1 ;;
    esac
done
[ "${#CUSTOM_TARGETS[@]}" -gt 0 ] && TARGETS=("${CUSTOM_TARGETS[@]}")

exec > >(tee -a "$LOG_FILE") 2>&1

# ─────────────────────────────── хелперы вывода ───────────────────────────────

info() { printf '        %s\n' "$1"; }
ok()   { printf '  [ОК]  %s\n' "$1"; }
skip() { printf ' [ПРОП] %s\n' "$1"; }
warn() { printf ' [ВНИМ] %s\n' "$1"; }
step() {
    printf '\n══════════════════════════════════════════════════════════════════\n'
    printf '%s\n' "$1"
    printf '══════════════════════════════════════════════════════════════════\n'
}
die() {
    printf '\n  [СБОЙ] %s\n' "$1"
    printf '  Лог: %s\n\n' "$LOG_FILE"
    exit 1
}
run() {
    local quoted=""
    for a in "$@"; do quoted="$quoted $(printf '%q' "$a")"; done
    printf '      $%s\n' "$quoted"
    "$@"
}

# Вопрос да/нет. ask_yes_no "вопрос" y|n(по умолчанию). Возвращает 0 на "да".
ask_yes_no() {
    local prompt="$1" default="$2" hint='[Y/n]' answer
    [ "$default" = "n" ] && hint='[y/N]'
    while true; do
        printf '  %s %s ' "$prompt" "$hint"
        read -r answer </dev/tty || answer=""
        [ -z "$answer" ] && answer="$default"
        case "$answer" in
            y|Y|yes|да|д|Д) return 0 ;;
            n|N|no|нет|н|Н) return 1 ;;
            q|Q) printf '\n  Отменено, ничего не изменено.\n\n'; exit 0 ;;
            *) printf '  Не понял ответ. Нужно y или n (Enter — вариант по умолчанию, q — выход).\n' ;;
        esac
    done
}

# ────────────────────────── проверки окружения ──────────────────────────

[ "$(uname -s)" = "Darwin" ] || die "скрипт только для macOS"
[ -x "$ZAPRET_CTL" ] || die "сервис zapret не установлен ($ZAPRET_CTL нет) — сперва ./install.sh"
[ -f "$CONFIG" ] || die "нет $CONFIG — сервис установлен не полностью"
[ -f "$TEMPLATE" ] || die "рядом нет config_custom.working — запусти из каталога dpi-bypass-macos"
command -v curl >/dev/null 2>&1 || die "нет curl"

# ──────────────────── интерактивный опрос (если без ключей) ────────────────────
# Спрашиваем план до запроса пароля sudo и до trap: выход по «q» здесь ничего
# не откатывает, потому что менять ещё нечего.

if [ "$ASK" -eq 1 ]; then
    step "Что делать"
    info "Перебор стратегий tpws для 443 на установленном сервисе. По каждому кандидату"
    info "правится config_custom и перезапускается сервис — это рвёт текущие соединения."
    info "Найду рабочую — в конце спрошу, применять ли её. «q» в вопросе — выход."
    printf '\n'

    if ! ask_yes_no "Мерить на стандартных целях (${TARGETS[*]})?" y; then
        printf '  Впиши хосты через пробел (сейчас заблокированы, но должны чиниться обходом): '
        read -r line </dev/tty || line=""
        if [ -n "$line" ]; then
            TARGETS=($line)
            info "цели: ${TARGETS[*]}"
        else
            info "ничего не ввёл — оставляю стандартные: ${TARGETS[*]}"
        fi
    fi

    if [ ! -x "$CHROME_BIN" ]; then
        USE_CHROME=0
    elif ! ask_yes_no "Перепроверять победителя через headless Chrome?" y; then
        USE_CHROME=0
    fi
fi

# Перезапуск сервиса должен идти без пароля — иначе перебор будет спрашивать его
# на каждом кандидате. Проверяем право заранее и, если надо, поднимаем сессию.
if ! sudo -n -l "$ZAPRET_CTL" >/dev/null 2>&1 && ! sudo -n true 2>/dev/null; then
    info "нужен пароль для перезапуска сервиса (один раз, дальше по правилу sudoers — без него)"
    sudo -v || die "без прав администратора перезапускать сервис нельзя"
fi

# ─────────────────────── сохранение исходного состояния ───────────────────────

ORIG_CONFIG="$(mktemp /tmp/dpi-tuning-orig.XXXXXX)"
cp "$CONFIG" "$ORIG_CONFIG"
ORIG_443="$(grep -m1 '^--filter-tcp=443' "$ORIG_CONFIG" | sed -E 's/^--filter-tcp=443 (.*) <HOSTLIST>.*/\1/')"
APPLIED=0   # ставится в 1, только когда мы намеренно оставляем новую стратегию

# Пишет переданное содержимое в config_custom (файл наш после харденинга, но на
# всякий случай умеем и через sudo) и перезапускает сервис. Возвращает 0, если
# tpws поднялся, иначе 1 — кандидат с битой опцией не уронит весь прогон.
apply_config() {
    local content="$1" tmp
    tmp="$(mktemp /tmp/dpi-tuning-cfg.XXXXXX)"
    printf '%s\n' "$content" > "$tmp"
    if ! cp "$tmp" "$CONFIG" 2>/dev/null; then
        sudo cp "$tmp" "$CONFIG" && sudo chown "$USER" "$CONFIG"
    fi
    rm -f "$tmp"
    sudo "$ZAPRET_CTL" restart >/dev/null 2>&1 || true
    local waited=0
    while [ "$waited" -lt 15 ]; do
        pgrep -f "$TPWS_BIN" >/dev/null 2>&1 && return 0
        sleep 1; waited=$((waited + 1))
    done
    return 1
}

# Собирает config_custom из эталона, подменяя только строку стратегии для 443.
config_for() {
    sed "s|^--filter-tcp=443 .*<HOSTLIST>|--filter-tcp=443 $1 <HOSTLIST>|" "$TEMPLATE"
}

restore_original() {
    [ "$APPLIED" -eq 1 ] && return 0
    printf '\n'
    info "возвращаю исходную стратегию и перезапускаю сервис"
    if ! cp "$ORIG_CONFIG" "$CONFIG" 2>/dev/null; then
        sudo cp "$ORIG_CONFIG" "$CONFIG" && sudo chown "$USER" "$CONFIG"
    fi
    sudo "$ZAPRET_CTL" restart >/dev/null 2>&1 || true
    local waited=0
    while [ "$waited" -lt 15 ]; do
        pgrep -f "$TPWS_BIN" >/dev/null 2>&1 && { ok "исходная стратегия на месте, tpws работает"; break; }
        sleep 1; waited=$((waited + 1))
    done
    pgrep -f "$TPWS_BIN" >/dev/null 2>&1 || warn "tpws не поднялся — проверь: sudo $ZAPRET_CTL start"
}
cleanup() {
    restore_original
    rm -f "$ORIG_CONFIG"
}
trap cleanup EXIT
trap 'die "прервано"' INT TERM

# ───────────────────────────────── замер ─────────────────────────────────

# Печатает "код размер время". На обрыве соединения curl не даёт вывода — тогда 000.
measure() {
    local host="$1" out
    out="$(curl -s -o /dev/null -w '%{http_code} %{size_download} %{time_total}' \
           --max-time "$CURL_TIMEOUT" "https://$host" 2>/dev/null)" || true
    [ -n "$out" ] || out="000 0 0"
    printf '%s' "$out"
}

# Хендшейк вообще прошёл — любой ответ 2xx/3xx. Для контрольного хоста этого и надо:
# он не в блок-листе, размер тела не важен (у example.com оно всего ~1.2 КБ).
is_up() {
    case "$1" in
        2[0-9][0-9]|3[0-9][0-9]) return 0 ;;
    esac
    return 1
}

# Цель реально открылась: 2xx с осмысленным телом или 3xx (редирект — TLS уже поднялся).
# Тело меряем, чтобы не принять заглушку-200 за успех, но только для целей, не контроля.
is_success() {
    local code="$1" size="$2"
    case "$code" in
        3[0-9][0-9]) return 0 ;;
        2[0-9][0-9]) [ "$size" -ge "$MIN_SIZE" ] && return 0 || return 1 ;;
    esac
    return 1
}

# ───────────────────────────── шапка прогона ─────────────────────────────

step "Подбор стратегии tpws для порта 443"
info "Лог: $LOG_FILE"
info "Текущая стратегия 443: ${ORIG_443:-неизвестна}"
info "Кандидатов: ${#STRATEGIES[@]}   Целей: ${TARGETS[*]}   Контроль: $CONTROL"
handshakes=$(( ${#STRATEGIES[@]} ))
info "На каждый целевой хост придётся до $handshakes хендшейков (по одному на кандидата)."
if [ "$handshakes" -gt 14 ]; then
    warn "это близко к порогу, после которого провайдер режет хост наглухо (~15)."
    warn "сократи список STRATEGIES в скрипте или добавь целей через --host, чтобы размазать нагрузку."
fi
info "Между замерами пауза $PAUSE с — так перебор не выглядит как долбёж одного хоста."
printf '\n'

# ─────────────────────────────── перебор ───────────────────────────────

# Параллельные массивы результатов по индексу кандидата.
R_SCORE=(); R_TIME=(); R_STATUS=(); R_DETAIL=()

first=1
for i in "${!STRATEGIES[@]}"; do
    strat="${STRATEGIES[$i]}"
    label="$strat"
    [ "$strat" = "$ORIG_443" ] && label="$strat  (текущая)"
    printf '── [%d/%d] %s\n' $((i + 1)) "${#STRATEGIES[@]}" "$label"

    if ! apply_config "$(config_for "$strat")"; then
        R_SCORE[$i]=-1; R_TIME[$i]=999; R_STATUS[$i]="tpws не стартовал"; R_DETAIL[$i]="битая опция?"
        warn "tpws не поднялся с этой стратегией — вероятно, tpws не знает такую опцию. Пропускаю."
        continue
    fi
    sleep 2   # дать соединениям устояться после рестарта

    # Контроль: если незаблокированный хост не отвечает, туннель/DNS лёг —
    # замер целей в этом раунде недостоверен.
    read -r cc cs ct <<< "$(measure "$CONTROL")"
    if ! is_up "$cc"; then
        R_SCORE[$i]=-1; R_TIME[$i]=999; R_STATUS[$i]="контроль не отвечает"; R_DETAIL[$i]="$CONTROL код $cc"
        warn "контрольный $CONTROL не открылся (код $cc) — пропускаю, замер был бы мусором"
        [ "$first" -eq 0 ] && sleep "$PAUSE"; first=0
        continue
    fi

    score=0; sumtime=0; detail=""
    for host in "${TARGETS[@]}"; do
        [ "$first" -eq 0 ] && sleep "$PAUSE"; first=0
        read -r hc hs ht <<< "$(measure "$host")"
        if is_success "$hc" "$hs"; then
            score=$((score + 1))
            # целочисленные миллисекунды для сортировки без bc
            ms=$(awk "BEGIN{printf \"%d\", ($ht)*1000}" 2>/dev/null || echo 0)
            sumtime=$((sumtime + ${ms:-0}))
            detail="$detail ${host%%.*}:ok/${hs}b/${ht}s"
            printf '        %-22s код %s  %8s байт  %ss  ✓\n' "$host" "$hc" "$hs" "$ht"
        else
            detail="$detail ${host%%.*}:FAIL/$hc"
            printf '        %-22s код %s  %8s байт  %ss  ✗\n' "$host" "$hc" "$hs" "$ht"
        fi
    done
    R_SCORE[$i]=$score; R_TIME[$i]=$sumtime; R_STATUS[$i]="ok"; R_DETAIL[$i]="${detail# }"
    printf '        итог: %d/%d целей\n' "$score" "${#TARGETS[@]}"
done

# ───────────────────────────── выбор лучшей ─────────────────────────────

step "Результаты (отсортированы: больше взятых целей, при равенстве — быстрее)"

# Индексы, отсортированные по (score убыв., time возр.). Пузырьком — кандидатов единицы.
order=("${!STRATEGIES[@]}")
n=${#order[@]}
for ((a = 0; a < n; a++)); do
    for ((b = 0; b < n - a - 1; b++)); do
        x=${order[$b]}; y=${order[$((b + 1))]}
        swap=0
        if [ "${R_SCORE[$y]}" -gt "${R_SCORE[$x]}" ]; then swap=1
        elif [ "${R_SCORE[$y]}" -eq "${R_SCORE[$x]}" ] && [ "${R_TIME[$y]}" -lt "${R_TIME[$x]}" ]; then swap=1
        fi
        if [ "$swap" -eq 1 ]; then order[$b]=$y; order[$((b + 1))]=$x; fi
    done
done

printf '  %-4s %-40s %s\n' "цел" "стратегия" "детали"
printf '  ─────────────────────────────────────────────────────────────────\n'
for i in "${order[@]}"; do
    sc="${R_SCORE[$i]}"
    [ "$sc" -lt 0 ] && cel="—" || cel="$sc/${#TARGETS[@]}"
    mark=" "
    [ "${STRATEGIES[$i]}" = "$ORIG_443" ] && mark="•"
    printf '%s %-4s %-40s %s\n' "$mark" "$cel" "${STRATEGIES[$i]}" "${R_STATUS[$i]}: ${R_DETAIL[$i]}"
done
printf '  (• — стратегия, что стоит сейчас)\n'

best=${order[0]}
best_score=${R_SCORE[$best]}
best_strat="${STRATEGIES[$best]}"

if [ "$best_score" -le 0 ]; then
    printf '\n'
    warn "ни одна стратегия не взяла ни одной цели."
    info "Скорее всего либо цели сейчас режутся по IP/входящему потоку (обходом не лечится),"
    info "либо провайдер уже прижал хосты за частые хендшейки — тогда подожди час-другой и повтори."
    info "Стратегию не меняю. Проверь ещё и вручную в Chrome (README, «Правила работы со стендом»)."
    exit 0
fi

printf '\n'
ok "лучшая: $best_strat  ($best_score/${#TARGETS[@]} целей)"

if [ "$best_strat" = "$ORIG_443" ]; then
    ok "это и есть текущая стратегия — менять нечего, она по-прежнему лучшая из проверенных."
    exit 0
fi

# ─────────────────── перепроверка победителя через Chrome ───────────────────
# curl и Chrome ломаются по-разному (разный ClientHello), поэтому победителя по
# curl полезно подтвердить браузером. Успех Chrome меряем размером DOM, а не
# заголовком: на странице ошибки Chrome ставит заголовком имя хоста (README).
if [ "$USE_CHROME" -eq 1 ] && [ -x "$CHROME_BIN" ]; then
    step "Перепроверка победителя через headless Chrome"
    if apply_config "$(config_for "$best_strat")"; then
        sleep 2
        prof="$(mktemp -d /tmp/dpi-tuning-chrome.XXXXXX)"
        domfile="$(mktemp /tmp/dpi-tuning-dom.XXXXXX)"
        host="${TARGETS[0]}"
        chrome_wait=25
        info "гружу https://$host свежим профилем Chrome (без куки), меряю размер DOM (до $chrome_wait с)"
        # headless=new с --dump-dom иногда не выходит сам (QUIC закрыт, страница
        # добирает ресурсы), а timeout на macOS нет — сторожим вручную и добиваем
        # по уникальному пути профиля, чтобы не осталось висящих процессов Chrome.
        "$CHROME_BIN" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
            --user-data-dir="$prof" --virtual-time-budget=10000 \
            --dump-dom "https://$host" >"$domfile" 2>/dev/null &
        cpid=$!
        waited=0
        while kill -0 "$cpid" 2>/dev/null && [ "$waited" -lt "$chrome_wait" ]; do
            sleep 1; waited=$((waited + 1))
        done
        if kill -0 "$cpid" 2>/dev/null; then
            warn "Chrome не завершился за $chrome_wait с — снимаю его и пропускаю проверку"
            kill "$cpid" 2>/dev/null || true
            pkill -f "$prof" 2>/dev/null || true
            dom=0
        else
            wait "$cpid" 2>/dev/null || true
            dom="$(wc -c <"$domfile" | tr -d ' ')"
        fi
        rm -rf "$prof" "$domfile"   # профиль мог набрать куки — удаляем сразу
        if [ "${dom:-0}" -ge 5000 ]; then
            ok "Chrome отдал $dom байт DOM — победитель подтверждён браузером"
        elif [ "${dom:-0}" -eq 0 ]; then
            warn "Chrome ничего не отдал (таймаут или сбой) — браузером подтвердить не вышло"
            warn "для curl стратегия сработала; проверь вручную (README, п.2 «Правила работы со стендом»)"
        else
            warn "Chrome отдал всего $dom байт DOM — для curl стратегия сработала, для Chrome под вопросом"
            warn "проверь вручную (README, п.2 «Правила работы со стендом») прежде чем оставлять её надолго"
        fi
    else
        warn "не удалось перезапустить сервис для проверки Chrome — пропускаю"
    fi
fi

# ───────────────────────────── применение ─────────────────────────────

step "Применение"
if [ "$DRY_RUN" -eq 1 ]; then
    info "--dry-run: ничего не меняю. Чтобы применить лучшую, запусти без --dry-run."
    info "Или впиши строку 443 вручную в $CONFIG:"
    info "  --filter-tcp=443 $best_strat <HOSTLIST>"
    exit 0
fi

apply=0
if [ "$ASSUME_YES" -eq 1 ]; then
    apply=1
else
    printf '  Применить «%s» и перезапустить сервис? [y/N]: ' "$best_strat"
    read -r ans </dev/tty || ans=""
    case "$ans" in y|Y|yes|Yes) apply=1 ;; esac
fi

if [ "$apply" -eq 1 ]; then
    if apply_config "$(config_for "$best_strat")"; then
        APPLIED=1   # cleanup не станет откатывать — оставляем новую стратегию
        ok "стратегия применена: --filter-tcp=443 $best_strat"
        info "Если хочешь сделать её эталоном на будущее — впиши ту же строку 443 в"
        info "  $TEMPLATE  (тогда install.sh будет ставить уже её)."
        info "Прежняя стратегия была: --filter-tcp=443 ${ORIG_443:-?}"
    else
        warn "не удалось применить — откатываю на исходную (сделает cleanup)"
    fi
else
    info "оставляю как было — исходную стратегию вернёт cleanup."
fi
