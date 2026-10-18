# Android Linux Terminal (AVF) — Docker가 필요할 때

Android에는 개발자 옵션으로 켜는 공식 **Linux 개발 환경**(Linux Terminal 앱,
Android Virtualization Framework)이 있습니다. proot와 달리 **진짜 VM**(Debian, 자체
리눅스 커널)이라 systemd, Docker, user namespace(Claude Code `/sandbox`)가 동작합니다.
AndLinux의 주 경로(Termux + proot)를 대체하지는 않고, Docker가 필요한 작업을 맡는
보조 계층으로 씁니다. 근거: [decisions/0001](decisions/0001-runtime.md).

## 내 기기에서 되나?

`andlinux doctor`가 "this device can run Android's Linux Terminal VM"을 표시하면
가능성이 있습니다(`ro.boot.hypervisor.vm.supported=true`). 2026-10 기준 상황:

| 기기 | 상태 |
|---|---|
| Pixel 6 이후 (공식 목록은 Pixel 7~9 계열) | 동작 |
| Pixel 10 | 동작, GPU 렌더링(gfxstream)까지 가능한 유일한 계열 |
| Galaxy — Exynos / MediaTek 칩 (예: Z Flip7, S26/S26+ Exynos, Tab S11) | 동작 보고 |
| Galaxy — Snapdragon 칩 (예: S26 Ultra, Z Fold7) 및 Snapdragon 기기 전반 | **불가** (Qualcomm 하이퍼바이저가 비보호 VM을 허용하지 않음) |

요구 조건: RAM 4 GB+, 저장공간 16 GB+, 펌웨어에 Terminal 앱 포함. 상태: Android 17
QPR1에서도 "실험적" 기능입니다.

## 켜기와 특징

설정 › 시스템 › 개발자 옵션 › **Linux 개발 환경** 켜기 → Terminal 앱 실행 → 설치.

| 항목 | 내용 |
|---|---|
| 게스트 | Debian 13 (arm64), systemd, 사용자 `droid` (비밀번호 `droid` → 바로 변경) |
| Docker | 커널이 지원. `sudo apt install docker.io` (구형 이미지는 iptables-legacy 필요 보고) |
| GUI | Android 16 QPR2+: Display 버튼(Weston/Xwayland). 기본은 CPU 렌더링 |
| 네트워크 | 리스닝 포트마다 "포트 전달 허용?" 확인 → **폰의 localhost에서만** 접근 가능, LAN 불가 |
| 파일 | `/mnt/shared` = 안드로이드 Download(16) 또는 내부 저장소 전체(16 QPR2+, 전체 파일 접근 권한) |
| 약점 | 화면 꺼짐·메모리 부족 시 VM 종료, 리셋/토글 끄기 시 데이터 삭제, IME(한글) 불안정 |

## AndLinux와 함께 쓰는 법

1. **Docker 호스트로 쓰기**: VM 안에서 Docker를 띄우고, AndLinux 게스트(proot)에서는
   Docker CLI로 원격 접속합니다. VM의 SSH 포트를 열고(포트 전달 허용) 키를 등록한 뒤:
   ```bash
   # AndLinux 게스트에서
   sudo apt install docker.io       # 클라이언트만 씀 (데몬은 proot에서 뜨지 않음)
   export DOCKER_HOST=ssh://droid@localhost:2223   # VM sshd를 2223에 (2222는 AndLinux SSH)
   docker run --rm hello-world
   ```
2. **VM 안에서 Claude Code 직접 실행**: Anthropic 네이티브 설치기가 linux-arm64로
   동작합니다(`curl -fsSL https://claude.ai/install.sh | bash`). `/sandbox`(bubblewrap)도
   VM 커널에서는 동작할 수 있습니다.
3. **Ubuntu가 꼭 필요하면**: VM 안에서 `docker run -it ubuntu:24.04` 또는
   `systemd-nspawn`/`incus`로 Ubuntu 컨테이너를 씁니다.

키 입력·복사가 불편한 Terminal 앱 대신, Termux에서 `ssh -p <포트> droid@localhost`로
VM에 들어가는 방식을 권장합니다.

## 향후 (씨앗)

`guest/` 모듈은 Debian 계열 apt 기반이라 VM 안에서 재사용할 여지가 있습니다
(`AL_CONFIG_FILE=... bash guest/provision.sh base user devtools claude`). 아직 VM에서
검증하지 않았으므로 공식 지원 범위는 아닙니다. 필요해지면 `andlinux avf` 서브커맨드로
승격합니다.
