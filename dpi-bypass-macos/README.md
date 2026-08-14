# Обход DPI на macOS

Рабочая конфигурация от 13.08.2026, macOS 26.5.1, Apple Silicon.

Наблюдения о поведении сети сняты на одном конкретном провайдере — у другого набор
блокировок и рабочая стратегия будут отличаться, но методика проверки та же.
Конкретные адреса в тексте намеренно не зашиты: везде, где они нужны, приведена команда,
которая их получает.

## Два скрипта

```bash
./install.sh      # развернуть настройку
./uninstall.sh    # снять её полностью
```

Оба идемпотентны: повторный запуск на уже настроенной (или уже вычищенной) машине
проходит на «ПРОПУСК» и ничего не ломает. Каждый пишет полный лог —
`~/dpi-bypass-install-*.log` и `~/dpi-bypass-uninstall-*.log`; если что-то пошло не так,
этот файл и есть то, что нужно показать. Пароль администратора спрашивается в начале;
система может переспросить его посреди работы — это нормально.

**`install.sh`** ставит зависимости (Command Line Tools, Homebrew, git, dnscrypt-proxy,
Chrome), собирает `tpws` и `ciadpi` из исходников, ставит приложение, проводит через
два шага, которые нельзя сделать за тебя — кнопку **Install Service** в меню-баре и
флаги Chrome, — и после каждого проверяет результат, не пропуская дальше, пока он не
достигнут. Затем прописывает стратегию, хук блокировки QUIC, шифрованный DNS и
закрывает дыру, которую оставляет установщик апстрима (см. ниже). Ключ `--rebuild`
заставляет пересобрать приложение, даже если сервис уже стоит.

**`uninstall.sh`** без аргументов спрашивает объём удаления: сносить ли шифрованный DNS,
исходники сборки, логи. Ключи `--keep-dnscrypt`, `--keep-sources`, `--keep-logs`
отвечают на те же вопросы заранее и отключают опрос, `--yes` снимает и подтверждение
плана — вместе они дают неинтерактивный запуск. Порядок шагов там не случайный:
**сначала системный DNS возвращается на автоматический и проверяется, что резолв живой,
и только потом останавливается `dnscrypt-proxy`** — наоборот машина осталась бы без DNS.
Если резолв после отката не поднимается, скрипт демон не трогает и говорит об этом.

Кнопка Uninstall в самом приложении делает заметно меньше: сносит `/opt` и правило
sudoers, но оставляет LaunchDaemon, патч `/etc/pf.conf` и настройки DNS и Chrome.

## Как обходится DPI

Три независимых механизма, каждый закрывает свою дыру.

### 1. Десинхронизация TCP — `tpws`

Правило PF заворачивает исходящие соединения на порты 80 и 443 на локальный прокси
(якорь `zapret-v4`, `/etc/pf.anchors/zapret-v4`):

```
rdr on lo0 inet proto tcp from !127.0.0.0/8 to any port {80,443} -> 127.0.0.1 port 988
pass out route-to (lo0 127.0.0.1) inet proto tcp from !127.0.0.0/8 to any port {80,443} user { >root }
```

`user { >root }` исключает процессы самого root — иначе tpws зациклил бы собственные
исходящие соединения. Адреса из таблицы `<nozapret>` не перенаправляются.

`tpws` принимает соединение как прозрачный прокси, открывает своё наружу и вмешивается
ровно в первый запрос клиента:

- **443**: ClientHello разрезается на два TCP-сегмента в позиции `midsld` — середине
  домена второго уровня в SNI — и они отправляются **в обратном порядке** (`--disorder`).
  DPI собирает поток иначе, чем сервер, целого имени хоста в одном сегменте не видит
  и правило блокировки не срабатывает. Сервер же складывает сегменты по номерам
  и получает корректный ClientHello.
- **80**: `--methodeol` — перевод строки **перед** методом запроса, чтобы DPI, который
  ждёт `GET ` в начале потока, не распознал HTTP. На этом провайдере не помогает
  (см. «Тупики»), но и не мешает.

Вмешательство идёт не во всё подряд: `MODE_FILTER=autohostlist`, домены берутся из
хостлистов (~81 000 записей плюс автонакопление). Второй экземпляр `tpws` поднимает
SOCKS на `127.0.0.1:987` вообще без вмешательства — он в этой схеме не нужен.

**Потолок метода на macOS:** доступен только сокетный уровень. Пакетных трюков
(TTL, MSS, десинк ответов сервера) нет — для них нужны divert-сокеты, которых в macOS
не существует, и `nfqws`/`winws` сюда не портируются. Отсюда и то, что часть сайтов
чинится лишь частично — см. «Что работает, а что нет».

### 2. Блокировка QUIC

`tpws` знает только TCP, а Chrome ходит на YouTube по HTTP/3 поверх UDP — такой трафик
прошёл бы мимо обхода. Поэтому UDP/443 глушится правилом PF, политикой Chrome и флагом
браузера — подробности в разделе «Блокировка QUIC».

### 3. Локальный DNS-прокси — `dnscrypt-proxy`

Провайдер подменяет DNS-ответы, **включая запросы к публичным резолверам по обычному
UDP**, поэтому одного обхода TLS мало: без честного DNS браузер просто идёт на адрес
заглушки. Разворачивается локальный резолвер `dnscrypt-proxy` на `127.0.0.1:53`,
наружу он ходит по DoH (`server_names = ['cloudflare', 'google']`), а системный DNS
всех сетевых сервисов переключается на него. Chrome использует собственный резолвер,
но серверы берёт из системной конфигурации, так что идёт туда же. Подробности и способ
поймать подмену — в разделе «DNS».

### Чего эта сборка не обходит

Обход работает ровно там, где решение о блокировке принимается по **первому пакету
клиента**. Всё, что ТСПУ делает дальше по соединению, socket-level движку недоступно:

- **Троттлинг входящего потока.** `rutracker.org`, `x.com`, `discord.com`: DNS резолвится
  честно, TLS поднимается с настоящим сертификатом, сервер отвечает `200` и отдаёт
  заголовки — а потом поток встаёт после **~15–20 КБ** тела и висит до таймаута.
  Давят **ответ сервера**, а `tpws` вмешивается только в исходящий ClientHello, до
  входящих пакетов он не дотягивается. Лечится сжатием MSS и десинком ответов, то есть
  пакетным движком (`nfqws`/`winws`), которого на macOS нет и быть не может.
- **Перехват по IP на порту 80.** Запрос к адресу заблокированного сайта возвращает
  заглушку даже с подставленным чужим `Host:` — значит фильтр смотрит на адрес, а не
  на имя, и дробить запрос бессмысленно. Проверены все 11 стратегий tpws для 80-го порта.
- **Блокировка по адресу в целом.** Если сервис закрыт по диапазонам IP, десинхронизация
  не поможет ни в какой форме — здесь нужен только VPN или зарубежный прокси.
- **Агрессивная реакция на перебор.** После ~15 подряд handshake'ов к заблокированному
  хосту провайдер начинает резать его наглухо на час-другой, и работавшая стратегия
  «перестаёт работать» до тех пор, пока он не отпустит.

Для этих случаев на Mac ответ один — VPN или зарубежный прокси. На Windows-машине
с zapret те же сайты работают именно потому, что там пакетный движок.

## Что ставится: собранное и готовое

| Компонент | Откуда | Как получается |
|---|---|---|
| `tpws`, `ip2net`, `mdig` | [bol-van/zapret](https://github.com/bol-van/zapret) в составе форка | **сборка из исходников**, `make mac` — universal (arm64 + x86_64 через `lipo`) |
| `ciadpi` (ByeDPI) | [hufrea/byedpi](https://github.com/hufrea/byedpi) | **сборка из исходников**, `make` |
| GUI-пульт «darkware zapret» | [roninreilly/darkware-zapret](https://github.com/roninreilly/darkware-zapret) | **сборка из исходников**, `swift build` + бандл с ad-hoc подписью |
| `dnscrypt-proxy` | [DNSCrypt/dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy) | **готовый бинарник** — bottle из Homebrew |
| Google Chrome | — | **готовый**, cask, и только если его ещё нет |
| Хостлисты доменов | скачивает сам сервис | данные, не код |

Всё, что попадает в `/opt/darkware-zapret` и реально работает с трафиком, собрано
на этой машине: `/opt/darkware-zapret/tpws/tpws` — симлинк на `binaries/my/tpws`,
и он представляется как `self-built version`. Закоммиченный в репозиторий
`darkware-zapret` бинарник `ciadpi` намеренно **заменяется своей сборкой** перед
упаковкой приложения — доверять чужому исполняемому файлу из репозитория незачем.
`ciadpi` при этом в рабочей конфигурации не запускается: на macOS он слабее `tpws`
(см. «Тупики»), но остаётся в бандле, потому что его ждёт GUI.

Ставится это апстримовым `install_darkware.sh` (кнопка Install Service): он копирует
дерево в `/opt`, патчит `/etc/pf.conf`, кладёт LaunchDaemon и правило sudoers —
и заодно оставляет дыру, которую `install.sh` закрывает следом (см. одноимённый раздел).

## Что стоит и где

| Компонент | Где | Автозапуск |
|---|---|---|
| `tpws` (обход DPI, только TCP) | `/opt/darkware-zapret/` | LaunchDaemon `/Library/LaunchDaemons/com.darkware.zapret.plist` |
| GUI-пульт «darkware zapret» | `/Applications/darkware zapret.app` | не нужен, сервис живёт сам |
| `dnscrypt-proxy` (DNS поверх HTTPS) | `/opt/homebrew/etc/dnscrypt-proxy.toml` | `sudo brew services start dnscrypt-proxy` |
| Исходники (материал сборки) | `~/Library/Caches/dpi-bypass-macos/{darkware-zapret,byedpi}` | — |

Исходники лежат в кэше намеренно: после установки сервис живёт в `/opt` и от них не
зависит, так что каталог можно снести в любой момент — `./install.sh --rebuild`
переклонирует и пересоберёт. Поэтому же они не в `~/develop` (это не рабочий проект)
и не в репозитории dotfiles (16 МБ чужих бинарников в git не нужны).

Управление сервисом (пароль не спрашивает — правило в `/etc/sudoers.d/darkware-zapret`;
команды `status` у него нет, без аргументов печатает список поддерживаемых):

```bash
sudo /opt/darkware-zapret/init.d/macos/zapret start|stop|restart|start-fw|stop-fw|restart-fw|start-daemons|stop-daemons|restart-daemons
```

## Рабочая стратегия

`/opt/darkware-zapret/config_custom` — эталон лежит рядом в `config_custom.working`,
`install.sh` копирует его туда. Права 600, владелец — ты, так что правится без sudo;
GUI перезаписывает файл тем же содержимым:

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

Первые два делает `install.sh`, третий — ты сам на его шаге про флаги.

## Chrome: обязательные настройки

- **`chrome://flags/#cryptography-compliance-cnsa` → Default.** Это была причина
  `ERR_CONNECTION_CLOSED` на YouTube во всех профилях и в инкогнито. Режим CNSA 2.0
  раздувает ClientHello до нескольких килобайт (ML-KEM-1024, P-384), он не влезает
  в один TCP-сегмент, и socket-level split его не спасает. Доказано тремя прогонами
  на чистом профиле: с флагом — ERR_CONNECTION_CLOSED, без — YouTube грузится.
- **«Всегда использовать безопасные соединения»** (`chrome://settings/security`) —
  порт 80 не обходится в принципе (см. ниже), а браузер при вводе голого домена лезет туда.

Флаги живут в `Local State` и записываются на диск только при полном выходе из Chrome —
поэтому `install.sh` просит закрыть его через Cmd+Q, а потом читает файл и проверяет.

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

`install.sh` делает это для **всех** сетевых сервисов (Ethernet, Wi-Fi, Thunderbolt Bridge,
iPhone USB и прочих) и только после того, как локальный резолвер уже ответил.

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

Почему нижние две строки не чинятся — в разделе «Чего эта сборка не обходит»: давят
входящий поток, а `tpws` дотягивается только до исходящего первого пакета (в нём нет
даже `--mss`).

## Проверка, что всё живо

```bash
pgrep -fl tpws dnscrypt-proxy
networksetup -getdnsservers Ethernet                      # ждём 127.0.0.1
dig +short rutracker.org                                  # сверить с ответом по DoH (раздел «DNS»)
curl -s -o /dev/null -w '%{http_code}\n' --max-time 10 https://www.youtube.com   # 200
curl -s https://httpbin.org/ip                            # свой внешний адрес, если нужен
```

Те же проверки делает `install.sh` в конце — при повторном запуске он их прогонит,
ничего не меняя, так что это ещё и способ получить сводку о состоянии стенда.

Отладка tpws (пишет имена хостов, потом обязательно убрать):
добавить `--debug=@/tmp/tpws.log` первой строкой в `TPWS_OPT`, перезапустить сервис.
В логе видно `hostlist check ... positive`, `multisplit pos: N`, размер ClientHello.

## Сборка с нуля — то, что `install.sh` делает за тебя

```bash
SRC=~/Library/Caches/dpi-bypass-macos
git clone https://github.com/roninreilly/darkware-zapret.git "$SRC/darkware-zapret"
git clone https://github.com/hufrea/byedpi.git "$SRC/byedpi"

cd "$SRC/byedpi" && make                       # ciadpi; для universal — две сборки + lipo
cd "$SRC/darkware-zapret/zapret_src" && make mac      # tpws, ip2net, mdig в binaries/my
cp "$SRC/byedpi/ciadpi" zapret_src/byedpi/ciadpi      # не доверять бинарнику из репозитория

cd "$SRC/darkware-zapret" && swift build -c release -Xswiftc -parse-as-library
./make_bundle.sh "$SRC/darkware-zapret"        # из этой папки: бинарь + zapret_src
# в Resources + Info.plist + codesign -s -. Полный create_app.sh делает ещё DMG и требует
# Finder/AppleScript, а universal-сборка Swift — полного Xcode (в CLT нет xcbuild).
```

Дальше — запустить приложение, нажать **Install Service** (один раз, с паролем админа),
затем вписать стратегию в `config_custom` и `sudo /opt/darkware-zapret/init.d/macos/zapret restart`.

## Дыра в установщике апстрима — её закрывает `install.sh`

Читается в `install_darkware.sh` самого проекта. Правило sudoers он выписывает на всех
пользователей, а свой файл конфигурации создаёт доступным на запись кому угодно.
Поскольку этот конфиг подключается в тот, что читает запускаемый под root скрипт,
вместе это даёт локальному процессу root без пароля.

```bash
# сузить sudoers до себя и закрыть конфиг на запись остальным
sudo chown "$USER" /opt/darkware-zapret/config_custom
sudo chmod 600 /opt/darkware-zapret/config_custom
sudo sed -i '' "s/^ALL /$USER /" /etc/sudoers.d/darkware-zapret
```

Установщик также патчит `/etc/pf.conf` (добавляет `rdr-anchor "zapret"`, `anchor "zapret"`
и `set limit table-entries`) и ставит LaunchDaemon с автозапуском.

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

## Удаление вручную

Штатный путь — `./uninstall.sh` (см. выше). По шагам, если нужно руками:

```bash
sudo networksetup -setdnsservers Ethernet Empty; sudo networksetup -setdnsservers Wi-Fi Empty
dig +short example.com                                  # убедиться, что DNS жив
sudo brew services stop dnscrypt-proxy
sudo /opt/darkware-zapret/init.d/macos/zapret stop      # снимает правила PF и демонов
sudo launchctl unload /Library/LaunchDaemons/com.darkware.zapret.plist
sudo rm /Library/LaunchDaemons/com.darkware.zapret.plist /etc/sudoers.d/darkware-zapret
sudo rm -f /etc/pf.anchors/zapret /etc/pf.anchors/zapret-v4 /etc/pf.anchors/zapret-v6
sudo sed -i '' -e '/^anchor "zapret"$/d' -e '/^rdr-anchor "zapret"$/d' \
               -e '/^set limit table-entries/d' /etc/pf.conf
sudo pfctl -qf /etc/pf.conf
sudo rm -rf /opt/darkware-zapret "/Applications/darkware zapret.app"
defaults delete com.google.Chrome QuicAllowed
```

`brew uninstall dnscrypt-proxy` при этом честно скажет «Could not remove keg»: бинарник
лежит в `Cellar/.../sbin`, который `brew services` перевёл во владение root, — каталог
нужно добить через `sudo rm -rf "$(brew --cellar dnscrypt-proxy)"`. Конфигурацию в
`etc/dnscrypt-proxy.toml` brew не удаляет никогда. `uninstall.sh` доводит оба хвоста сам.
