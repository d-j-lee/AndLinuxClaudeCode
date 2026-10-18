# 설치 가이드

처음 한 번만 하는 기기 준비와 설치 절차입니다. 설치 후 쓰는 법은
[operations.md](operations.md), 문제 해결은 [troubleshooting.md](troubleshooting.md)에 있습니다.

## 0. 요구 사항

| 항목 | 최소 | 권장 |
|---|---|---|
| CPU | 64비트 ARM (aarch64) | 최근 2~3년 플래그십급 |
| Android | 7.0 (Termux 요구) | 12 이상 |
| RAM | 4 GB (Claude Code 요구) | 8 GB 이상 |
| 여유 저장공간 | cli 4 GB / desktop 8 GB | 16 GB 이상 |
| 루팅 | 불필요 | — |

입력 장치: 데스크톱을 본격적으로 쓰려면 블루투스 키보드·마우스, 또는 Samsung DeX /
데스크톱 모드 외부 모니터를 권장합니다.

## 1. 앱 설치

**Termux와 그 플러그인은 반드시 같은 출처에서** 받습니다(공유 서명 UID 때문에 출처를
섞으면 `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE`로 설치가 실패합니다).

| 앱 | 필수 | 받는 곳 |
|---|---|---|
| Termux | 필수 | [F-Droid](https://f-droid.org/packages/com.termux/) 또는 [GitHub Releases](https://github.com/termux/termux-app/releases) (`apt-android-7` 변형) |
| Termux:X11 | desktop 프로필 | [GitHub nightly](https://github.com/termux/termux-x11/releases/tag/nightly)의 `termux-x11-universal-debug.apk` (F-Droid에 없음, Termux 출처와 무관). GitHub 판 Termux라면 `termux-x11-universal-sharedUid-debug.apk`도 가능 — Termux와 한 앱으로 취급돼 백그라운드 감속을 피함 |
| Termux:API | 권장 | Termux와 같은 출처. `android-share`, `android-clip`에 필요 |
| Termux:Widget | 선택 | 홈 화면 바로가기 (설치 시 자동 생성되는 `~/.shortcuts`) |
| Termux:Boot | 선택 | 부팅 시 서비스 자동 시작 (`AL_BOOT_SERVICES`) |
| Tailscale | 선택 | 외부에서 폰의 SSH·개발 서버 접속 |

Google Play 판 Termux는 별도 코드베이스의 실험판이며 Termux:API 앱이 없습니다.
AndLinux는 F-Droid / GitHub 판을 기준으로 합니다.

## 2. 안드로이드 설정 (중요)

데스크톱·Claude Code처럼 프로세스를 많이 띄우는 작업은 이 설정 없이는 `signal 9`로
강제 종료됩니다.

1. **자식 프로세스 제한 해제 (phantom process killer)**
   - Android 14 이상: 설정 › 개발자 옵션 › **"하위 프로세스 제한 사용 중지"**
     (영문 "Disable child process restrictions"). 개발자 옵션을 끄면 함께 초기화됩니다.
   - Android 12L 이상, 영구 적용 (PC의 adb 또는 무선 디버깅):
     ```
     adb shell settings put global settings_enable_monitor_phantom_procs false
     ```
   - Android 12 (초기판):
     ```
     adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent; /system/bin/device_config put activity_manager max_phantom_processes 2147483647"
     ```
2. **배터리 최적화 해제**: 설정 › 앱 › Termux › 배터리 › **제한 없음**.
   Termux:X11도 동일하게 설정하면 좋습니다.
3. Samsung One UI 8 이상: Termux가 백그라운드일 때 큰 코어를 쓰지 않아 크게 느려지는
   문제가 보고되어 있습니다. 데스크톱(Termux:X11)을 전면에 두거나, GitHub 판 Termux +
   `sharedUid` Termux:X11 조합을 쓰세요 ([troubleshooting.md](troubleshooting.md#samsung-백그라운드-성능-저하)).

## 3. 설치

Termux를 열고 한 줄을 실행합니다.

```bash
curl -fsSL https://raw.githubusercontent.com/d-j-lee/AndLinuxClaudeCode/main/install.sh | bash
```

- 저장소 접근 권한을 묻는 창이 뜨면 **허용**합니다(`~/Android` 공유 폴더에 필요).
- 기본 프로필은 `desktop`입니다. CLI만 원하면 `| bash -s -- --profile cli`,
  전부 원하면 `--profile full`.
- 처음 설치는 네트워크와 기기에 따라 수십 분 걸립니다. 중간에 끊겨도
  `andlinux setup`을 다시 실행하면 이어서 수렴합니다.
- 로그: `~/.local/state/andlinux/logs/setup-*.log`

설치 전에 설정을 바꾸고 싶다면(예: 사용자명, 언어, Ubuntu 26.04):

```bash
mkdir -p ~/.config/andlinux
cat > ~/.config/andlinux/config.env <<'EOF'
AL_USER=dj
AL_LANG=ko_KR.UTF-8
EOF
```

모든 설정과 설명은 [config/defaults.env](../config/defaults.env)에 있습니다.

## 4. 첫 실행

```bash
andlinux doctor      # 상태 점검 (FAIL 0 이 목표)
andlinux claude      # Claude Code 시작 → 로그인
andlinux desktop     # XFCE 데스크톱 (Termux:X11 앱이 앞으로 나옵니다)
```

**Claude Code 로그인**: 데스크톱이 없는 CLI 세션에서는 로그인 URL이 안드로이드
브라우저로 열립니다(`BROWSER=android-open`). proot는 안드로이드와 네트워크를
공유하므로 브라우저의 `localhost` 콜백이 그대로 Claude Code에 도달합니다. 자동으로
안 열리면 `c`로 URL을 복사해 브라우저에 붙여 넣고, 표시되는 코드를 터미널에 붙여
넣으면 됩니다.

## 5. Termux:X11 권장 설정

Termux:X11 앱의 설정(알림 또는 화면 가장자리 메뉴 › Preferences):

| 설정 | 권장 | 이유 |
|---|---|---|
| Display resolution mode | `native` 또는 `scaled` | 고해상도 폰에서는 scaled가 읽기 쉬움 |
| Fullscreen | 켜기 | 화면 확보 |
| Touchscreen input mode | Trackpad(마우스처럼) 또는 Direct touch | 취향 |
| Hardware keyboard scancodes workaround | **끄기** | 켜져 있으면 한글 입력 지연·Caps Lock 오류 보고 |
| Enforce char based input | 끄기 | 켜면 한글 조합 입력이 막힘 |

한글 입력: 하드웨어 키보드는 데스크톱 안의 fcitx5-hangul을 씁니다
(**한/영 키, Shift+Space, Ctrl+Space**). 안드로이드 소프트 키보드의 한글은 Termux:X11이
조합 문자를 전달하므로 대부분 동작하지만 지연이 있을 수 있습니다.

## 6. 다음 단계

- PC에서 SSH / VS Code Remote-SSH로 접속: [operations.md#pc에서-접속](operations.md#pc에서-접속)
- 파일 주고받기, 개발 서버 공개, 백업: [operations.md](operations.md)
- Docker가 꼭 필요하면: [avf.md](avf.md)
