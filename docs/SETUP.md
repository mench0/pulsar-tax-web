# Pulsar Tax: настройка и запуск

Пошаговая инструкция для бэкенда (Java), веб-версии, Android и iOS — от первого запуска на своём
компьютере до выкладки для пользователей.

| Часть | Репозиторий | Технология |
|---|---|---|
| Бэкенд (API) | [mench0/pulsar-tax](https://github.com/mench0/pulsar-tax) | Java 21, без внешних библиотек |
| Веб, Android, iOS | [mench0/pulsar-tax-web](https://github.com/mench0/pulsar-tax-web) | Flutter (Dart) |

Содержание:

1. [Что установить](#1-что-установить)
2. [Скачать код](#2-скачать-код)
3. [Бэкенд](#3-бэкенд)
4. [Веб-версия](#4-веб-версия)
5. [Android](#5-android)
6. [iOS](#6-ios)
7. [Тесты](#7-тесты)
8. [Выкладка на сервер](#8-выкладка-на-сервер)
9. [Сборка для Google Play и App Store](#9-сборка-для-google-play-и-app-store)
10. [Частые проблемы](#10-частые-проблемы)

---

## 1. Что установить

| Что | Зачем | Где взять |
|---|---|---|
| **Git** | скачать код | https://git-scm.com |
| **JDK 21** или новее | бэкенд | Temurin: https://adoptium.net (проверка: `java -version`) |
| **Flutter 3.47** или новее (канал stable) | веб, Android, iOS | https://docs.flutter.dev/get-started/install (проверка: `flutter --version`) |
| **Google Chrome** | запуск веб-версии при разработке | https://www.google.com/chrome |
| **Android Studio** | Android SDK и эмулятор | https://developer.android.com/studio |
| **Mac с Xcode** | только для iOS | App Store → Xcode |

После установки Flutter выполните `flutter doctor`: он покажет, чего не хватает. Для Android примите
лицензии: `flutter doctor --android-licenses`.

Для работы только с бэкендом и вебом достаточно Git, JDK, Flutter и Chrome.

## 2. Скачать код

Оба репозитория кладите в одну папку: тесты приложения ищут API рядом, в `../pulsar-tax`.

```bash
mkdir pulsar && cd pulsar
git clone https://github.com/mench0/pulsar-tax.git
git clone https://github.com/mench0/pulsar-tax-web.git
```

```
pulsar/
  pulsar-tax/       бэкенд
  pulsar-tax-web/   приложение
```

## 3. Бэкенд

### Сборка и запуск

**macOS и Linux:**

```bash
cd pulsar-tax/pulsar
./build.sh test                 # собрать и прогнать тесты (должно быть «упало: 0»)
java -jar build/pulsar-tax.jar
```

**Windows (PowerShell):**

```powershell
cd pulsar-tax\pulsar
mkdir build\classes -Force
javac --release 21 -encoding UTF-8 -d build\classes (Get-ChildItem -Recurse src\main\java -Filter *.java).FullName
jar --create --file build\pulsar-tax.jar --main-class am.pulsar.tax.Main -C build\classes .
java -jar build\pulsar-tax.jar
```

Сервер напишет:

```
Pulsar Tax API: http://127.0.0.1:8080
Allowed origins: local addresses only
Data dir: /…/pulsar-tax/pulsar/data
Telegram reminders: off
```

Проверка: откройте http://127.0.0.1:8080. Ответ должен быть `{"service":"pulsar-tax-api","status":"ok"}`.
Интерфейса у бэкенда нет, он в приложении.

### Настройки

Все настройки задаются переменными окружения (в PowerShell: `$env:ИМЯ="значение"`).

| Переменная | По умолчанию | Когда менять |
|---|---|---|
| `PULSAR_PORT` | `8080` | Порт занят |
| `PULSAR_HOST` | `127.0.0.1` | `0.0.0.0` — для телефона в той же сети или для сервера |
| `PULSAR_DATA_DIR` | `data` | Где хранить данные и резервные копии |
| `PULSAR_ALLOWED_ORIGINS` | — | Адреса веб-версии через запятую, когда API доступен из сети |
| `PULSAR_SECURE_COOKIE` | `0` | `1` — за HTTPS (на сервере обязательно) |
| `PULSAR_COOKIE_SAMESITE` | `Strict` | `None` — веб-версия на другом домене (нужен HTTPS) |
| `PULSAR_SIGNUP` | `open` | `closed` — закрыть регистрацию новых пользователей |
| `PULSAR_TELEGRAM_TOKEN` | — | Токен бота для напоминаний в Telegram |
| `PULSAR_CBA_URL` | API ЦБ РА | Менять не нужно, используется в тестах |

### Данные

```
data/
  users.json            учётные записи и сессии
  users/{id}.json       данные каждого ИП
  backups/ГГГГ-ММ-ДД/   ежедневные копии, хранятся 14 дней
```

Чтобы восстановить данные, остановите сервер, скопируйте файлы из нужной папки `backups/…` в `data/` и
запустите сервер снова.

### Напоминания в Telegram (по желанию)

1. В Telegram откройте [@BotFather](https://t.me/BotFather) → `/newbot` → скопируйте токен.
2. Запустите API с токеном:
   ```bash
   PULSAR_TELEGRAM_TOKEN=123456:ABC... java -jar build/pulsar-tax.jar
   ```
3. В приложении: «Настройки» → «Подключить Telegram» → в боте нажмите «Start».

Публичный адрес для бота не нужен: сервер сам опрашивает Telegram.

## 4. Веб-версия

API должен быть запущен (раздел 3).

```bash
cd pulsar-tax-web
flutter pub get
flutter run -d chrome
```

Откроется Chrome с приложением. Зарегистрируйтесь — первая учётная запись получит данные старой версии,
если они были.

Пока API слушает `127.0.0.1`, он принимает запросы приложения с любого локального порта, поэтому
`PULSAR_ALLOWED_ORIGINS` при разработке не нужен.

Другой адрес API: `flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:9090`.

## 5. Android

### Эмулятор

1. Android Studio → **Device Manager** → **Create Device** → любой Pixel → образ системы с API 34 или новее
   → **Finish** → запустите эмулятор (▶).
2. Запустите API на компьютере (раздел 3) — как есть, на `127.0.0.1`.
3. Запустите приложение:
   ```bash
   cd pulsar-tax-web
   flutter devices              # в списке должен быть emulator-5554
   flutter run -d emulator-5554
   ```

Эмулятор видит компьютер по адресу `10.0.2.2`, приложение подставляет его само.

### Телефон

1. На телефоне: **Настройки → О телефоне** → 7 раз нажмите «Номер сборки» → в **Для разработчиков**
   включите «Отладка по USB». Подключите кабелем и разрешите отладку.
2. Телефон и компьютер — в одной сети Wi-Fi. Узнайте адрес компьютера: `ipconfig` (Windows),
   `ipconfig getifaddr en0` (macOS) или `hostname -I` (Linux), например `192.168.1.20`.
3. Запустите API так, чтобы он был виден в сети:
   ```bash
   PULSAR_HOST=0.0.0.0 java -jar build/pulsar-tax.jar
   ```
   Разрешите доступ в брандмауэре, если система спросит.
4. Запустите приложение с адресом компьютера:
   ```bash
   flutter run -d <id-телефона> --dart-define=API_BASE=http://192.168.1.20:8080
   ```

Обычный http (без HTTPS) разрешён только в отладочной сборке. Рабочая сборка работает только с API на HTTPS.

## 6. iOS

Нужен Mac с Xcode. Для симулятора аккаунт Apple не нужен; для своего iPhone достаточно бесплатного
Apple ID, для App Store — платный Apple Developer ($99 в год).

### Подготовка (один раз)

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo gem install cocoapods        # или: brew install cocoapods
cd pulsar-tax-web && flutter pub get && (cd ios && pod install)
```

### Симулятор

```bash
open -a Simulator
flutter run -d "iPhone 16"        # имя — из `flutter devices`
```

API на `127.0.0.1` симулятору виден напрямую.

### iPhone

1. Откройте `pulsar-tax-web/ios/Runner.xcworkspace` в Xcode.
2. **Runner → Signing & Capabilities** → Team: свой Apple ID. Если идентификатор `am.pulsar.pulsarTax`
   занят — поменяйте Bundle Identifier на свой (например `am.pulsar.tax.dev`).
3. Подключите iPhone, на телефоне: **Настройки → Конфиденциальность → Режим разработчика** → включить.
4. API запустите с `PULSAR_HOST=0.0.0.0`, как для Android, и:
   ```bash
   flutter run -d <id-iphone> --dart-define=API_BASE=http://192.168.1.20:8080
   ```
5. При первом запуске iPhone спросит доступ к локальной сети — разрешите. Если приложение «не доверено»:
   **Настройки → Основные → VPN и управление устройством** → доверять своему Apple ID.

Обычный http разрешён только к адресам локальной сети. Рабочие сборки ходят в API по HTTPS.

## 7. Тесты

```bash
# бэкенд
cd pulsar-tax/pulsar && ./build.sh test

# приложение (сквозные тесты сами запускают API из ../pulsar-tax/pulsar/build/pulsar-tax.jar)
cd pulsar-tax-web
flutter analyze
flutter test
```

Если API лежит в другом месте: `PULSAR_JAR=/путь/к/pulsar-tax.jar flutter test`.
Без jar сквозные тесты пропускаются, остальные выполняются.

В GitHub Actions (`.github/workflows/ci.yml`) на каждый push собираются API, веб, APK и iOS без подписи.

## 8. Выкладка на сервер

Пример для VPS на Ubuntu 24.04 (от 1 ГБ памяти) и домена `pulsar.am`:
API на `api.pulsar.am`, веб-версия на `app.pulsar.am`. Оба поддомена направьте A-записями DNS на IP сервера.

### 8.1. Сервер

```bash
sudo apt update && sudo apt install -y openjdk-21-jre-headless caddy
sudo useradd --system --create-home --home-dir /opt/pulsar pulsar
```

Соберите jar на своём компьютере (`./build.sh test`) и скопируйте:

```bash
scp pulsar/build/pulsar-tax.jar root@СЕРВЕР:/opt/pulsar/
```

### 8.2. API как служба

`/etc/systemd/system/pulsar-api.service`:

```ini
[Unit]
Description=Pulsar Tax API
After=network.target

[Service]
User=pulsar
WorkingDirectory=/opt/pulsar
ExecStart=/usr/bin/java -jar /opt/pulsar/pulsar-tax.jar
Environment=PULSAR_HOST=127.0.0.1
Environment=PULSAR_PORT=8080
Environment=PULSAR_DATA_DIR=/opt/pulsar/data
Environment=PULSAR_SECURE_COOKIE=1
Environment=PULSAR_ALLOWED_ORIGINS=https://app.pulsar.am
# Environment=PULSAR_TELEGRAM_TOKEN=…
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo chown -R pulsar:pulsar /opt/pulsar
sudo systemctl daemon-reload && sudo systemctl enable --now pulsar-api
sudo journalctl -u pulsar-api -f        # журнал
```

API слушает только `127.0.0.1`, наружу его выставляет Caddy с HTTPS.

### 8.3. Веб-версия

На своём компьютере:

```bash
cd pulsar-tax-web
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE=https://api.pulsar.am
scp -r build/web/* root@СЕРВЕР:/var/www/pulsar-app/
```

### 8.4. HTTPS и адреса (Caddy)

`/etc/caddy/Caddyfile`:

```
api.pulsar.am {
    reverse_proxy 127.0.0.1:8080
}

app.pulsar.am {
    root * /var/www/pulsar-app
    try_files {path} /index.html
    file_server
}
```

```bash
sudo systemctl reload caddy
```

Caddy сам получит сертификаты Let's Encrypt. Проверка: https://api.pulsar.am отвечает статусом,
https://app.pulsar.am открывает приложение.

### 8.5. Резервные копии

API каждый день копирует данные в `/opt/pulsar/data/backups`. Копии на том же сервере не спасут при его
потере — раз в сутки забирайте папку `/opt/pulsar/data` на другой компьютер или в облачное хранилище
(например `rsync` по cron).

### 8.6. Обновление

```bash
scp pulsar/build/pulsar-tax.jar root@СЕРВЕР:/opt/pulsar/
sudo systemctl restart pulsar-api
```

## 9. Сборка для Google Play и App Store

Во всех рабочих сборках указывайте адрес API: `--dart-define=API_BASE=https://api.pulsar.am`.

**Перед первой публикацией:** своя иконка и экран запуска, окончательный идентификатор приложения
(сейчас `am.pulsar.pulsar_tax` на Android и `am.pulsar.pulsarTax` на iOS), вычитанный армянский перевод.

### Android (Google Play, разовый взнос $25)

1. Создайте ключ подписи (храните его и пароль в надёжном месте — без них приложение не обновить):
   ```bash
   keytool -genkey -v -keystore ~/pulsar-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Создайте `android/key.properties` (в git не добавлять):
   ```properties
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/Users/вы/pulsar-upload.jks
   ```
3. Подключите ключ в `android/app/build.gradle.kts` вместо отладочного (сейчас там
   `signingConfig = signingConfigs.getByName("debug")`) — по инструкции
   https://docs.flutter.dev/deployment/android#configure-signing-in-gradle.
4. Сборка:
   ```bash
   flutter build appbundle --release --dart-define=API_BASE=https://api.pulsar.am
   ```
   Файл `build/app/outputs/bundle/release/app-release.aab` загрузите в Google Play Console.

### iOS (App Store, Apple Developer $99 в год)

1. В https://developer.apple.com зарегистрируйте идентификатор приложения, в App Store Connect создайте
   приложение.
2. В Xcode (`ios/Runner.xcworkspace`) → Signing & Capabilities → Team: ваша команда разработчика.
3. Сборка:
   ```bash
   flutter build ipa --release --dart-define=API_BASE=https://api.pulsar.am
   ```
4. Загрузите `build/ios/ipa/*.ipa` через приложение **Transporter** или
   `xcrun altool --upload-app`. Перед публикацией — тест через TestFlight.

## 10. Частые проблемы

| Симптом | Причина и решение |
|---|---|
| `java: command not found` или ошибка про версию 21 | Установите JDK 21+ и перезапустите терминал |
| `Address already in use` | Порт 8080 занят: `PULSAR_PORT=8081`, и в приложении `--dart-define=API_BASE=http://127.0.0.1:8081` |
| В приложении бесконечная загрузка или ошибка сети | API не запущен или неверный `API_BASE`. Проверьте адрес в браузере телефона |
| Android на телефоне не видит API | API запущен без `PULSAR_HOST=0.0.0.0`, брандмауэр, или телефон в другой сети |
| Веб: «Запрос с другого сайта отклонён» (403) | Адрес веб-версии не указан в `PULSAR_ALLOWED_ORIGINS` |
| Веб на сервере: после входа снова просит войти | Нет HTTPS или не задан `PULSAR_SECURE_COOKIE=1`; для разных доменов — `PULSAR_COOKIE_SAMESITE=None` |
| «Курс ЦБ РА недоступен» | Сервер не достучался до `api.cba.am` (сеть или брандмауэр). Курс можно ввести вручную |
| iOS: `pod install` с ошибкой | `sudo gem install cocoapods`, затем `cd ios && pod repo update && pod install` |
| iOS: «Untrusted Developer» | Настройки → Основные → VPN и управление устройством → доверять |
| `flutter test` пропускает сквозные тесты | Нет jar API: соберите `./build.sh` в `pulsar-tax/pulsar` или задайте `PULSAR_JAR` |
| Файл данных повреждён, API не стартует | Восстановите `data/` из `data/backups/ГГГГ-ММ-ДД/` (раздел 3) |
