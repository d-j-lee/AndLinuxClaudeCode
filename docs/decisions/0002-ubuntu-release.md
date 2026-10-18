# 0002. Ubuntu 릴리스: 24.04 LTS 기본, 26.04 LTS 선택

- 상태: 채택 (2026-10-18). 재검토: 26.04 관련 proot 수정이 한동안 잠잠해지면.

## 맥락

proot-distro 5.x에는 별칭이 없어 `ubuntu`는 Docker Hub `ubuntu:latest`(=26.04.1)이다.
26.04는 rust-coreutils와 sudo-rs가 기본이며 proot에서 연달아 문제가 있었다.

- rust-coreutils "unknown program 'loader'" → Termux proot 5.1.107.72에서 수정
- sudo-rs no-new-privileges 거부 → 5.1.107.77에서 수정
- rust-coreutils 업그레이드 후 하드링크(link2symlink) 경유 **전 명령 실패** → 5.1.107.93(2026-09-22)에서 수정
- proot-distro 관리자: 데스크톱은 Ubuntu 24.04 / Debian 12에서 동작, 더 새 릴리스는 보장하지 않음

실측(2026-10-18, termux-docker x86_64): 24.04.5와 26.04.1 모두 설치·sudo·Claude Code 동작.

## 결정

- 기본 `AL_UBUNTU_RELEASE=24.04` (표준 지원 2029-05).
- 26.04는 선택 가능. Termux proot ≥ 5.1.107.93을 요구하고(설치 시 검사),
  `AL_CLASSIC_SUDO=auto`로 sudo 대안을 classic sudo(`/usr/bin/sudo.ws`)로 바꾼다.
- rust-coreutils는 그대로 둔다. `coreutils-from-gnu`로의 전환은 26.04에서
  `build-essential`이 `coreutils-from-uutils`에 직접 의존해 apt가 즉시 되돌린다(실측,
  2026-10-18). 대신 문제였던 업그레이드 버그가 고쳐진 proot 버전을 강제한다.
- LTS 간 이동은 in-place `do-release-upgrade` 대신 새 컨테이너 + 홈 이전으로 한다
  (proot에서 릴리스 업그레이드는 검증되지 않았고 되돌리기 어렵다).

## 남은 일 (씨앗)

- `andlinux migrate --to 26.04`: 백업 → 새 컨테이너 → `/home` rsync → 전환 자동화.
