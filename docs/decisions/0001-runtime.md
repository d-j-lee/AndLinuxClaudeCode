# 0001. 실행 기반: Termux + proot-distro (주), AVF VM (보조)

- 상태: 채택 (2026-10-18)

## 맥락

목표는 "Ubuntu GUI에서 Claude Code를 쓰는 것과 같은 개발 환경을 안드로이드에서".
조건: 루팅 없는 일반 폰, 공식 저장소·정식 업데이트, 파일 교환·호스팅 가능.

## 선택지

| 선택지 | 장점 | 단점 |
|---|---|---|
| **Termux + proot-distro + Ubuntu** | 모든 arm64 기기, 루팅 불필요, Ubuntu 공식 이미지·apt 그대로, 네트워크·파일 공유가 쉬움 | systemd·Docker·namespace 없음, ptrace로 I/O 느림 |
| Android Linux Terminal (AVF) | 진짜 VM: systemd·Docker·sandbox 가능, Google 공식 | Pixel·Exynos·MediaTek만(Snapdragon 불가), 아직 실험적, Debian 고정, 포트는 폰 localhost 전용, 백그라운드 종료·데이터 삭제 위험, 한글 IME 불안정 |
| 루팅 + chroot | 성능 최상, Docker 가능(커널 따라) | 루팅 필요(보안·보증·금융앱), 기기별 편차 |
| Termux 네이티브 | 가장 빠름 | Claude Code가 v2.1.113부터 glibc 전용이라 동작 안 함 (anthropics/claude-code#50270) |
| 원격 개발 서버 + 폰은 클라이언트 | 제약 없음 | "동작은 안드로이드" 요구와 다름 |

## 결정

Termux + proot-distro 5.x 위의 Ubuntu LTS를 주 경로로 한다. AVF는 지원 기기에서
Docker가 필요한 작업용 보조 계층으로 문서화하고(docs/avf.md), `andlinux doctor`가
지원 여부를 알린다.

## 결과

- 모든 arm64 폰·태블릿에서 같은 절차로 동작.
- Docker·systemd 부재는 `andlinux svc`, AVF, 원격 `DOCKER_HOST`로 보완.
- proot-distro 5.x가 Docker Hub OCI 이미지를 쓰므로 레지스트리 장애 대비 fallback
  (Canonical ubuntu-base tarball)을 둔다.
