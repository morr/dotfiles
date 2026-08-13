#!/bin/bash
#
# Разворачивает на macOS настройку обхода DPI, описанную в README.md рядом:
# tpws (darkware-zapret) + блокировка QUIC + шифрованный DNS (dnscrypt-proxy).
#
# Скрипт идемпотентен: повторный запуск на настроенной машине пройдёт на "ПРОПУСК"
# и закончится тем же финальным отчётом. Весь вывод дублируется в лог-файл —
# при проблеме пришли его целиком.
#
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$HOME/develop"
ZAPRET_SRC="$DEV_DIR/darkware-zapret"
BYEDPI_SRC="$DEV_DIR/byedpi"
APP_SRC="$ZAPRET_SRC/darkware zapret.app"
APP_DST="/Applications/darkware zapret.app"
OPT_DIR="/opt/darkware-zapret"
ZAPRET_CTL="$OPT_DIR/init.d/macos/zapret"
CHROME_APP="/Applications/Google Chrome.app"
CHROME_LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
LOG_FILE="$HOME/dpi-bypass-setup-$(date +%Y%m%d-%H%M%S).log"

FORCE_REBUILD=0
for arg in "$@"; do
    case "$arg" in
        --rebuild) FORCE_REBUILD=1 ;;
        -h|--help)
            printf 'Использование: %s [--rebuild]\n\n' "$0"
            printf '  --rebuild   пересобрать приложение, даже если сервис уже установлен\n'
            printf '\nСкрипт идемпотентен: повторный запуск на настроенной машине ничего не ломает.\n'
            exit 0 ;;
        *) printf 'Неизвестный аргумент: %s (см. --help)\n' "$arg"; exit 1 ;;
    esac
done

STEP_NO=0
CURRENT_STEP="старт"
NEED_RESTART=0
SUDO_KEEPALIVE_PID=""
DNS_BACKUP=""            # "сервис=серверы;сервис=серверы" на случай отката
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
# Аргументы экранируются, иначе пустые строки и пробелы теряются и команду
# из лога нельзя скопировать как есть.
run() {
    local quoted=""
    for a in "$@"; do quoted="$quoted $(printf '%q' "$a")"; done
    printf '      $%s\n' "$quoted"
    "$@"
}

# dig возвращает 0 и при пустом ответе, поэтому проверяем, что адрес реально пришёл.
resolver_answers() {
    dig +short +time=2 +tries=1 @127.0.0.1 example.com 2>/dev/null | grep -qE '^[0-9]+\.'
}
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

# Шаг, требующий действий пользователя. После подтверждения проверяет результат
# и не пропускает дальше, пока проверка не пройдена.
# confirm_gui_step "инструкция многострочная" имя_функции_проверки
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
            s|S) warn "шаг пропущен по твоей просьбе — настройка может оказаться неполной"; return 0 ;;
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
    local line="$1"
    printf '\n  [СБОЙ] команда завершилась с ошибкой (строка %s)\n' "$line"
    printf '  Шаг: %s\n  Лог: %s\n' "$CURRENT_STEP" "$LOG_FILE"
    if [ -n "$DNS_BACKUP" ]; then
        warn "восстанавливаю прежние DNS-серверы, чтобы не оставить машину без резолва"
        restore_dns
    fi
    printf '  Пришли лог целиком.\n\n'
}
trap 'on_error $LINENO' ERR

# ────────────────────────────── общая информация ──────────────────────────────

printf '\n'
printf 'Настройка обхода DPI на macOS\n'
printf 'Лог пишется в: %s\n\n' "$LOG_FILE"
printf 'Окружение:\n'
sw_vers | sed 's/^/  /'
printf '  Архитектура: %s\n' "$(uname -m)"
printf '  Пользователь: %s\n' "$USER"
printf '  Дата: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf '  Каталог со скриптом: %s\n' "$DOTFILES_DIR"
if [ -n "${HTTP_PROXY:-}${HTTPS_PROXY:-}${http_proxy:-}${https_proxy:-}" ]; then
    printf '  Прокси в окружении: обнаружен, снимаю на время работы скрипта\n'
fi
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy

[ "$(uname -s)" = "Darwin" ] || die "скрипт только для macOS, здесь $(uname -s)"
[ "${EUID:-$(id -u)}" -ne 0 ] || die "не запускай через sudo — пароль скрипт спросит сам, когда понадобится"

for f in config_custom.working 10-block-quic make_bundle.sh; do
    [ -f "$DOTFILES_DIR/$f" ] || die "рядом со скриптом нет файла $f" \
        "склонируй репозиторий dotfiles целиком и запусти скрипт из каталога dpi-bypass-macos"
done
ok "вспомогательные файлы на месте: config_custom.working, 10-block-quic, make_bundle.sh"

# ──────────────────────────────── права sudo ────────────────────────────────

step "Права администратора"
info "Пароль нужен для установки в /opt, правки sudoers и запуска демона DNS."
info "Скрипт будет держать сессию sudo живой, чтобы не спрашивать пароль посреди сборки."
if sudo -n true 2>/dev/null; then
    ok "sudo уже активен"
else
    sudo -v || die "без прав администратора настройка невозможна"
fi
( while true; do sudo -n true 2>/dev/null || exit; sleep 50; done ) &
SUDO_KEEPALIVE_PID=$!
ok "сессия sudo получена"

# ═══════════════════════════ ФАЗА A — зависимости ═══════════════════════════

step "Xcode Command Line Tools (нужны swift, make, компилятор)"
if xcode-select -p >/dev/null 2>&1 && xcrun --find swift >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
    ok "установлены: $(xcode-select -p)"
    info "swift: $(swift --version 2>&1 | head -1)"
else
    info "не найдены, запускаю установщик Apple (откроется окно с прогрессом)"
    xcode-select --install 2>/dev/null || true
    verify_clt() {
        if xcode-select -p >/dev/null 2>&1 && xcrun --find swift >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
            info "swift: $(swift --version 2>&1 | head -1)"
            return 0
        fi
        info "пока не вижу swift/make — установка ещё не завершилась?"
        return 1
    }
    confirm_gui_step "  1. Дождись окончания установки Command Line Tools в открывшемся окне Apple.
  2. Окно должно сказать, что установка завершена." verify_clt
fi
info "Примечание: с Command Line Tools бандл соберётся только под свою архитектуру."
info "Universal-сборка требует полного Xcode — для одной машины это не нужно."

step "Homebrew"
if command -v brew >/dev/null 2>&1; then
    ok "уже установлен: $(brew --version | head -1)"
else
    info "не найден, ставлю официальным установщиком"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$candidate" ] && eval "$("$candidate" shellenv)" && break
    done
    command -v brew >/dev/null 2>&1 || die "Homebrew не поставился" \
        "поставь вручную по инструкции с https://brew.sh и запусти скрипт заново"
    ok "установлен: $(brew --version | head -1)"
fi
BREW_PREFIX="$(brew --prefix)"
info "префикс Homebrew: $BREW_PREFIX"

step "git"
if command -v git >/dev/null 2>&1; then
    ok "есть: $(git --version)"
else
    run brew install git
    command -v git >/dev/null 2>&1 || die "git не поставился" "поставь его вручную: brew install git"
    ok "установлен"
fi

step "dnscrypt-proxy (шифрованный DNS)"
DNSCRYPT_TOML="$BREW_PREFIX/etc/dnscrypt-proxy.toml"
if brew list dnscrypt-proxy >/dev/null 2>&1; then
    ok "уже установлен"
else
    run brew install dnscrypt-proxy
    brew list dnscrypt-proxy >/dev/null 2>&1 || die "dnscrypt-proxy не поставился" \
        "поставь вручную: brew install dnscrypt-proxy"
    ok "установлен"
fi
[ -f "$DNSCRYPT_TOML" ] || die "нет конфигурации $DNSCRYPT_TOML" \
    "переустанови пакет: brew reinstall dnscrypt-proxy"
ok "конфигурация на месте: $DNSCRYPT_TOML"

step "Google Chrome"
if [ -d "$CHROME_APP" ]; then
    ok "установлен: $CHROME_APP"
else
    info "не найден, ставлю через Homebrew Cask"
    if ! brew install --cask google-chrome; then
        die "Chrome не установился автоматически" \
            "скачай и установи вручную с https://www.google.com/chrome/, затем запусти скрипт заново"
    fi
    [ -d "$CHROME_APP" ] || die "Chrome не появился в /Applications" \
        "установи Chrome вручную с https://www.google.com/chrome/"
    ok "установлен"
fi

# ═══════════════════════ ФАЗА B — исходники и сборка ════════════════════════

step "Исходники darkware-zapret и byedpi"
mkdir -p "$DEV_DIR"
clone_or_skip() {
    local url="$1" dir="$2"
    if [ -d "$dir/.git" ]; then
        skip "$dir уже склонирован"
    else
        run git clone --depth 50 "$url" "$dir"
    fi
    [ -d "$dir/.git" ] || die "не удалось получить $url" "склонируй вручную в $dir"
}
clone_or_skip https://github.com/roninreilly/darkware-zapret.git "$ZAPRET_SRC"
clone_or_skip https://github.com/hufrea/byedpi.git "$BYEDPI_SRC"
ok "исходники на месте"

step "Нужна ли пересборка"
# На уже настроенной машине пересобирать и подменять приложение незачем: сервис
# работает из /opt и от бандла не зависит. Так повторный запуск ничего не трогает.
NEED_BUILD=1
if [ "$FORCE_REBUILD" -eq 1 ]; then
    info "запрошено ключом --rebuild"
elif [ -d "$OPT_DIR" ] && [ -x "$ZAPRET_CTL" ] && [ -d "$APP_DST" ]; then
    NEED_BUILD=0
    skip "сервис и приложение уже установлены — сборку пропускаю"
    info "чтобы пересобрать принудительно, запусти: $0 --rebuild"
else
    info "сервис или приложение отсутствуют — собираю"
fi

if [ "$NEED_BUILD" -eq 1 ]; then

step "Сборка ciadpi из byedpi"
info "Собираем сами: бинарнику, закоммиченному в darkware-zapret, не доверяем."
if [ -x "$BYEDPI_SRC/ciadpi" ]; then
    skip "ciadpi уже собран"
else
    ( cd "$BYEDPI_SRC" && run make )
fi
[ -x "$BYEDPI_SRC/ciadpi" ] || die "ciadpi не собрался" "посмотри вывод make выше"
ok "ciadpi готов: $("$BYEDPI_SRC/ciadpi" --version 2>&1 | head -1)"

step "Сборка tpws, ip2net, mdig (make mac)"
if [ -x "$ZAPRET_SRC/zapret_src/binaries/my/tpws" ]; then
    skip "бинарники уже собраны"
else
    ( cd "$ZAPRET_SRC/zapret_src" && run make mac )
fi
for b in tpws ip2net mdig; do
    [ -x "$ZAPRET_SRC/zapret_src/binaries/my/$b" ] || die "не собрался $b" "посмотри вывод make mac выше"
done
ok "tpws: $("$ZAPRET_SRC/zapret_src/binaries/my/tpws" --help 2>&1 | head -1)"

step "Подмена ciadpi на свою сборку"
if cmp -s "$BYEDPI_SRC/ciadpi" "$ZAPRET_SRC/zapret_src/byedpi/ciadpi"; then
    skip "уже заменён"
else
    run cp "$BYEDPI_SRC/ciadpi" "$ZAPRET_SRC/zapret_src/byedpi/ciadpi"
fi
cmp -s "$BYEDPI_SRC/ciadpi" "$ZAPRET_SRC/zapret_src/byedpi/ciadpi" || die "подмена ciadpi не удалась"
ok "в сборку пойдёт наш ciadpi"

step "Сборка приложения (swift build)"
info "Занимает около минуты."
( cd "$ZAPRET_SRC" && run swift build -c release -Xswiftc -parse-as-library )
[ -x "$ZAPRET_SRC/.build/release/DarkwareZapret" ] || die "swift build не дал бинарника" \
    "посмотри вывод сборки выше; при ошибке про xcbuild — universal-сборка требует полного Xcode"
ok "бинарник собран"

step "Сборка бандла .app"
run bash "$DOTFILES_DIR/make_bundle.sh"
[ -d "$APP_SRC" ] || die "бандл не собрался" "посмотри вывод make_bundle.sh выше"
ok "бандл готов: $APP_SRC"

step "Установка приложения в /Applications"
if pgrep -f "$APP_DST/Contents/MacOS" >/dev/null 2>&1; then
    warn "приложение сейчас запущено — закрой его через меню-бар, иначе заменю на ходу"
    info "на работу сервиса это не влияет: он живёт в /opt и от бандла не зависит"
fi
if [ -d "$APP_DST" ]; then
    info "приложение уже стоит — заменяю свежесобранным"
    run rm -rf "$APP_DST"
fi
run cp -R "$APP_SRC" "$APP_DST"
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true
[ -d "$APP_DST" ] || die "не удалось скопировать приложение в /Applications"
ok "установлено: $APP_DST"

fi  # NEED_BUILD

# ══════════════════ ФАЗА C — установка сервиса (шаг с GUI) ══════════════════

step "Установка сервиса zapret (кнопка Install Service)"
verify_service() {
    local fail=0
    [ -d "$OPT_DIR" ] || { info "нет каталога $OPT_DIR"; fail=1; }
    [ -x "$ZAPRET_CTL" ] || { info "нет управляющего скрипта $ZAPRET_CTL"; fail=1; }
    [ -x "$OPT_DIR/tpws/tpws" ] || { info "нет бинарника $OPT_DIR/tpws/tpws"; fail=1; }
    [ -f /Library/LaunchDaemons/com.darkware.zapret.plist ] || { info "нет LaunchDaemon"; fail=1; }
    # Через sudo -n, чтобы не выскочил второй запрос пароля посреди проверки.
    if sudo -n test -f /etc/sudoers.d/darkware-zapret 2>/dev/null; then
        :
    elif sudo -n true 2>/dev/null; then
        info "нет правила sudoers"; fail=1
    else
        info "правило sudoers не проверить без пароля — пропускаю эту проверку"
    fi
    grep -q 'anchor "zapret"' /etc/pf.conf 2>/dev/null || { info "в /etc/pf.conf нет якоря zapret"; fail=1; }
    [ "$fail" -eq 0 ] || return 1
    retry_until "запуск tpws" 20 pgrep -f "$OPT_DIR/tpws/tpws" || { info "процесс tpws не поднялся"; return 1; }
    return 0
}
if verify_service >/dev/null 2>&1; then
    skip "сервис уже установлен и работает"
else
    run open "$APP_DST"
    confirm_gui_step "  1. В строке меню (справа вверху) появится иконка «darkware zapret» — открой её.
  2. Нажми «Install Service».
  3. Введи пароль администратора, когда его спросит система.
  4. Дождись, пока приложение сообщит об успешной установке." verify_service
fi
ok "сервис установлен: /opt/darkware-zapret, LaunchDaemon, правило sudoers, якоря PF"

# ══════════════════════ ФАЗА D — стратегия и хук QUIC ═══════════════════════

step "Рабочая стратегия tpws (config_custom)"
info "Стратегия для 443: --split-pos=midsld --disorder (см. README, раздел «Рабочая стратегия»)."
if cmp -s "$DOTFILES_DIR/config_custom.working" "$OPT_DIR/config_custom" 2>/dev/null; then
    skip "нужная стратегия уже записана"
else
    NEED_RESTART=1
    if cp "$DOTFILES_DIR/config_custom.working" "$OPT_DIR/config_custom" 2>/dev/null; then
        ok "стратегия записана"
    else
        info "файл закрыт на запись (уже применён хардening) — пишу через sudo"
        run sudo cp "$DOTFILES_DIR/config_custom.working" "$OPT_DIR/config_custom"
        run sudo chown "$USER" "$OPT_DIR/config_custom"
    fi
fi
cmp -s "$DOTFILES_DIR/config_custom.working" "$OPT_DIR/config_custom" || die "стратегия не записалась в $OPT_DIR/config_custom"
ok "config_custom совпадает с эталоном"

step "Блокировка QUIC на уровне PF"
info "tpws работает только с TCP; QUIC (UDP 443) пойдёт мимо обхода, поэтому закрываем его."
CUSTOM_D="$OPT_DIR/init.d/macos/custom.d"
if sudo cmp -s "$DOTFILES_DIR/10-block-quic" "$CUSTOM_D/10-block-quic" 2>/dev/null; then
    skip "хук уже установлен"
else
    NEED_RESTART=1
    run sudo mkdir -p "$CUSTOM_D"
    run sudo cp "$DOTFILES_DIR/10-block-quic" "$CUSTOM_D/10-block-quic"
fi
sudo cmp -s "$DOTFILES_DIR/10-block-quic" "$CUSTOM_D/10-block-quic" || die "хук 10-block-quic не установился"
ok "хук на месте: $CUSTOM_D/10-block-quic"

step "Перезапуск сервиса с новой конфигурацией"
info "Правило sudoers позволяет перезапускать сервис без пароля."
# Перезапуск рвёт установленные TCP-соединения, поэтому делаем его только если
# что-то реально изменилось или tpws не работает.
if [ "$NEED_RESTART" -eq 0 ] && pgrep -f "$OPT_DIR/tpws/tpws" >/dev/null 2>&1; then
    skip "конфигурация не менялась и tpws работает — не перезапускаю"
else
    run sudo "$ZAPRET_CTL" restart || true
    retry_until "процесс tpws" 20 pgrep -f "$OPT_DIR/tpws/tpws" || die "tpws не запустился после перезапуска" \
        "посмотри /tmp/darkware-zapret.error.log и вывод: sudo $ZAPRET_CTL start"
fi
ok "tpws работает"
if sudo pfctl -a zapret-v4 -sr 2>/dev/null | grep -q 'udp.*port = 443'; then
    ok "правило блокировки QUIC загружено в PF"
else
    warn "в якоре PF не вижу правила по udp/443 — проверь вручную: sudo pfctl -a zapret-v4 -sr"
fi

# ═════════════════════════════ ФАЗА E — Chrome ══════════════════════════════

step "Политика Chrome: запрет QUIC"
run defaults write com.google.Chrome QuicAllowed -bool false
[ "$(defaults read com.google.Chrome QuicAllowed 2>/dev/null)" = "0" ] || die "политика QuicAllowed не записалась"
ok "QuicAllowed=false (видно в chrome://policy после перезапуска Chrome)"

step "Флаги Chrome"
info "Критично: флаг cryptography-compliance-cnsa ломает TLS так, что обход перестаёт работать"
info "(в README — раздел «Chrome: обязательные настройки», это была причина ERR_CONNECTION_CLOSED)."
verify_chrome_flags() {
    [ -f "$CHROME_LOCAL_STATE" ] || { info "нет файла Local State — запусти Chrome хотя бы раз"; return 1; }
    python3 - "$CHROME_LOCAL_STATE" <<'PY'
import json, sys
try:
    labs = json.load(open(sys.argv[1])).get('browser', {}).get('enabled_labs_experiments', [])
except Exception as exc:
    print(f'        не удалось прочитать Local State: {exc}')
    sys.exit(1)
print(f'        флаги сейчас: {labs if labs else "пусто"}')
problems = []
if 'enable-quic@2' not in labs:
    problems.append('enable-quic не выставлен в Disabled')
if any(f.startswith('cryptography-compliance-cnsa@1') for f in labs):
    problems.append('cryptography-compliance-cnsa включён — его нужно вернуть в Default')
for p in problems:
    print(f'        не так: {p}')
sys.exit(1 if problems else 0)
PY
}
if verify_chrome_flags >/dev/null 2>&1; then
    skip "флаги уже выставлены как надо"
else
    confirm_gui_step "  1. Открой Chrome, в адресной строке: chrome://flags/#enable-quic  → поставь Disabled
  2. Там же: chrome://flags/#cryptography-compliance-cnsa  → поставь Default
  3. Нажми кнопку Relaunch внизу страницы.
  4. Затем открой chrome://settings/security и включи «Всегда использовать безопасные соединения».
  5. ВАЖНО: полностью закрой Chrome (Cmd+Q) — иначе он не запишет настройки на диск." verify_chrome_flags
fi
ok "флаги Chrome в порядке"

# ═══════════════════════════════ ФАЗА F — DNS ═══════════════════════════════

step "Настройка dnscrypt-proxy (шифрованный DNS)"
info "Провайдер подменяет DNS-ответы, в том числе запросы к 1.1.1.1 по обычному UDP."
info "Поэтому резолвер поднимаем локально, а наружу он ходит по HTTPS."
TOML_CHANGED=0
if grep -q "^server_names = \['cloudflare', 'google'\]" "$DNSCRYPT_TOML"; then
    skip "server_names уже настроены"
else
    TOML_CHANGED=1
    [ -f "$DNSCRYPT_TOML.bak" ] || run cp "$DNSCRYPT_TOML" "$DNSCRYPT_TOML.bak"
    run sed -i '' "s|^#*[[:space:]]*server_names[[:space:]]*=.*|server_names = ['cloudflare', 'google']|" "$DNSCRYPT_TOML"
    grep -q "^server_names = \['cloudflare', 'google'\]" "$DNSCRYPT_TOML" || die "не удалось прописать server_names в $DNSCRYPT_TOML" \
        "открой файл и приведи строку к виду: server_names = ['cloudflare', 'google']"
    ok "server_names прописаны"
fi
grep -q "^listen_addresses = \['127.0.0.1:53'\]" "$DNSCRYPT_TOML" \
    && ok "слушает 127.0.0.1:53" \
    || warn "listen_addresses отличается от 127.0.0.1:53 — проверь $DNSCRYPT_TOML"

step "Запуск демона dnscrypt-proxy"
# Резолвер отвечает — не трогаем его. Лишний перезапуск на уже настроенной машине
# означал бы несколько секунд без DNS, потому что система уже смотрит на 127.0.0.1.
if resolver_answers; then
    if [ "$TOML_CHANGED" -eq 1 ]; then
        info "конфигурация изменилась — перезапускаю демон"
        run sudo brew services restart dnscrypt-proxy
    else
        skip "демон уже работает и отвечает, конфигурация не менялась — не трогаю"
    fi
elif sudo brew services list 2>/dev/null | grep -q '^dnscrypt-proxy.*started'; then
    info "числится запущенным, но не отвечает — перезапускаю"
    run sudo brew services restart dnscrypt-proxy
else
    run sudo brew services start dnscrypt-proxy
fi
info "Первому запуску нужно до 40 секунд: он скачивает список резолверов."
retry_until "ответ локального резолвера" 120 resolver_answers \
    || die "dnscrypt-proxy не отвечает на 127.0.0.1:53" \
       "посмотри лог: sudo brew services info dnscrypt-proxy; системный DNS не трогали, интернет цел"
ok "локальный резолвер отвечает"

step "Переключение системного DNS на локальный резолвер"
info "Делаем это только сейчас — когда резолвер уже точно отвечает."
restore_dns() {
    local entry svc prev
    IFS=';' read -ra entries <<< "$DNS_BACKUP"
    for entry in "${entries[@]}"; do
        [ -z "$entry" ] && continue
        svc="${entry%%=*}"; prev="${entry#*=}"
        sudo networksetup -setdnsservers "$svc" $prev 2>/dev/null || true
    done
}
while IFS= read -r svc; do
    case "$svc" in
        *"An asterisk"*|"") continue ;;
    esac
    svc="${svc#\*}"
    current="$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ')"
    case "$current" in
        *"aren't any"*) prev="Empty" ;;
        *)              prev="$current" ;;
    esac
    if [ "${current% }" = "127.0.0.1" ]; then
        skip "$svc уже смотрит на 127.0.0.1"
        continue
    fi
    DNS_BACKUP="$DNS_BACKUP$svc=$prev;"
    info "$svc: было [${prev% }] → ставлю 127.0.0.1"
    sudo networksetup -setdnsservers "$svc" 127.0.0.1 2>/dev/null || warn "$svc: не удалось выставить DNS (сервис неактивен?)"
done < <(networksetup -listallnetworkservices)
retry_until "резолв через систему" 30 system_resolves \
    || { restore_dns; die "после переключения DNS перестал работать, вернул прежние настройки" \
         "проверь, жив ли демон: pgrep -fl dnscrypt-proxy"; }
DNS_BACKUP=""
ok "системный DNS переключён"

# ═══════════════════════════ ФАЗА G — хардening ═════════════════════════════

step "Закрытие дыры, которую оставляет установщик апстрима"
info "Он выписывает правило sudoers на всех пользователей и создаёт config_custom с правами 666."
info "Вместе это даёт любому локальному процессу root без пароля."
if [ "$(stat -f '%Su' "$OPT_DIR/config_custom")" = "$USER" ] && [ "$(stat -f '%Lp' "$OPT_DIR/config_custom")" = "600" ]; then
    skip "config_custom уже закрыт"
else
    run sudo chown "$USER" "$OPT_DIR/config_custom"
    run sudo chmod 600 "$OPT_DIR/config_custom"
    ok "config_custom: владелец $USER, права 600"
fi
if sudo grep -q "^ALL " /etc/sudoers.d/darkware-zapret 2>/dev/null; then
    # Бэкап кладём ВНЕ /etc/sudoers.d — каталог целиком читается sudo.
    SUDOERS_BAK="$(mktemp /tmp/darkware-sudoers.XXXXXX)"
    run sudo cp /etc/sudoers.d/darkware-zapret "$SUDOERS_BAK"
    run sudo sed -i '' "s/^ALL /$USER /" /etc/sudoers.d/darkware-zapret
    if sudo visudo -cf /etc/sudoers.d/darkware-zapret >/dev/null 2>&1; then
        run sudo rm -f "$SUDOERS_BAK"
        ok "правило sudoers сужено до пользователя $USER"
    else
        run sudo cp "$SUDOERS_BAK" /etc/sudoers.d/darkware-zapret
        run sudo chmod 440 /etc/sudoers.d/darkware-zapret
        run sudo rm -f "$SUDOERS_BAK"
        die "правка sudoers дала невалидный синтаксис, вернул как было" \
            "поправь вручную: sudo visudo -f /etc/sudoers.d/darkware-zapret"
    fi
else
    skip "правило sudoers уже сужено"
fi
# У управляющего скрипта нет команды status: без аргументов он печатает usage и
# выходит с кодом 1. Нам важно другое — что sudo пропустил его без пароля.
if sudo -n "$ZAPRET_CTL" 2>&1 | grep -q 'Usage:'; then
    ok "перезапуск сервиса по-прежнему работает без пароля"
else
    warn "sudo больше не пропускает управляющий скрипт без пароля — проверь /etc/sudoers.d/darkware-zapret"
fi

# ═════════════════════════ ФАЗА H — финальная проверка ══════════════════════

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

check "процесс tpws работает" pgrep -f "$OPT_DIR/tpws/tpws"
check "процесс dnscrypt-proxy работает" pgrep -f dnscrypt-proxy

info "DNS сетевых сервисов:"
networksetup -listallnetworkservices | tail -n +2 | while IFS= read -r svc; do
    printf '        %-24s %s\n' "$svc" "$(networksetup -getdnsservers "$svc" 2>/dev/null | tr '\n' ' ')"
done

info "Сверяю системный резолв с ответом по HTTPS (так видно подмену DNS):"
sys_ip="$(dig +short rutracker.org 2>/dev/null | head -1)"
doh_ip="$(curl -s --max-time 10 -H 'accept: application/dns-json' \
          'https://1.1.1.1/dns-query?name=rutracker.org&type=A' 2>/dev/null \
          | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(a["data"] for a in d.get("Answer",[]) if a.get("type")==1))' 2>/dev/null | head -1)"
info "системный: ${sys_ip:-нет ответа}   по HTTPS: ${doh_ip:-нет ответа}"
if [ -n "$sys_ip" ] && [ -n "$doh_ip" ]; then
    if dig +short rutracker.org 2>/dev/null | grep -qx "$doh_ip"; then
        ok "подмены DNS нет"
    else
        printf '  [НЕТ] системный резолв расходится с ответом по HTTPS — похоже на подмену\n'
        FAILED_CHECKS+=("резолв расходится с DoH")
    fi
else
    warn "не удалось сравнить резолв (нет ответа) — проверь сеть"
fi

yt_code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 https://www.youtube.com 2>/dev/null || echo 000)"
if [ "$yt_code" = "200" ]; then
    ok "YouTube отвечает 200 — обход работает"
else
    printf '  [НЕТ] YouTube вернул %s вместо 200\n' "$yt_code"
    FAILED_CHECKS+=("YouTube не открывается (код $yt_code)")
fi

printf '\n══════════════════════════════════════════════════════════════════\n'
if [ "${#FAILED_CHECKS[@]}" -eq 0 ]; then
    printf 'ГОТОВО. Все проверки пройдены.\n\n'
    printf 'Что стоит:\n'
    printf '  • tpws со стратегией --split-pos=midsld --disorder, автозапуск через LaunchDaemon\n'
    printf '  • QUIC закрыт: правило PF + политика Chrome + флаг\n'
    printf '  • dnscrypt-proxy на 127.0.0.1:53, системный DNS переключён на него\n\n'
    printf 'Работать должны YouTube, Instagram, Facebook.\n'
    printf 'rutracker, x.com и discord — нет: их поток душат после ~20 КБ,\n'
    printf 'на macOS это не лечится (см. README, раздел «Что работает, а что нет»).\n'
else
    printf 'ЗАВЕРШЕНО С ЗАМЕЧАНИЯМИ. Не прошли проверки:\n'
    for c in "${FAILED_CHECKS[@]}"; do printf '  • %s\n' "$c"; done
    printf '\nСмотри соответствующие разделы README.md рядом со скриптом.\n'
fi
printf '\nПолный лог: %s\n' "$LOG_FILE"
printf 'Если что-то не так — пришли его целиком.\n'
printf '══════════════════════════════════════════════════════════════════\n\n'
