# 문제 해결

먼저 `andlinux doctor`를 실행하고, 설치 문제라면
`~/.local/state/andlinux/logs/setup-*.log`의 마지막 부분을 봅니다.
대부분의 문제는 `andlinux setup` 재실행(멱등)으로 수렴합니다.

## 프로세스가 갑자기 죽음 (`[Process completed (signal 9)]`)

안드로이드의 phantom process killer(앱당 자식 프로세스 32개 제한) 또는 메모리 부족입니다.
[setup-guide.md › 2. 안드로이드 설정](setup-guide.md#2-안드로이드-설정-중요)의 두 가지를 적용하세요.
`andlinux doctor`가 설정 상태를 읽을 수 있으면 경고로 알려 줍니다.

## Samsung 백그라운드 성능 저하

One UI 8(Android 16)에서 Termux가 화면에 없을 때 큰 코어를 쓰지 않아 몇 배 느려지는
문제가 보고되어 있습니다([proot-distro#567](https://github.com/termux/proot-distro/issues/567)).
분할 화면으로 Termux를 화면에 두거나, 데스크톱(Termux:X11)을 전면에 둡니다. 근본 대책은
GitHub 판 Termux와 `termux-x11-universal-sharedUid-debug.apk` 조합입니다(Termux:X11이 Termux와
같은 앱으로 취급되어 감속되지 않음).

## 컨테이너 설치 실패: `HTTP Error 429/502` (Docker Hub)

proot-distro 5.x는 Docker Hub의 공식 `ubuntu` 이미지를 받습니다. 익명 다운로드는
횟수 제한이 있어 실패하면 AndLinux가 자동으로 Canonical의 `ubuntu-base` tarball
(cdimage.ubuntu.com, SHA256 검증)로 설치합니다. 둘 다 실패하면 네트워크를 확인하고
`andlinux setup`을 다시 실행하세요.

## `andlinux desktop`: X server did not start

- Termux:X11 **앱**(APK)이 설치되어 있는지 확인합니다. `termux-x11-nightly` 패키지만으로는
  화면이 없습니다.
- 로그: `~/.local/state/andlinux/logs/termux-x11.log`
- 이전 세션이 남았다면 `andlinux stop` 후 다시 시작합니다.

## 데스크톱이 검은 화면이거나 바로 닫힘

- `andlinux desktop`(`--detach` 없이)은 XFCE 세션의 출력을 Termux 창에 그대로 보여
  줍니다. Termux로 돌아가 마지막 오류를 확인하세요.
- 소프트웨어 렌더링에서 합성(compositing)은 꺼 두었습니다(설정 › 창 관리자 조정).
  `AL_GPU=virgl`에서 문제가 생기면 `none`으로 되돌립니다.

## 한글 입력이 느리거나 Caps Lock이 이상함

Termux:X11 설정에서 **Hardware keyboard scancodes workaround를 끕니다**
([termux-x11#746](https://github.com/termux/termux-x11/issues/746)). 하드웨어 키보드는
fcitx5(한/영, Shift+Space)로 입력하고, "Enforce char based input"은 끈 상태로 둡니다.

## Firefox/Chrome/VS Code가 안 뜸

- snap 패키지는 proot에서 동작하지 않습니다. AndLinux는 Mozilla·Google·Microsoft의
  APT 저장소 패키지를 설치하고 `--no-sandbox` 래퍼(`/usr/local/bin/code` 등)를 둡니다.
  `/usr/bin/...`을 직접 실행하면 샌드박스 오류가 날 수 있습니다.
- Firefox 탭이 계속 충돌하면 `about:config`에서 `security.sandbox.content.level`을 `0`으로.

## `sudo: unable to send audit message: Operation not permitted`

Ubuntu 24.04의 sudo가 커널 감사(audit) 소켓을 못 열어 내는 경고입니다. 동작에는
영향이 없습니다(proot에서는 sudo 자체가 보안 경계가 아님).

## OpenSSH 서버(`sshd`)가 proot를 죽임

OpenSSH 9.8+의 `sshd-session`은 proot에서
`path.c: compare_paths2: assertion "length1 > 0" failed`로 세션을 죽입니다(실측).
AndLinux는 그래서 Dropbear를 씁니다(`andlinux svc start ssh`). 게스트에서
`openssh-server`를 직접 띄우지 마세요.

## 백그라운드 서비스가 셸을 닫으면 같이 죽음

proot-distro 로그인 세션은 종료 시 자식 프로세스를 모두 정리합니다(`--kill-on-exit`).
오래 돌릴 프로세스는 `andlinux svc`(분리 세션)나, 분리 세션 안의 `tmux`로 실행하세요.

## Docker / systemctl / snap이 필요함

proot에는 커널 네임스페이스·cgroup·systemd가 없어 불가능합니다. 대안은
[avf.md](avf.md)(Android 가상 머신, 지원 기기 한정)나 원격 Docker 호스트
(`DOCKER_HOST=ssh://user@host`, 게스트에 `docker-ce-cli`만 설치)입니다.

## `Permission denied` / 심볼릭 링크 실패 (`~/Android` 아래)

공유 저장소는 권한·심볼릭 링크·실행 비트를 지원하지 않습니다. 프로젝트를
`~/projects`로 옮기세요.

## 포트 바인딩 실패 (`EACCES` on :80, :443, :22)

비루트 안드로이드 앱은 1024 미만 포트를 열 수 없습니다. 3000 이상을 쓰거나
`andlinux shell -P`(80→2080 등 이동)를 씁니다.

## Ubuntu 26.04에서 명령이 갑자기 전부 실패

26.04 기본 rust-coreutils가 proot의 하드링크 에뮬레이션과 충돌한 사례가 있어
(Termux proot 5.1.107.93에서 수정) AndLinux는 26.04 설치 시 그 이상의 proot를 요구합니다.
Termux에서 `pkg upgrade`로 proot를 최신으로 유지하세요. sudo는 classic으로 바꿉니다
(`AL_CLASSIC_SUDO=auto`). GNU coreutils로의 전환은 26.04의 `build-essential`이
rust-coreutils에 의존해 불가능합니다.

## proot-distro가 업데이트되지 않음 ("holding proot-distro")

의도된 동작입니다. 메이저 업그레이드는 컨테이너를 되돌릴 수 없게 바꿀 수 있습니다.
`andlinux backup` 후 `andlinux update --allow-major`.

## 사내 프록시 / TLS 검사 환경

Termux에서 `HTTPS_PROXY` 등을 설정하면 게스트에도 전달됩니다. 사설 루트 CA가 있다면
PEM 파일을 Termux 홈에 두고 `andlinux config set AL_EXTRA_CA_FILE ~/corp-ca.pem` →
`andlinux setup`. 게스트의 시스템 인증서, Node, Python(requests), apt가 모두 신뢰하게
됩니다. Termux 자체는 `$PREFIX/etc/tls/cert.pem`에 CA를 추가해야 합니다(패키지
업데이트 시 덮어써질 수 있음).

## Thunar에 휴지통·네트워크 위치가 없음

의도된 구성입니다. gvfs는 proot에서 동작하지 않는 udisks2 등 58개 패키지를 끌고 와서
뺐습니다. 필요하면 게스트에서 `sudo apt install gvfs`로 추가할 수 있습니다(휴지통은 동작,
자동 마운트는 불가). 같은 이유로 화면 잠금(xscreensaver 등)도 제거되어 있습니다 — `dev`
사용자에게는 비밀번호가 없어 잠기면 풀 수 없기 때문입니다.
