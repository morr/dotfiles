#!/bin/bash
#
# Полностью снимает настройку обхода DPI, которую разворачивает install.sh рядом:
# tpws (darkware-zapret), правила PF, блокировку QUIC, шифрованный DNS
# и связанные настройки Chrome.
#
# Порядок важен: сначала системный DNS возвращается на автоматический и
# проверяется, что резолв живой, и только потом останавливается dnscrypt-proxy.
# Обратный порядок оставил бы машину без DNS.
#
# Скрипт идемпотентен: повторный запуск на уже вычищенной машине пройдёт
# целиком на "ПРОПУСК". Весь вывод дублируется в лог-файл.
#
set -Eeuo pipefail

SRC_DIR="$HOME/Library/Caches/dpi-bypass-macos"
ZAPRET_SRC="$SRC_DIR/darkware-zapret"
BYEDPI_SRC="$SRC_DIR/byedpi"
# Прежнее расположение исходников (до переезда в Caches) — на давно настроенной
# машине они лежат там, и «удалить исходники» должно означать и их тоже.
LEGACY_SRC=("$HOME/develop/darkware-zapret" "$HOME/develop/byedpi")
APP_DST="/Applications/darkware zapret.app"
OPT_DIR="/opt/darkware-zapret"
ZAPRET_CTL="$OPT_DIR/init.d/macos/zapret"
LAUNCH_DAEMON="/Library/LaunchDaemons/com.darkware.zapret.plist"
LAUNCH_LABEL="com.darkware.zapret"
SUDOERS_FILE="/etc/sudoers.d/darkware-zapret"
PF_MAIN="/etc/pf.conf"
PF_ANCHOR_DIR="/etc/pf.anchors"
APP_PREFS="$HOME/Library/Preferences/com.darkware.zapret.plist"
DNSCRYPT_DAEMON="/Library/LaunchDaemons/homebrew.mxcl.dnscrypt-proxy.plist"
CHROME_LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
LOG_FILE="$HOME/dpi-bypass-uninstall-$(date +%Y%m%d-%H%M%S).log"

KEEP_SOURCES=0
KEEP_DNSCRYPT=0
KEEP_LOGS=0
ASSUME_YES=0
# Без единого ключа скрипт спрашивает объём удаления сам: ключи нужны, чтобы
# запускать его неинтерактивно, а не чтобы держать их в голове.
ASK_OPTIONS=0
[ $# -eq 0 ] && ASK_OPTIONS=1

for arg in "$@"; do
    case "$arg" in
        --keep-sources)  KEEP_SOURCES=1 ;;
        --keep-dnscrypt) KEEP_DNSCRYPT=1 ;;
        --keep-logs)     KEEP_LOGS=1 ;;
        -y|--yes)        ASSUME_YES=1 ;;
        -h|--help)
            printf 'Использование: %s [--keep-sources] [--keep-dnscrypt] [--keep-logs] [--yes]\n\n' "$0"
            printf '  --keep-sources    не удалять исходники (darkware-zapret, byedpi) в кэше сборки\n'
            printf '  --keep-dnscrypt   оставить шифрованный DNS как есть:\n'
            printf '                    не трогать системный DNS, не останавливать и не удалять демон\n'
            printf '  --keep-logs       не удалять логи установки и работы сервиса\n'
            printf '  --yes             не спрашивать подтверждения плана удаления\n'
            printf '\nБез единого ключа скрипт спросит объём удаления сам. Любой переданный ключ\n'
            printf 'отключает опрос: остальное тогда удаляется (значения по умолчанию).\n'
            printf '\nСкрипт идемпотентен: повторный запуск на вычищенной машине ничего не ломает.\n'
            exit 0 ;;
        *) printf 'Неизвестный аргумент: %s (см. --help)\n' "$arg"; exit 1 ;;
    esac
done

STEP_NO=0
CURRENT_STEP="старт"
SUDO_KEEPALIVE_PID=""
DNSCRYPT_MAY_STOP=1      # сбрасывается, если после отката DNS резолв не поднялся
FAILED_CHECKS=()

exec > >(tee -a "$LOG_FILE") 2>&1

# ─────────────────────────────── хелперы вывода ───────────────────────────────

step() {
    STEP_NO=$((STEP_NO + 1))
    CURRENT_STEP="$1"
    printf '\n══════════════════════════════════════════════════════════════════\n'
    printf 'ШАГ %02d. %s\n' "$STEP_NO" "$1"
    printf '══════════════════════════════════════════════════════════════════\n'
}

info() { printf '        %s\n' "$1"; }
ok()   { printf '  [ОК]  %s\n' "$1"; }
skip() { printf ' [ПРОП] %s\n' "$1"; }
warn() { printf ' [ВНИМ] %s\n' "$1"; }

die() {
    printf '\n  [СБОЙ] %s\n' "$1"
    if [ $# -gt 1 ]; then
        printf '\n  Что нужно сделать:\n'
        printf '    %s\n' "$2"
    fi
    printf '\n  Шаг: %s\n  Лог: %s\n' "$CURRENT_STEP" "$LOG_FILE"
    printf '  Пришли лог целиком — по нему видно, на чём именно остановились.\n\n'
    exit 1
}

# Печатает команду перед выполнением, чтобы лог был воспроизводим.
# Аргументы экранируются, иначе пробелы в путях теряются и команду
# из лога нельзя скопировать как есть.
run() {
    local quoted=""
    for a in "$@"; do quoted="$quoted $(printf '%q' "$a")"; done
    printf '      $%s\n' "$quoted"
    "$@"
}

# dig возвращает 0 и при пустом ответе, поэтому проверяем, что адрес реально пришёл.
system_resolves() {
    dig +short +time=2 +tries=1 example.com 2>/dev/null | grep -qE '^[0-9]+\.'
}

# Ждёт выполнения условия. retry_until "описание" таймаут команда...
retry_until() {
    local desc="$1" timeout="$2"; shift 2
    local waited=0
    printf '      жду: %s (до %s с)' "$desc" "$timeout"
    while [ "$waited" -lt "$timeout" ]; do
        if "$@" >/dev/null 2>&1; then
            printf ' — дождались за %s с\n' "$waited"
            return 0
        fi
        printf '.'
        sleep 3
        waited=$((waited + 3))
    done
    printf ' — НЕ дождались\n'
    return 1
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

# Шаг, требующий действий пользователя. После подтверждения проверяет результат
# и не пропускает дальше, пока проверка не пройдена.
confirm_gui_step() {
    local instructions="$1" verify_fn="$2" answer
    while true; do
        printf '\n  ──── ТРЕБУЕТСЯ ТВОЁ ДЕЙСТВИЕ ────\n'
        printf '%s\n' "$instructions"
        printf '  ─────────────────────────────────\n'
        printf '  Сделал? Enter — проверю. "s" — пропустить шаг. "q" — прервать: '
        read -r answer </dev/tty || answer=""
        case "$answer" in
            q|Q) die "Прервано пользователем на шаге: $CURRENT_STEP" ;;
            s|S) warn "шаг пропущен по твоей просьбе — настройка останется частично"; return 0 ;;
        esac
        printf '  Проверяю...\n'
        if "$verify_fn"; then
            ok "проверка пройдена"
            return 0
        fi
        warn "проверка не прошла — см. строки выше. Доделай и нажми Enter ещё раз."
    done
}

cleanup() {
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap cleanup EXIT

on_error() {
    printf '\n  [СБОЙ] команда завершилась с ошибкой (строка %s)\n' "$1"
    printf '  Шаг: %s\n  Лог: %s\n' "$CURRENT_STEP" "$LOG_FILE"
    printf '  Удаление могло остаться незавершённым — повторный запуск скрипта безопасен\n'
    printf '  и продолжит с того места, где что-то ещё осталось.\n'
    printf '  Пришли лог целиком.\n\n'
}
trap 'on_error $LINENO' ERR

# ────────────────────────────── общая информация ──────────────────────────────

printf '\n'
printf 'Удаление настройки обхода DPI на macOS\n'
printf 'Лог пишется в: %s\n\n' "$LOG_FILE"
printf 'Окружение:\n'
sw_vers | sed 's/^/  /'
printf '  Пользователь: %s\n' "$USER"
printf '  Дата: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
if [ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ]; then
    printf '  Прокси в окружении: обнаружен, снимаю на время работы скрипта\n'
fi
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy

[ "$(uname -s)" = "Darwin" ] || die "скрипт только для macOS, здесь $(uname -s)"
[ "${EUID:-$(id -u)}" -ne 0 ] || die "не запускай через sudo — пароль скрипт спросит сам, когда понадобится"

# ────────────────────────────── опрос об объёме ───────────────────────────────

if [ "$ASK_OPTIONS" -eq 1 ]; then
    step "Объём удаления"
    info "Ключей не передано — спрошу по каждому пункту. Enter соглашается с вариантом"
    info "в скобках, «q» выходит, ничего не изменив. Неинтерактивно: см. --help."
    printf '\n'
    ask_yes_no "Вернуть системный DNS на автоматический и снести dnscrypt-proxy?" y \
        || KEEP_DNSCRYPT=1
    ask_yes_no "Удалить исходники сборки (darkware-zapret, byedpi)?" y \
        || KEEP_SOURCES=1
    ask_yes_no "Удалить логи установки и работы сервиса (в них есть имена посещённых сайтов)?" y \
        || KEEP_LOGS=1
    printf '\n'
    ok "объём выбран, ниже — что из этого получилось"
fi

# ────────────────────────────── план и подтверждение ──────────────────────────

step "Что будет удалено"
printf '\n'
printf '  Системное:\n'
printf '    • сервис и все файлы в %s\n' "$OPT_DIR"
printf '    • LaunchDaemon %s\n' "$LAUNCH_DAEMON"
printf '    • правило sudoers %s\n' "$SUDOERS_FILE"
printf '    • якоря PF (%s/zapret, zapret-v4, zapret-v6) и их строки в %s\n' "$PF_ANCHOR_DIR" "$PF_MAIN"
printf '    • приложение %s и его настройки\n' "$APP_DST"
printf '  Chrome:\n'
printf '    • политика QuicAllowed; флаг enable-quic вернуть в Default попрошу тебя вручную\n'
printf '  DNS:\n'
if [ "$KEEP_DNSCRYPT" -eq 1 ]; then
    printf '    • НЕ трогаю (--keep-dnscrypt): системный DNS и dnscrypt-proxy остаются как есть\n'
else
    printf '    • системный DNS возвращается на автоматический, затем демон dnscrypt-proxy\n'
    printf '      останавливается, конфигурация восстанавливается из .bak, пакет удаляется\n'
fi
printf '  Исходники:\n'
if [ "$KEEP_SOURCES" -eq 1 ]; then
    printf '    • НЕ трогаю (--keep-sources)\n'
else
    printf '    • %s (darkware-zapret, byedpi)\n' "$SRC_DIR"
    for d in "${LEGACY_SRC[@]}"; do
        [ -d "$d" ] && printf '    • %s — от прежней установки\n' "$d" || true
    done
fi
printf '  Логи:\n'
if [ "$KEEP_LOGS" -eq 1 ]; then
    printf '    • НЕ трогаю (--keep-logs)\n'
else
    printf '    • /tmp/darkware-zapret.*.log, /tmp/tpws.log, ~/dpi-bypass-install-*.log\n'
    printf '      (лог самого удаления остаётся)\n'
fi
printf '\n  Не трогаю: Homebrew, Command Line Tools, Google Chrome.\n'

if [ "$ASSUME_YES" -eq 0 ]; then
    printf '\n  Продолжить? "y" — да, что угодно другое — выход: '
    read -r answer </dev/tty || answer=""
    case "$answer" in
        y|Y|yes|да) ;;
        *) printf '\n  Отменено, ничего не изменено.\n\n'; exit 0 ;;
    esac
fi

# ──────────────────────────────── права sudo ────────────────────────────────

step "Права администратора"
info "Пароль нужен для удаления из /opt, /Library, /etc и остановки демона DNS."
info "Система может переспросить его ещё раз посреди работы — это нормально."
if sudo -n true 2>/dev/null; then
    ok "sudo уже активен"
else
    sudo -v || die "без прав администратора удаление невозможно"
fi
# Именно -v: он продлевает отметку времени явно, а не как побочный эффект команды.
( while true; do sudo -n -v 2>/dev/null || exit; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
ok "сессия sudo получена"

# ═══════════════════ ФАЗА A — DNS (обязательно первым делом) ════════════════

step "Возврат системного DNS на автоматический"
if [ "$KEEP_DNSCRYPT" -eq 1 ]; then
    skip "запрошено ключом --keep-dnscrypt — системный DNS остаётся на 127.0.0.1"
else
    info "Делаем это ДО остановки dnscrypt-proxy: иначе система осталась бы без резолвера."
    changed=0
    while IFS= read -r svc; do
        case "$svc" in
            *"An asterisk"*|"") continue ;;
        esac
        svc="${svc#\*}"
        current="$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ' || true)"
        # «There aren't any DNS Servers set on X» — это и есть автоматический DNS,
        # но целой фразой в отчёте оно читается как поломка.
        case "$current" in *"aren't any"*) current="не задан" ;; esac
        if [ "${current% }" = "127.0.0.1" ]; then
            info "$svc: 127.0.0.1 → Empty"
            sudo networksetup -setdnsservers "$svc" Empty 2>/dev/null \
                || warn "$svc: не удалось сбросить DNS (сервис неактивен?)"
            changed=1
        elif [ "$current" = "не задан" ]; then
            skip "$svc: DNS уже автоматический"
        else
            skip "$svc: DNS не наш (${current% }) — не трогаю"
        fi
    done < <(networksetup -listallnetworkservices)
    [ "$changed" -eq 1 ] || skip "ни один сетевой сервис не смотрел на 127.0.0.1"

    info "Проверяю, что резолв работает уже без локального резолвера."
    if retry_until "ответ системного DNS" 30 system_resolves; then
        ok "DNS живой — можно останавливать dnscrypt-proxy"
    else
        DNSCRYPT_MAY_STOP=0
        warn "DNS не отвечает после отката — НЕ останавливаю dnscrypt-proxy, чтобы не остаться без резолва"
        info "Разберись с сетью (DHCP выдаёт DNS?), потом запусти скрипт ещё раз."
        FAILED_CHECKS+=("после отката DNS не резолвится — dnscrypt-proxy оставлен работать")
    fi
fi

step "Остановка и удаление dnscrypt-proxy"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"
DNSCRYPT_TOML="$BREW_PREFIX/etc/dnscrypt-proxy.toml"
if [ "$KEEP_DNSCRYPT" -eq 1 ]; then
    skip "запрошено ключом --keep-dnscrypt"
elif [ "$DNSCRYPT_MAY_STOP" -eq 0 ]; then
    skip "пропускаю: без него сейчас не будет DNS (см. предыдущий шаг)"
elif ! command -v brew >/dev/null 2>&1; then
    skip "Homebrew не найден — нечего останавливать"
else
    KEEP_TOML=0
    if brew list dnscrypt-proxy >/dev/null 2>&1; then
        # Наличие LaunchDaemon — тот же факт, что «brew services list» под sudo,
        # но без лишнего запроса пароля.
        if [ -f "$DNSCRYPT_DAEMON" ]; then
            run sudo brew services stop dnscrypt-proxy || warn "не удалось остановить сервис — проверь: sudo brew services list"
        else
            skip "сервис не запущен"
        fi
        if [ -f "$DNSCRYPT_TOML.bak" ]; then
            run sudo mv "$DNSCRYPT_TOML.bak" "$DNSCRYPT_TOML"
            ok "конфигурация восстановлена из .bak"
            KEEP_TOML=1
        else
            skip "резервной копии конфигурации нет — удалю конфигурацию вместе с пакетом"
        fi
        info "brew сейчас может сказать «Could not remove keg» — это ожидаемо, дочищу сам."
        brew uninstall dnscrypt-proxy || warn "brew не смог доудалить пакет — дочищаю вручную"
        # Штатная ситуация, а не сбой: формула кладёт бинарник в keg в sbin,
        # принадлежащий root (демону нужен порт 53), и удалить такой каталог
        # brew из-под пользователя не может — он честно просит сделать это руками.
        CELLAR="$(brew --cellar dnscrypt-proxy 2>/dev/null || true)"
        [ -n "$CELLAR" ] || CELLAR="$BREW_PREFIX/Cellar/dnscrypt-proxy"
        if [ -d "$CELLAR" ]; then
            info "в keg остались файлы root (sbin/dnscrypt-proxy) — удаляю через sudo"
            run sudo rm -rf "$CELLAR"
        fi
        if brew list --versions dnscrypt-proxy >/dev/null 2>&1; then
            warn "brew всё ещё считает пакет установленным — проверь: brew list --versions dnscrypt-proxy"
        else
            ok "пакет удалён"
        fi
        # Конфигурацию в etc brew при удалении не трогает никогда.
        if [ "$KEEP_TOML" -eq 0 ] && [ -f "$DNSCRYPT_TOML" ]; then
            if rm -f "$DNSCRYPT_TOML" 2>/dev/null; then
                ok "конфигурация удалена: $DNSCRYPT_TOML"
            else
                run sudo rm -f "$DNSCRYPT_TOML"
            fi
        fi
    else
        skip "пакет не установлен"
    fi
    # brew services снимает свой LaunchDaemon сам, но если он остался —
    # демон поднимется снова при следующей загрузке, уже без конфигурации.
    if [ -f "$DNSCRYPT_DAEMON" ]; then
        warn "LaunchDaemon dnscrypt-proxy остался — снимаю вручную"
        sudo launchctl bootout system/homebrew.mxcl.dnscrypt-proxy 2>/dev/null \
            || sudo launchctl unload "$DNSCRYPT_DAEMON" 2>/dev/null || true
        run sudo rm -f "$DNSCRYPT_DAEMON"
    else
        skip "LaunchDaemon dnscrypt-proxy снят"
    fi
    if pgrep -f dnscrypt-proxy >/dev/null 2>&1; then
        warn "процесс dnscrypt-proxy всё ещё жив — добиваю"
        sudo pkill -f dnscrypt-proxy || true
        sleep 1
    fi
    pgrep -f dnscrypt-proxy >/dev/null 2>&1 \
        && warn "процесс dnscrypt-proxy не завершился, посмотри: pgrep -fl dnscrypt-proxy" \
        || ok "dnscrypt-proxy не работает"
fi

# ═══════════════════════ ФАЗА B — сервис и правила PF ═══════════════════════

step "Остановка сервиса zapret"
info "Останавливаем штатно: скрипт сам снимает правила PF и убивает демонов."
if [ -x "$ZAPRET_CTL" ]; then
    run sudo "$ZAPRET_CTL" stop || warn "штатная остановка завершилась с ошибкой — дочищу вручную"
else
    skip "управляющего скрипта нет — сервис уже удалён"
fi
if pgrep -f "$OPT_DIR/tpws/tpws" >/dev/null 2>&1; then
    warn "процесс tpws всё ещё жив — снимаю принудительно"
    sudo pkill -f "$OPT_DIR/tpws/tpws" || true
    sleep 1
fi
if pgrep -f "$OPT_DIR/tpws/tpws" >/dev/null 2>&1; then
    warn "tpws не завершился — посмотри: pgrep -fl tpws"
else
    ok "tpws не работает"
fi

step "Удаление LaunchDaemon (автозапуск)"
if [ -f "$LAUNCH_DAEMON" ]; then
    sudo launchctl bootout "system/$LAUNCH_LABEL" 2>/dev/null \
        || sudo launchctl unload "$LAUNCH_DAEMON" 2>/dev/null \
        || warn "launchctl не смог выгрузить демона (возможно, он и не был загружен)"
    run sudo rm -f "$LAUNCH_DAEMON"
    ok "автозапуск снят"
else
    skip "LaunchDaemon уже удалён"
fi
# Через sudo -n: проверка не должна сама по себе выскакивать с запросом пароля.
if sudo -n launchctl print "system/$LAUNCH_LABEL" >/dev/null 2>&1; then
    warn "демон $LAUNCH_LABEL всё ещё зарегистрирован в launchd — потребуется перезагрузка"
elif sudo -n true 2>/dev/null; then
    ok "в launchd демона нет"
else
    skip "состояние launchd не проверить без пароля"
fi

step "Удаление правила sudoers"
# Правило разрешало перезапускать сервис без пароля. Сервиса больше нет —
# правило становится просто висящим разрешением, его надо снять.
if sudo test -f "$SUDOERS_FILE"; then
    run sudo rm -f "$SUDOERS_FILE"
    ok "правило удалено: $SUDOERS_FILE"
else
    skip "правила sudoers нет"
fi

step "Снятие правил и якорей PF"
info "Сначала чистим содержимое якорей, потом убираем сами файлы и ссылки на них в $PF_MAIN."
for anchor in zapret zapret-v4 zapret-v6; do
    sudo pfctl -a "$anchor" -F all >/dev/null 2>&1 || true
done
ok "содержимое якорей PF сброшено"

for anchor in zapret zapret-v4 zapret-v6; do
    if [ -f "$PF_ANCHOR_DIR/$anchor" ]; then
        run sudo rm -f "$PF_ANCHOR_DIR/$anchor"
    else
        skip "$PF_ANCHOR_DIR/$anchor уже удалён"
    fi
done

if grep -qE '^(rdr-)?anchor "zapret"$' "$PF_MAIN" 2>/dev/null || grep -q '^set limit table-entries' "$PF_MAIN" 2>/dev/null; then
    # Бэкап кладём во временный каталог: рядом с pf.conf он не нужен и только путает.
    PF_BAK="$(mktemp /tmp/pf.conf.XXXXXX)"
    run sudo cp "$PF_MAIN" "$PF_BAK"
    info "резервная копия: $PF_BAK"
    # Те же три строки, что вписывает установщик zapret (common/pf.sh).
    run sudo sed -i '' \
        -e '/^anchor "zapret"$/d' \
        -e '/^rdr-anchor "zapret"$/d' \
        -e '/^set limit table-entries/d' \
        "$PF_MAIN"
    if sudo pfctl -n -f "$PF_MAIN" >/dev/null 2>&1; then
        run sudo pfctl -qf "$PF_MAIN" || warn "перезагрузка правил PF вернула ошибку — проверь: sudo pfctl -sr"
        run sudo rm -f "$PF_BAK"
        ok "$PF_MAIN приведён к исходному виду, правила перезагружены"
    else
        run sudo cp "$PF_BAK" "$PF_MAIN"
        run sudo rm -f "$PF_BAK"
        die "после правки $PF_MAIN стал невалидным, вернул как было" \
            "проверь вручную: sudo pfctl -n -f $PF_MAIN"
    fi
else
    skip "в $PF_MAIN нет строк zapret"
fi

step "Удаление каталога сервиса"
if [ -d "$OPT_DIR" ]; then
    info "Внутри также хук блокировки QUIC (init.d/macos/custom.d/10-block-quic) и config_custom."
    run sudo rm -rf "$OPT_DIR"
    ok "удалён $OPT_DIR"
else
    skip "$OPT_DIR уже удалён"
fi

# ═══════════════════ ФАЗА C — приложение, настройки, исходники ══════════════

step "Удаление приложения darkware zapret"
if pgrep -f "$APP_DST/Contents/MacOS" >/dev/null 2>&1; then
    info "приложение запущено — закрываю"
    pkill -f "$APP_DST/Contents/MacOS" || true
    sleep 1
fi
if [ -d "$APP_DST" ]; then
    run sudo rm -rf "$APP_DST"
    ok "удалено: $APP_DST"
else
    skip "приложения в /Applications нет"
fi
if [ -f "$APP_PREFS" ]; then
    run defaults delete com.darkware.zapret 2>/dev/null || true
    run rm -f "$APP_PREFS"
    ok "настройки приложения удалены"
else
    skip "настроек приложения нет"
fi

step "Удаление исходников"
if [ "$KEEP_SOURCES" -eq 1 ]; then
    skip "запрошено ключом --keep-sources"
else
    for dir in "$ZAPRET_SRC" "$BYEDPI_SRC" "${LEGACY_SRC[@]}"; do
        if [ -d "$dir" ]; then
            run rm -rf "$dir"
            ok "удалён $dir"
        else
            skip "$dir уже удалён"
        fi
    done
    # Каталог кэша наш целиком, но убираем его только если он пуст:
    # чужого там быть не должно, а если что-то есть — пусть останется на виду.
    rmdir "$SRC_DIR" 2>/dev/null && ok "удалён каталог кэша $SRC_DIR" || true
fi

# ═════════════════════════════ ФАЗА D — Chrome ══════════════════════════════

step "Политика Chrome: снятие запрета QUIC"
if defaults read com.google.Chrome QuicAllowed >/dev/null 2>&1; then
    run defaults delete com.google.Chrome QuicAllowed
    ok "политика QuicAllowed снята (подтвердится в chrome://policy после перезапуска Chrome)"
else
    skip "политика не выставлена"
fi

step "Флаги Chrome"
info "Флаг enable-quic остаётся в Disabled — снять его можно только руками в самом Chrome."
verify_chrome_flags() {
    if ! command -v python3 >/dev/null 2>&1; then
        info "нет python3 — проверить флаги нечем, считаю шаг выполненным"
        return 0
    fi
    [ -f "$CHROME_LOCAL_STATE" ] || { info "нет файла Local State — Chrome не установлен или ни разу не запускался"; return 0; }
    python3 - "$CHROME_LOCAL_STATE" <<'PY'
import json, sys
try:
    labs = json.load(open(sys.argv[1])).get('browser', {}).get('enabled_labs_experiments', [])
except Exception as exc:
    print(f'        не удалось прочитать Local State: {exc}')
    sys.exit(1)
print(f'        флаги сейчас: {labs if labs else "пусто"}')
if any(f.startswith('enable-quic@') for f in labs):
    print('        не так: enable-quic всё ещё переопределён — верни его в Default')
    sys.exit(1)
sys.exit(0)
PY
}
if [ ! -d "/Applications/Google Chrome.app" ]; then
    skip "Chrome не установлен"
elif verify_chrome_flags >/dev/null 2>&1; then
    skip "флаги Chrome уже в исходном состоянии"
else
    confirm_gui_step "  1. Открой Chrome, в адресной строке: chrome://flags/#enable-quic  → верни Default
  2. Нажми кнопку Relaunch внизу страницы.
  3. Необязательно: chrome://flags/#cryptography-compliance-cnsa тоже можно вернуть в Default —
     установка держала его выключенным, вреда от этого нет.
  4. Необязательно: «Всегда использовать безопасные соединения» в chrome://settings/security
     полезна и сама по себе — снимать не обязательно.
  5. ВАЖНО: полностью закрой Chrome (Cmd+Q) — иначе он не запишет настройки на диск." verify_chrome_flags
fi

# ══════════════════════════════ ФАЗА E — логи ═══════════════════════════════

step "Удаление логов"
if [ "$KEEP_LOGS" -eq 1 ]; then
    skip "запрошено ключом --keep-logs"
else
    info "В /tmp/tpws.log могли попасть имена посещённых сайтов — удаляем в первую очередь."
    for f in /tmp/darkware-zapret.out.log /tmp/darkware-zapret.error.log /tmp/tpws.log; do
        if [ -e "$f" ]; then
            run sudo rm -f "$f"
        else
            skip "$f уже нет"
        fi
    done
    # dpi-bypass-setup-*.log — имя логов до переименования setup.sh в install.sh;
    # на давно настроенной машине они ещё лежат, и вычистить их надо тоже.
    found_install_log=0
    for f in "$HOME"/dpi-bypass-install-*.log "$HOME"/dpi-bypass-setup-*.log; do
        [ -f "$f" ] || continue
        found_install_log=1
        run rm -f "$f"
    done
    [ "$found_install_log" -eq 1 ] && ok "логи установки удалены" || skip "логов установки нет"
    info "Лог этого удаления остаётся: $LOG_FILE"
fi

# ═════════════════════════ ФАЗА F — итоговая проверка ═══════════════════════

step "Итоговая проверка"
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        ok "$desc"
    else
        printf '  [НЕТ] %s\n' "$desc"
        FAILED_CHECKS+=("$desc")
    fi
}
check_absent() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        printf '  [НЕТ] %s\n' "$desc"
        FAILED_CHECKS+=("$desc")
    else
        ok "$desc"
    fi
}

check_absent "каталог $OPT_DIR удалён"        test -d "$OPT_DIR"
check_absent "LaunchDaemon удалён"            test -f "$LAUNCH_DAEMON"
if sudo -n true 2>/dev/null; then
    check_absent "правило sudoers удалено"    sudo -n test -f "$SUDOERS_FILE"
else
    warn "правило sudoers не проверить без пароля — пропускаю эту проверку"
fi
check_absent "приложение удалено"             test -d "$APP_DST"
check_absent "процесс tpws не работает"       pgrep -f "$OPT_DIR/tpws/tpws"
check_absent "в $PF_MAIN нет якорей zapret"   grep -qE '^(rdr-)?anchor "zapret"$' "$PF_MAIN"
check_absent "файлы якорей PF удалены"        test -f "$PF_ANCHOR_DIR/zapret"
if [ "$KEEP_DNSCRYPT" -eq 1 ]; then
    skip "dnscrypt-proxy оставлен намеренно — не проверяю"
else
    check_absent "процесс dnscrypt-proxy не работает" pgrep -f dnscrypt-proxy
    check_absent "автозапуск dnscrypt-proxy снят" test -f "$DNSCRYPT_DAEMON"
    check_absent "пакет dnscrypt-proxy удалён" brew list --versions dnscrypt-proxy
fi

info "DNS сетевых сервисов:"
networksetup -listallnetworkservices | tail -n +2 | while IFS= read -r svc; do
    printf '        %-24s %s\n' "$svc" "$(networksetup -getdnsservers "${svc#\*}" 2>/dev/null | tr '\n' ' ' || true)"
done

check "системный DNS резолвит имена" system_resolves
check "интернет работает (https://example.com)" \
    curl -s -o /dev/null --max-time 15 https://example.com

printf '\n══════════════════════════════════════════════════════════════════\n'
if [ "${#FAILED_CHECKS[@]}" -eq 0 ]; then
    printf 'ГОТОВО. Настройка снята, все проверки пройдены.\n\n'
    printf 'Что осталось на машине намеренно:\n'
    printf '  • Homebrew, Command Line Tools, Google Chrome — их скрипт не ставил как одноразовые\n'
    printf '  • настройка «Всегда использовать безопасные соединения» в Chrome, если ты её оставил\n\n'
    printf 'Заблокированные сайты снова блокируются — это ожидаемо.\n'
    printf 'Развернуть всё обратно: ./install.sh рядом с этим скриптом.\n'
else
    printf 'ЗАВЕРШЕНО С ЗАМЕЧАНИЯМИ. Не прошли проверки:\n'
    for c in "${FAILED_CHECKS[@]}"; do printf '  • %s\n' "$c"; done
    printf '\nПовторный запуск скрипта безопасен и дочистит оставшееся.\n'
fi
printf '\nПолный лог: %s\n' "$LOG_FILE"
printf 'Если что-то не так — пришли его целиком.\n'
printf '══════════════════════════════════════════════════════════════════\n\n'
