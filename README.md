# AndLinux — 안드로이드에서 돌아가는 Ubuntu 개발 데스크톱 + Claude Code

루팅 없는 안드로이드 폰·태블릿에 **Ubuntu LTS 데스크톱 개발 환경과 Claude Code**를
한 줄로 설치하고, 한 명령으로 최신 상태를 유지합니다. Ubuntu PC에서 Claude Code를 쓰던
방식(apt, VS Code, 브라우저, 터미널, SSH, git, 개발 서버)을 그대로 쓰되, 실제 동작은
폰 안에서 합니다.

```bash
# Termux(F-Droid/GitHub 판)에서
curl -fsSL https://raw.githubusercontent.com/d-j-lee/AndLinuxClaudeCode/main/install.sh | bash
andlinux claude        # Claude Code
andlinux desktop       # XFCE 데스크톱 (Termux:X11)
andlinux update        # 전 계층을 공식 채널로 업데이트
```

## 무엇이 되나

| | Ubuntu PC | AndLinux | 방식 |
|---|---|---|---|
| Ubuntu 공식 저장소·업데이트 | ✅ | ✅ | Ubuntu 24.04 LTS arm64 (26.04 선택), `apt` 그대로 |
| Claude Code | ✅ | ✅ | Anthropic 공식 설치기, 자동 업데이트. `/sandbox`만 불가 |
| GUI 데스크톱 | ✅ | ✅ | XFCE + Termux:X11, 한글 폰트·fcitx5-hangul |
| VS Code · Firefox · Chrome | ✅ | ✅ | Microsoft·Mozilla·Google 공식 APT (snap 대신) |
| Node · Python · Go · Rust · Java | ✅ | ✅ | mise(공식 APT) + uv, build-essential |
| GitHub CLI · git | ✅ | ✅ | cli.github.com 공식 APT |
| PC에서 SSH / VS Code Remote | ✅ | ✅ | 게스트 SSH :2222 (키 인증) |
| 안드로이드와 파일 교환 | — | ✅ | `~/Android`(=/sdcard), 공유시트·클립보드·브라우저 연동 |
| 개발 서버 호스팅 | ✅ | ✅ | localhost 공유, LAN, Tailscale, Cloudflare 터널 |
| 백업·복원 | — | ✅ | 컨테이너 통째로 공유 저장소(+Google Drive) |
| Docker · systemd | ✅ | ❌ | proot 한계 → `andlinux svc`, [Android VM](docs/avf.md), 원격 Docker |
| 파일 I/O 속도 | 기준 | 느림 | ptrace 기반. 프로젝트는 `~/projects`에 |

## 구조

```
Android ─ Termux (andlinux CLI, pkg, proot-distro) ─ Ubuntu LTS 게스트 (dev 사용자, 개발 환경 전부)
        └ Termux:X11 (화면) · Termux:API (공유/클립보드) · Tailscale (선택)
```

모든 소프트웨어는 배포 주체의 공식 채널에서만 받고 그 채널로 업데이트합니다
([decisions/0004](docs/decisions/0004-software-sources.md)). 설치는 멱등이라 언제든
`andlinux setup`을 다시 실행해 원하는 상태로 수렴시킬 수 있습니다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/setup-guide.md](docs/setup-guide.md) | 기기 준비(앱·안드로이드 설정), 설치, 첫 실행 |
| [docs/operations.md](docs/operations.md) | 명령, 업데이트, 파일 교환, 호스팅, PC 접속, Claude Code, 백업 |
| [docs/troubleshooting.md](docs/troubleshooting.md) | 증상별 해결 |
| [docs/architecture.md](docs/architecture.md) | 계층, 보안 모델, 저장소 구조, 모듈 추가 |
| [docs/avf.md](docs/avf.md) | Android Linux Terminal(VM): Docker가 필요할 때 |
| [docs/decisions/](docs/decisions/) | 설계 결정 기록 (ADR) |
| [config/defaults.env](config/defaults.env) | 모든 설정과 기본값 |

## 프로필

| 프로필 | 내용 | 여유 공간 |
|---|---|---|
| `cli` | Ubuntu, dev 사용자, 안드로이드 연동, 개발 도구, Claude Code, SSH | ~4 GB |
| `desktop` (기본) | cli + XFCE, 한국어 입력·폰트, Firefox, VS Code | ~8 GB |
| `full` | desktop + code-server, Google Chrome, cloudflared, Go/Java/Rust | ~12 GB |

`andlinux setup --profile full`처럼 언제든 바꿀 수 있습니다.

## 검증 범위

실기기 없이 확인할 수 있는 것은 모두 실제로 실행해 확인했습니다(2026-10-18). E2E는 공식 Termux Docker 이미지(x86_64 — proot의 ptrace가 QEMU 에뮬레이션에서 동작하지 않아 arm64 Termux는 재현 불가)에서 돌렸고, arm64는 패키지·프로비저닝 수준으로 따로 확인합니다.

| 검증 | 방법 | 결과 |
|---|---|---|
| 정적 분석 | shellcheck, 전 스크립트 | 통과 |
| 전체 설치 (cli, 24.04) | 공식 `termux/termux-docker` 이미지에서 `install.sh`부터: 설치 → 재실행 → 게스트 점검 20항목 → SSH → doctor → 백업·복원 | 통과. 첫 설치 301초, 재실행 15초(멱등), 백업 538 MB(zstd) |
| 전체 설치 (cli, 26.04) | 위와 같음 + 실패 후 재실행 수렴 | 통과. 첫 설치 310초, 재실행 16초, classic sudo 전환 확인 |
| 업데이트 | `andlinux update` (Termux → 게스트 재수렴 → apt full-upgrade → Claude Code → mise) | 통과, 변경 없을 때 38초 |
| 호스팅 | `andlinux tunnel`: cloudflared 자동 설치, quick tunnel URL 발급 | URL 발급까지 확인 (엣지 연결은 검증 환경 DNS 제약으로 미확인) |
| 장애 대비 경로 | 고장 난 Termux 미러 → 공식 미러로 자동 전환, Docker Hub 실패 → Canonical ubuntu-base(SHA256 검증)로 설치 | 통과 |
| PC 접속 | SSH 비대화형 세션 환경 일치, VS Code 서버 1.142.0을 게스트에서 기동 → SSH 로컬 포워딩으로 응답 확인 | 통과 |
| 전체 모듈 (full) | proot 없는 Ubuntu 24.04 컨테이너에서 전 모듈(code-server 제외) | 통과 |
| 데스크톱 (desktop, 24.04) | 전체 설치 후 XFCE 세션을 Xvfb에 띄워 패널·데스크톱·fcitx5·VS Code·Firefox·터미널 창 확인 | 통과 ([캡처](docs/images/e2e-desktop-xvfb.png)). 데스크톱 모듈 115초. fcitx5 자동 시작은 이 검증에서 발견해 고친 뒤 같은 컨테이너에서 재확인 |
| arm64 | Ubuntu 26.04 arm64에서 사용 패키지 ~95종 가용성(QEMU), CI는 네이티브 arm64 러너에서 프로비저닝 | 가용성 확인 / CI |
| 실기기 | 안드로이드 커널·SELinux·Termux:X11 앱 화면·한글 IME | **미검증** — 첫 실기기 결과를 이슈로 남겨 주세요 |

code-server는 이 검증 환경이 github.com 릴리스 다운로드를 막아 CI에서만 확인합니다.

## 기여

설계 원칙과 수정 방법은 [CLAUDE.md](CLAUDE.md)와 [docs/architecture.md](docs/architecture.md)를 따릅니다.
변경 이력은 [CHANGELOG.md](CHANGELOG.md).
