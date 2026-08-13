# Обход DPI на macOS

Рабочая конфигурация от 13.08.2026, macOS 26.5.1, Apple Silicon.

Наблюдения о поведении сети сняты на одном конкретном провайдере — у другого набор
блокировок и рабочая стратегия будут отличаться, но методика проверки та же.
Конкретные адреса в тексте намеренно не зашиты: везде, где они нужны, приведена команда,
которая их получает.

## Что стоит и где

| Компонент | Где | Автозапуск |
|---|---|---|
| `tpws` (обход DPI, только TCP) | `/opt/darkware-zapret/` | LaunchDaemon `/Library/LaunchDaemons/com.darkware.zapret.plist` |
| GUI-пульт «darkware zapret» | `/Applications/darkware zapret.app` | не нужен, сервис живёт сам |
| `dnscrypt-proxy` (DNS поверх HTTPS) | `/opt/homebrew/etc/dnscrypt-proxy.toml` | `sudo brew services start dnscrypt-proxy` |
| Исходники | `~/develop/darkware-zapret`, `~/develop/byedpi` | — |

Управление сервисом (пароль не спрашивает — правило в `/etc/sudoers.d/darkware-zapret`):

```bash
sudo /opt/darkware-zapret/init.d/macos/zapret start|stop|restart|status
```

## Рабочая стратегия

`/opt/darkware-zapret/config_custom` — файл с правами 666, редактируется без sudo,
GUI перезаписывает его тем же содержимым:

```
MODE_FILTER=autohostlist
TPWS_ENABLE=1
TPWS_SOCKS_ENABLE=1
TPWS_PORTS=80,443
INIT_APPLY_FW=1
DISABLE_IPV6=1
GZIP_LISTS=0
GETLIST=get_refilter_domains.sh
TPWS_OPT="
--filter-tcp=80 --methodeol <HOSTLIST> --new
--filter-tcp=443 --split-pos=midsld --disorder <HOSTLIST>
"
```

Ключевое — `--split-pos=midsld --disorder` для 443. Вариант из GUI по умолчанию
(`--split-pos=1,midsld --disorder`) берёт YouTube, но не rutracker и рвёт соединения curl.

## Блокировка QUIC (обязательна)

tpws работает только с TCP, а Chrome ходит на YouTube по HTTP/3. Проверено:
`youtube.com` по HTTP/3 — таймаут, по HTTP/2 — 200; `google.com` по HTTP/3 — 200,
то есть режут QUIC именно к YouTube. Закрыто на трёх уровнях:

1. Хук PF: `/opt/darkware-zapret/init.d/macos/custom.d/10-block-quic` (копия в этой папке) —
   `block drop out quick proto udp port 443` в якорях zapret-v4/v6.
2. Политика Chrome: `defaults write com.google.Chrome QuicAllowed -bool false`.
3. Флаг `chrome://flags/#enable-quic` → Disabled.

## Chrome: обязательные настройки

- **`chrome://flags/#cryptography-compliance-cnsa` → Default.** Это была причина
  `ERR_CONNECTION_CLOSED` на YouTube во всех профилях и в инкогнито. Режим CNSA 2.0
  раздувает ClientHello до нескольких килобайт (ML-KEM-1024, P-384), он не влезает
  в один TCP-сегмент, и socket-level split его не спасает. Доказано тремя прогонами
  на чистом профиле: с флагом — ERR_CONNECTION_CLOSED, без — YouTube грузится.
- **«Всегда использовать безопасные соединения»** (`chrome://settings/security`) —
  порт 80 не обходится в принципе (см. ниже), а браузер при вводе голого домена лезет туда.

## DNS

Провайдер подменяет DNS-ответы для заблокированных доменов, **включая запросы к 1.1.1.1
и 8.8.8.8 по обычному UDP** — прописывать публичные DNS в настройках сети бесполезно.
Подмена **непостоянная**: то есть, то нет, поэтому симптомы плавают.

С подменённого адреса приходит заглушка «Доступ закрыт» или 503, а по HTTPS — чужой
сертификат, выписанный на домен провайдера (Chrome показывает Privacy error).
Как отличить подмену от настоящего ответа — сравнить обычный резолв с ответом по HTTPS
и посмотреть, чья это сеть:

```bash
dig +short rutracker.org                                   # что отдаёт система
curl -s -H 'accept: application/dns-json' \
     'https://1.1.1.1/dns-query?name=rutracker.org&type=A' # правда, подменить нельзя
whois "$(dig +short rutracker.org | head -1)" | grep -i -m1 -E 'netname|org-name'
```

Расхождение + netname самого провайдера в whois = подмена.

Лечение — `dnscrypt-proxy` на `127.0.0.1:53`, в конфиге `server_names = ['cloudflare', 'google']`:

```bash
sudo brew services start dnscrypt-proxy      # первому старту нужно ~40 с на список резолверов
sudo networksetup -setdnsservers Ethernet 127.0.0.1
sudo networksetup -setdnsservers Wi-Fi 127.0.0.1
# откат:
sudo networksetup -setdnsservers Ethernet Empty; sudo networksetup -setdnsservers Wi-Fi Empty
```

Chrome использует **свой** резолвер, но серверы берёт из системной конфигурации, так что
идёт через тот же `127.0.0.1`. Secure DNS в самом Chrome включать не нужно.

Профиль macOS (`.mobileconfig`) с DoH на этой машине **не ставится** — «The VPN service
could not be created», и с `ServerAddresses`, и без них. Поэтому и понадобился dnscrypt-proxy.

## Что работает, а что нет

| Сайт | Состояние |
|---|---|
| YouTube | работает, 869 КБ за 0.47 с |
| Instagram, Facebook | работают |
| rutracker.org | DNS и TLS чинятся (настоящий `CN=rutracker.org`, HTTP 200), но поток душат: ~20 КБ и тишина |
| x.com, discord.com | то же самое — заголовки приходят, тело встаёт на 15–20 КБ |

Замедление бьёт по **входящему** потоку. Лечится только на уровне пакетов (`nfqws`/`winws`:
сжатие MSS, десинк ответов сервера), а на macOS их не существует — в `tpws` нет даже `--mss`.
Для этих сайтов на Mac нужен VPN или зарубежный прокси. На Windows-машине с zapret они работают
именно потому, что там пакетный движок.

## Проверка, что всё живо

```bash
pgrep -fl tpws dnscrypt-proxy
networksetup -getdnsservers Ethernet                      # ждём 127.0.0.1
dig +short rutracker.org                                  # сверить с ответом по DoH (раздел «DNS»)
curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://www.youtube.com   # 200
curl -s https://httpbin.org/ip                            # свой внешний адрес, если нужен
```

Отладка tpws (пишет имена хостов, потом обязательно убрать):
добавить `--debug=@/tmp/tpws.log` первой строкой в `TPWS_OPT`, перезапустить сервис.
В логе видно `hostlist check ... positive`, `multisplit pos: N`, размер ClientHello.

## Сборка с нуля

```bash
git clone https://github.com/roninreilly/darkware-zapret.git ~/develop/darkware-zapret
git clone https://github.com/hufrea/byedpi.git ~/develop/byedpi

cd ~/develop/byedpi && make                     # ciadpi; для universal — две сборки + lipo
cd ~/develop/darkware-zapret/zapret_src && make mac   # tpws, ip2net, mdig в binaries/my
cp ~/develop/byedpi/ciadpi zapret_src/byedpi/ciadpi   # не доверять бинарнику из репозитория

cd ~/develop/darkware-zapret && swift build -c release -Xswiftc -parse-as-library
# бандл собирается скриптом make_bundle.sh (копия в этой папке): бинарь + zapret_src
# в Resources + Info.plist + codesign -s -. Полный create_app.sh делает ещё DMG и требует
# Finder/AppleScript, а universal-сборка Swift — полного Xcode (в CLT нет xcbuild).
```

Дальше — запустить приложение, нажать **Install Service** (один раз, с паролем админа),
затем вписать стратегию в `config_custom` и `sudo /opt/darkware-zapret/init.d/macos/zapret restart`.

## Что делает установщик апстрима — проверить сразу после установки

Читается в `install_darkware.sh` самого проекта. Две вещи стоит поправить первым делом:
правило sudoers он выписывает на всех пользователей, а свой файл конфигурации создаёт
доступным на запись кому угодно. Поскольку этот конфиг подключается в тот, что читает
запускаемый под root скрипт, вместе это даёт локальному процессу root без пароля.

```bash
# сузить sudoers до себя и закрыть конфиг на запись остальным
sudo chown "$USER" /opt/darkware-zapret/config_custom
sudo chmod 600 /opt/darkware-zapret/config_custom
sudo sed -i '' "s/^ALL /$USER /" /etc/sudoers.d/darkware-zapret
```

Установщик также патчит `/etc/pf.conf` (добавляет `rdr-anchor "zapret"` и `anchor "zapret"`)
и ставит LaunchDaemon с автозапуском.

## Тупики — не тратить на них время повторно

- **Порт 80 не обходится.** Перехват идёт по IP, а не по имени: запрос к адресу
  заблокированного сайта с подставленным `Host: example.com` всё равно отдаёт заглушку,
  то есть до настоящего сервера пакеты не доходят. Проверены все 11 стратегий tpws
  для 80-го порта — бесполезно. Решение только одно: не ходить по HTTP.
- **Движок ciadpi (ByeDPI) на macOS слабее tpws.** `-d` (disorder) и `-q` (disoob) рвут
  вообще любое соединение, включая example.com (реализованы через TTL=1, что работает
  только на Linux). Ни одна его стратегия не берёт YouTube. Не включать.
- **ECH не поможет.** Cloudflare не публикует `ech=` в DNS (проверено для rutracker.org,
  cloudflare.com, crypto.cloudflare.com), Chrome молча откатывается на открытый SNI
  (`sni=plaintext` в `cdn-cgi/trace`). Плюс ТСПУ режет ECH там, где он есть.
- **Не долбить заблокированный хост подряд.** После ~15 handshake'ов провайдер начинает
  резать адрес наглухо, и результаты перебора стратегий становятся мусором на час-другой.
  Между замерами держать паузу, стратегии сравнивать на разных хостах.
- **Заголовок вкладки Chrome — плохой индикатор.** На странице ошибки Chrome ставит
  заголовком имя хоста, и это легко принять за успех. Проверять размер DOM и наличие
  осмысленного контента.

## Полное удаление

```bash
sudo launchctl unload /Library/LaunchDaemons/com.darkware.zapret.plist
sudo rm /Library/LaunchDaemons/com.darkware.zapret.plist /etc/sudoers.d/darkware-zapret
sudo rm -rf /opt/darkware-zapret
sudo brew services stop dnscrypt-proxy
sudo networksetup -setdnsservers Ethernet Empty; sudo networksetup -setdnsservers Wi-Fi Empty
defaults delete com.google.Chrome QuicAllowed
```
