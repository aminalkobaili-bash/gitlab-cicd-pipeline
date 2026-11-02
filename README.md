# GitLab CI/CD Pipeline: build → style → test → deploy → notify

[![CI](https://github.com/aminalkobaili-bash/gitlab-cicd-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/aminalkobaili-bash/gitlab-cicd-pipeline/actions/workflows/ci.yml)

**Задача:** CI/CD для C-утилиты на self-hosted GitLab Runner: сборка с артефактом, проверка code style, интеграционные тесты, ручной деплой по SSH на prod-VM и уведомления в Telegram о результатах CI и CD.

**Стек:** GitLab CI · GitLab Runner 19.3 (shell executor) · Ubuntu Server 24.04 (2 VM в VirtualBox) · gcc / make · clang-format 18 (стиль Google) · Python 3 · Bash · SSH / scp · Telegram Bot API · GitHub Actions (зеркало build → style → test)
Синтаксис сверен с документацией через Context7: GitLab CI (`when: manual`, `allow_failure`, `after_script`), GitLab Runner (регистрация), GitHub Actions (`checkout@v7`, `upload-artifact@v7`, `download-artifact@v8`); workflow проверен `actionlint`.

## Архитектура

```
VM1: gitlab-runner (теги build, style, test, deploy, bot)          VM2: production
┌──────────────────────────────────────────────────────────┐
│ build   cd app && make          → артефакт app/DO (30 д) │
│ style   scripts/style.sh        → clang-format --Werror  │
│ test    tests/test_integration.py → 4 сценария на app/DO │
│ deploy  scripts/deploy.sh  (manual) ── scp + ssh ────────┼──► /usr/local/bin/DO (root:root 755)
│         after_script → notify.sh: CD passed / failed     │
│ notify  notify_ci_success / notify_ci_failure            │──► Telegram Bot API
└──────────────────────────────────────────────────────────┘
```

```
├── .gitlab-ci.yml              # основной пайплайн (self-hosted runner)
├── .github/workflows/ci.yml    # build → style → test на GitHub-hosted runner
├── .clang-format               # BasedOnStyle: Google
├── app/main.c, app/Makefile    # утилита: аргумент 1..6 → строка, иначе exit 255 / 254
├── scripts/style.sh            # проверка стиля
├── scripts/deploy.sh           # доставка на prod по SSH
├── scripts/notify.sh           # уведомление в Telegram
└── tests/test_integration.py   # проверка stdout и кода возврата бинарника
```

## Что сделано

1. **Runner:** две VM на Ubuntu Server 24.04; на VM1 — `gitlab-runner` 19.3.2 с shell executor и тегами `build, style, test, deploy, bot`.
2. **build:** `make` → бинарник `app/DO` сохраняется как артефакт на 30 дней и передаётся в следующие стадии.
3. **style:** `clang-format --dry-run --Werror`. Пайплайн падал на нарушениях стиля и прошёл после форматирования.
4. **test:** `test_integration.py` запускает бинарник через `subprocess` и проверяет вывод и код возврата: без аргументов → 255, `1` → «Learning to Linux», `6` → «Learning to CI/CD», `7` → 254.
5. **deploy (`when: manual`):** SSH-ключ `ed25519` пользователя `gitlab-runner` на VM1 → `authorized_keys` на VM2, VM2 в `known_hosts`, `scp` во временный файл и установка в `/usr/local/bin` через `sudo`.
6. **notify:** Telegram-бот, сообщения об успехе и провале CI и CD с коммитом, веткой и ссылкой на пайплайн.

## Найденные проблемы и исправления

| Проблема | Было | Стало |
|---|---|---|
| **Токен бота в истории git** | в первой версии `notify.sh` токен и `chat_id` были вписаны прямо в код и попали в историю учебного репозитория | токен **отозван** через @BotFather. Этот репозиторий создан заново, без старой истории; секреты читаются только из окружения |
| Хардкод не работал вообще | строка вида `bot${123456:ABC…}/sendMessage` — bash разбирает `${N:offset}` как подстроку позиционного параметра, а не как литерал, поэтому токен в URL не подставлялся | токен передаётся через переменную `TELEGRAM_BOT_TOKEN` |
| **Уведомление о провале деплоя никогда не отправлялось** | `notify_cd_failure` с `needs: deploy_job` и `when: on_failure`. У manual-job по умолчанию `allow_failure: true`: его провал считается успехом, и job с `on_failure` после него не стартуют | результат CD отправляется из `after_script` самого `deploy_job` по `$CI_JOB_STATUS` (`after_script` выполняется и при провале `script`) |
| Ошибка Telegram API не роняла job | ответ `curl` не проверялся, `set -e` не было: неверный токен → `{"ok":false}` → job зелёный | `set -euo pipefail`, проверка `"ok":true`, `--data-urlencode` для текста. Проверено: фейковый токен → `401 Unauthorized` → exit 1 |
| Секреты в файле на runner | `source /home/gitlab-runner/.secrets/telegram.env` (в учебном GitLab не было доступа к CI/CD Variables) | сначала переменные окружения (GitLab CI/CD Variables, masked + protected); файл с правами 600 — только запасной путь |
| Конфиг стиля не применялся | `.clang-format` лежал в `materials/linters/` — это не родительская папка для `main.c`, поэтому проверка шла по стилю LLVM | `.clang-format` в корне, `main.c` переформатирован под Google (отступ `case`); проверка падает на испорченном форматировании |
| Задеплоенный бинарник был `rwxrwxrwx` | `mv` + `chmod +x` сохраняли права 777 из артефакта: любой пользователь VM2 мог подменить программу в `PATH` | `sudo install -o root -g root -m 755`; хост и пользователь — из `DEPLOY_HOST` / `DEPLOY_USER`, `ssh -o BatchMode=yes` |
| `Makefile` | цель `main` не связана с файлом `DO`, нет флагов предупреждений | `DO: main.c`, `-Wall -Wextra -Werror -std=c11 -O2`, `.PHONY`; повторный `make` ничего не пересобирает |
| `style.sh` | без shebang и `set -e` | `set -euo pipefail`; версия clang-format задаётся через `CLANG_FORMAT` (вывод форматирования отличается между версиями) |

**Остаётся на стороне VM2:** для деплоя группе `sudo` было выдано `NOPASSWD: ALL`. Правильнее отдельный пользователь деплоя с правилом только на установку бинарника, например `deploy ALL=(root) NOPASSWD: /usr/bin/install -o root -g root -m 755 /tmp/DO.* /usr/local/bin/DO`. Но `install` от root — по-прежнему мощная команда, поэтому в продакшене лучше доставка пакетом или pull-модель.

## Как запустить

**Локально** (нужны gcc, make, python3, clang-format):
```bash
cd app && make && cd ..
bash scripts/style.sh
python3 tests/test_integration.py
```

**GitLab:** зарегистрировать runner с тегами `build, style, test, deploy, bot` (shell executor) и задать CI/CD Variables:
`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` (masked, protected), `DEPLOY_HOST`, `DEPLOY_USER`. Ключ `gitlab-runner` должен лежать в `authorized_keys` пользователя деплоя на VM2. Деплой запускается кнопкой ▶ в пайплайне.

**GitHub:** `.github/workflows/ci.yml` запускается на каждый push и PR. В нём только build, style и test: deploy и notify требуют self-hosted runner, prod-VM и секреты бота.

## Результат

Прогон всех стадий в чистом контейнере `ubuntu:24.04` (та же ОС, что на runner и в GitHub Actions):

```console
$ cd app && make
gcc -Wall -Wextra -Werror -std=c11 -O2 main.c -o DO
$ make
make: Nothing to be done for 'all'.

$ CLANG_FORMAT=clang-format-18 bash scripts/style.sh
Ubuntu clang-format version 18.1.3 (1ubuntu1)
Code style OK

$ python3 tests/test_integration.py
Starting integration tests...
PASS: args=[] -> 'Bad number of arguments!' (code 255)
PASS: args=['1'] -> 'Learning to Linux' (code 0)
PASS: args=['6'] -> 'Learning to CI/CD' (code 0)
PASS: args=['7'] -> 'Bad number!' (code 254)
All integration tests passed successfully!

$ TELEGRAM_BOT_TOKEN=123:fake TELEGRAM_CHAT_ID=1 bash scripts/notify.sh "test"
ERROR: Telegram API rejected the message: {"ok":false,"error_code":401,"description":"Unauthorized"}

$ bash scripts/deploy.sh
scripts/deploy.sh: line 8: DEPLOY_HOST: DEPLOY_HOST is not set

$ shellcheck scripts/*.sh        # без замечаний
$ actionlint .github/workflows/ci.yml   # 0 errors
```

- **Учебный прогон в GitLab** (до исправлений): падение на `style`, после форматирования — зелёный пайплайн; все 5 стадий passed; ручной деплой установил `DO` на VM2 (`/usr/local/bin/DO 6` → «Learning to CI/CD»); сообщения «CI passed» и «CD passed» пришли в Telegram.
- **После исправлений** GitLab-часть (deploy, notify и `after_script`) проверена синтаксически и по документации, но заново на runner не запускалась: учебный GitLab и VM недоступны. Build, style и test подтверждаются реальным прогоном GitHub Actions — бейдж вверху.
