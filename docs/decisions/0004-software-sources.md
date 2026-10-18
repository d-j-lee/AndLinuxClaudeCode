# 0004. 소프트웨어 출처: 공식 채널만

- 상태: 채택 (2026-10-18)

## 원칙

"주요 레포와 정식 업데이트"를 지키기 위해 각 소프트웨어는 배포 주체의 공식 채널에서만
받고, 업데이트는 그 채널의 표준 방식(apt 등)으로 한다. snap은 proot에서 동작하지 않으므로
snap 전환 패키지가 있는 소프트웨어는 벤더 APT로 대체한다.

| 소프트웨어 | 출처 | 비고 |
|---|---|---|
| Ubuntu 베이스 | Docker Hub 공식 `ubuntu` 이미지(Canonical 관리) / fallback: cdimage.ubuntu.com ubuntu-base + SHA256 | |
| Ubuntu 패키지 | ports.ubuntu.com (arm64) | `AL_UBUNTU_MIRROR`로 미러 선택 가능, 보안 업데이트는 항상 공식 |
| Claude Code | Anthropic 네이티브 설치기(자동 업데이트) 또는 Anthropic 서명 apt | apt 키 지문 검증 |
| Firefox | packages.mozilla.org APT, pin 1000 | Ubuntu `firefox`는 snap 전환 패키지 |
| VS Code | packages.microsoft.com APT | `--no-sandbox` 래퍼 |
| Google Chrome | dl.google.com APT (arm64 빌드 제공) | full 프로필, `--no-sandbox` 래퍼 |
| GitHub CLI | cli.github.com APT | Ubuntu 패키지는 구버전 |
| mise | mise.jdx.dev APT | Node LTS, uv 등 런타임은 mise가 각 공식 배포처에서 받음 |
| code-server | coder 공식 설치 스크립트(.deb) | apt 저장소 없음 → `andlinux update`가 재실행 |
| cloudflared | pkg.cloudflare.com APT | |

## 검토했지만 택하지 않은 것

- NodeSource APT: Node 하나만 해결. mise가 Node·Python(uv)·Go·Java·Rust를 일관되게 관리.
- xtradeb PPA Chromium: 공식 벤더 채널이 아님 → Google Chrome 공식 arm64로 대체.
- Termux 네이티브 Firefox/Chromium: Ubuntu 데스크톱과 같은 경험(같은 프로필·확장)이 목표라 게스트 쪽 사용.
