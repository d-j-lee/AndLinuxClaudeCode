# 아키텍처

AndLinux는 안드로이드 기기 위에 "Ubuntu LTS 데스크톱 + Claude Code" 개발 환경을
코드로 구성합니다. 이 문서는 구조, 경계, 설계 원칙을 설명합니다. 결정의 배경과
대안 비교는 [decisions/](decisions/)에 있습니다.

## 계층

```
┌──────────────────────────────── Android (루팅 불필요) ────────────────────────────────┐
│  Termux:X11 앱 (X 서버 화면)     Termux:API 앱 (공유시트·클립보드)     Tailscale 앱(선택) │
│ ┌───────────────────────────── Termux 앱 (호스트) ─────────────────────────────────┐ │
│ │  andlinux CLI · pkg(Termux 공식 저장소) · proot-distro 5.x · termux-x11 · pulseaudio │ │
│ │ ┌──────────────────── proot 컨테이너 "andlinux" (게스트) ───────────────────────┐ │ │
│ │ │  Ubuntu 24.04 LTS arm64 (공식 이미지, 공식 apt)                              │ │ │
│ │ │  사용자 dev(sudo) · XFCE · fcitx5-hangul · Firefox · VS Code · Claude Code   │ │ │
│ │ │  mise(Node/uv/…) · gh · Dropbear SSH :2222 · code-server :8080(선택)         │ │ │
│ │ └────────────────────────────────────────────────────────────────────────────────┘ │ │
│ └────────────────────────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| 계층 | 담당 | 업데이트 채널 |
|---|---|---|
| Android | 앱 설치, 개발자 옵션, 배터리 정책 | 사용자 |
| Termux 호스트 | 패키지, X 서버, 오디오, proot 실행, `andlinux` CLI | Termux 공식 저장소 (`pkg`) |
| Ubuntu 게스트 | 실제 개발 환경 전부 | Ubuntu 공식 저장소 + 벤더 공식 저장소 |
| Claude Code | 게스트 사용자 영역 (`~/.local/bin/claude`) | Anthropic 공식 네이티브 설치기(자동) 또는 공식 apt |
| 툴킷 자체 | 이 저장소 (`~/.andlinux`) | `git pull` (`andlinux update`) |

## proot가 주는 것과 못 주는 것

proot는 ptrace로 시스템 콜을 가로채 경로를 바꾸고 root를 흉내 냅니다. 커널은
안드로이드 커널 그대로이고, 모든 프로세스는 Termux 앱의 안드로이드 UID로 돕니다.

| 항목 | Ubuntu 데스크톱 | AndLinux | 대응 |
|---|---|---|---|
| apt / 공식 저장소 | O | O | 동일. snap만 불가 → 벤더 APT로 대체 |
| GUI 데스크톱 | O | O (XFCE, Termux:X11) | 소프트웨어 렌더링 기본, virgl 선택 |
| Claude Code | O | O | `/sandbox`(bubblewrap)만 불가 |
| Electron/Chromium 앱 | O | O | `--no-sandbox` 래퍼 자동 적용 |
| systemd / `systemctl` | O | X | `andlinux svc`(분리 세션)로 대체 |
| Docker / Podman | O | X | AVF VM(지원 기기) · 원격 `DOCKER_HOST` ([avf.md](avf.md)) |
| 1024 미만 포트 | O (root) | X | 1024 이상 사용, 또는 `-P` 포트 이동 |
| FUSE / 마운트 | O | X | `rclone sync`, `/sdcard` 바인드로 대체 |
| 파일 I/O 성능 | 기준 | 수 배 느림 | 프로젝트는 rootfs 안(`~/projects`)에 |

## 보안 모델

- **실제 경계는 안드로이드 앱 샌드박스**입니다. 게스트의 root와 `sudo`는 흉내일 뿐이라,
  게스트에서 할 수 있는 일 = Termux 앱이 할 수 있는 일입니다: Termux 데이터, 저장소
  권한을 준 공유 저장소(`/sdcard`), 네트워크.
- 그래서 `sudo`는 비밀번호 없이 둡니다(보안 이득 없이 마찰만 생기므로).
- Claude Code의 권한 모드 판단 기준도 같습니다. `--dangerously-skip-permissions`를 쓰면
  Claude가 위 범위 전체(공유 저장소 포함)를 건드릴 수 있습니다. 비루트 사용자(`dev`)를
  쓰는 이유는 Claude Code가 root에서 이 옵션을 거부하기 때문이지 격리 때문이 아닙니다.
- SSH는 키 인증만 허용하고(`-s`), root 로그인을 막습니다(`-w`).
- 벤더 저장소 키는 `/etc/apt/keyrings`에 저장소별로 두고 `Signed-By`로 묶습니다.
  Claude Code apt 키는 문서에 게시된 지문을 검증합니다.

## 저장소 구조

```
install.sh              Termux 진입점 (curl | bash) → ~/.andlinux 설치, andlinux setup 실행
bin/andlinux            CLI 디스패처
lib/common.sh           호스트·게스트 공용 헬퍼 (로그, 재시도, 관리 블록 쓰기)
lib/host.sh             Termux 헬퍼 (설정 로드, 게스트 로그인 래퍼, 환경 전달)
lib/cmd/<명령>.sh       서브커맨드 구현 (setup, desktop, svc, update, doctor, ...)
config/defaults.env     모든 설정의 기본값과 설명 (덮어쓰기는 ~/.config/andlinux/config.env)
guest/provision.sh      게스트 프로비저닝 진입점 (root로 실행, 프로필 → 모듈)
guest/lib.sh            게스트 헬퍼 (apt, 벤더 저장소, 사용자 실행, 템플릿)
guest/modules/<m>.sh    모듈 = mod_<m> 함수 하나. 순서는 provision.sh가 정의
guest/bin/              게스트 /usr/local/bin에 설치되는 도구 (android-open 등)
guest/files/            게스트에 쓰는 템플릿 (@AL_VAR@ 치환)
tests/                  E2E(Termux Docker), arm64 게스트 검증, 게스트 점검 스크립트
docs/                   핵심 문서 + decisions/(ADR)
```

## 상태 위치

| 위치 | 내용 |
|---|---|
| `~/.andlinux` (Termux) | 툴킷 코드 (git) |
| `~/.config/andlinux/config.env` | 사용자 설정 덮어쓰기 |
| `~/.local/state/andlinux/` | 로그(`logs/`), 서비스 PID(`run/`), 게스트 설정 사본 |
| `$PREFIX/var/lib/proot-distro/containers/andlinux/` | 게스트 rootfs (proot-distro 관리) |
| 게스트 `/etc/andlinux/` | 적용된 설정, 안드로이드 환경 변수 사본, 프로비저닝 기록 |

## 설계 원칙

1. **멱등성**: 모든 단계는 상태를 확인한 뒤 바꿉니다. `andlinux setup`은 몇 번을 다시
   돌려도 같은 결과로 수렴합니다. 사용자 파일은 "없을 때만 생성"하거나 표시된 관리
   블록(`>>> andlinux >>>`)만 교체합니다.
2. **공식 채널만**: Ubuntu 공식 이미지·저장소, 벤더 공식 APT(Mozilla, Microsoft,
   GitHub, mise, Google, Cloudflare), Anthropic 공식 설치기. 출처가 불분명한
   스크립트·PPA·바이너리는 쓰지 않습니다.
3. **세션 일관성**: CLI·데스크톱·SSH·IDE 원격·Claude Code의 Bash 도구가 같은 PATH,
   로케일, 환경을 보도록 `/etc/profile.d/andlinux.sh` 하나에서 정의하고, 비대화형
   bash도 읽도록 `/etc/bash.bashrc` 맨 위에서 불러옵니다. 모든 세션은 `/tmp`를
   Termux와 공유합니다(X11·virgl 소켓).
4. **안전한 업데이트**: 컨테이너를 되돌릴 수 없게 마이그레이션할 수 있는 proot-distro
   메이저 업그레이드는 `--allow-major` 없이는 보류합니다.
5. **사실 기반**: 버전·호환성 주장은 실측이나 1차 출처로 확인하고 ADR에 근거를 남깁니다.

## 모듈 추가하기

1. `guest/modules/<이름>.sh`에 `mod_<이름>()`을 만듭니다(하이픈은 밑줄로).
2. `guest/provision.sh`의 `G_ALL_MODULES` 순서와 필요한 프로필에 추가합니다.
3. 패키지는 `g_install`, 벤더 저장소는 `g_add_apt_repo`, 사용자 권한 작업은
   `g_as_user`, 사용자 설정 파일은 `g_user_file`(없을 때만)을 씁니다.
4. `tests/guest-checks.sh`에 확인 항목을 넣고 `tests/e2e-termux.sh`로 검증합니다.
