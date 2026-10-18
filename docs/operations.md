# 운영 가이드

설치가 끝난 뒤 매일 쓰는 방법입니다. 명령은 모두 **Termux**에서 실행합니다
(게스트 안에서 쓰는 도구는 따로 표시).

## 명령 요약

| 명령 | 하는 일 |
|---|---|
| `andlinux` / `andlinux shell` | Ubuntu 로그인 셸 (사용자 `dev`) |
| `andlinux claude [인자]` | Claude Code 실행 |
| `andlinux run 명령…` | Ubuntu에서 명령 한 번 실행 |
| `andlinux root` | Ubuntu root 셸 |
| `andlinux desktop [--detach]` | XFCE 데스크톱 시작 (`--stop`, `andlinux stop`) |
| `andlinux svc start\|stop\|status [ssh\|code-server\|all]` | 상주 서비스 (systemd 대체) |
| `andlinux ssh-key add <공개키\|파일>` | SSH 접속 키 등록 |
| `andlinux ip` | 다른 기기에서 접속할 주소 |
| `andlinux tunnel PORT` | 임시 공개 HTTPS 주소 (Cloudflare) |
| `andlinux update` | 툴킷·Termux·Ubuntu·Claude Code·mise 모두 갱신 |
| `andlinux backup` / `restore FILE` | 컨테이너 백업·복원 |
| `andlinux doctor` | 상태 점검 |
| `andlinux config show\|edit\|set K V` | 설정 확인·변경 (적용: `andlinux setup`) |

홈 화면 바로가기(Termux:Widget): AndLinux Shell, AndLinux Desktop, Claude Code.

## 업데이트

`andlinux update` 한 번이 모든 계층을 각자의 공식 채널로 갱신합니다.

1. 툴킷: `git pull --ff-only` (바뀌면 새 버전으로 이어서 실행)
2. Termux: `pkg update` + `full-upgrade` (Termux는 부분 업그레이드를 지원하지 않음)
3. 게스트 재수렴: 새 툴킷의 모듈·기본값 반영 (변경 없으면 빠르게 통과)
4. Ubuntu: `apt full-upgrade` — Ubuntu, Mozilla, Microsoft, GitHub, mise 등 등록된 공식 저장소 전부
5. Claude Code: 네이티브 설치는 스스로도 백그라운드 업데이트하지만 여기서 즉시 `claude update`
6. mise 도구: `mise upgrade` (예: Node LTS의 새 패치)

**proot-distro 메이저 업그레이드는 보류됩니다.** 메이저 버전은 컨테이너 형식을
되돌릴 수 없게 바꿀 수 있어서(v4→v5 사례), 먼저 `andlinux backup` 후
`andlinux update --allow-major`로 진행합니다.

Claude Code 채널: `AL_CLAUDE_CHANNEL=latest`(기본) 또는 `stable`(약 1주 지연, 큰 회귀
제외). 패키지 관리자로 통일하고 싶다면 `AL_CLAUDE_METHOD=apt`(Anthropic 공식 서명
apt 저장소, `andlinux update`로 갱신).

**Ubuntu LTS 간 업그레이드**(24.04 → 26.04)는 `do-release-upgrade`가 아니라 새 컨테이너로
합니다: 백업 → `AL_CONTAINER=andlinux26`, `AL_UBUNTU_RELEASE=26.04`로 설정 → `andlinux setup`
→ 홈 디렉터리 이전(`rsync`) → 확인 후 이전 컨테이너 삭제. (자동화 예정:
[decisions/0002](decisions/0002-ubuntu-release.md))

## 파일 주고받기

| 방법 | 언제 | 어떻게 |
|---|---|---|
| 공유 저장소 | 폰의 다른 앱과 | 게스트 `~/Android` = `/sdcard`. 브라우저 다운로드는 `/sdcard/Download`로 저장 |
| 안드로이드로 열기·공유 | 결과물 확인, 메신저 전송 | 게스트에서 `android-open 파일\|URL`, `android-share 파일` |
| 클립보드 | 텍스트 | `명령 \| android-clip copy`, `android-clip paste` (Termux:API 필요) |
| SSH (scp/rsync/sftp) | PC ↔ 폰 | 아래 [PC에서 접속](#pc에서-접속) 후 `rsync -av -e "ssh -p 2222" ./ dev@폰:~/projects/x/` |
| Termux ↔ 게스트 | 스크립트 | `proot-distro copy` / `sync` (Termux에서), 게스트 `~/Termux` 링크 |
| Syncthing / LocalSend / KDE Connect | 폴더 동기화·무선 전송 | 안드로이드 앱이 `/sdcard`의 폴더를 쓰게 하고 게스트에서 `~/Android/...`로 접근 |
| Google Drive | 클라우드 | Termux의 `rclone`(`pkg install rclone`, 최신 버전) 설정 후 `rclone sync`/`bisync` (FUSE가 없어 `mount`는 불가) |
| git | 코드 | `gh auth login` 후 평소처럼 |

**코드는 `/sdcard`에 두지 마세요.** 공유 저장소는 FUSE 기반이라 느리고, 권한·심볼릭
링크·실행 비트가 없어 git과 `node_modules`가 깨집니다. 작업은 `~/projects`에서 하고
`~/Android`는 주고받는 용도로만 씁니다.

## 개발 서버와 호스팅

| 범위 | 방법 |
|---|---|
| 폰 자신 | proot는 안드로이드와 네트워크를 공유: 폰 브라우저에서 `http://localhost:PORT` |
| 같은 Wi-Fi | 서버를 `0.0.0.0`에 바인딩 (예: `vite --host`, `next dev -H 0.0.0.0`) → `andlinux ip`의 주소로 접속 |
| 어디서나, 나만 | Tailscale 앱(안드로이드)을 켜면 폰의 `100.x` 주소로 SSH·개발 서버에 접속 |
| 어디서나, 공개 | `andlinux tunnel 3000` → `https://….trycloudflare.com` (임시, 계정 불필요) |
| 고정 공개 주소 | Cloudflare 계정의 named tunnel (`cloudflared tunnel login` 후 게스트에서 구성) |

- 1024 미만 포트는 바인딩할 수 없습니다. 3000~9999를 쓰세요. 꼭 필요하면
  `andlinux shell -P`(proot-distro `--redirect-ports`: 80→2080, 443→2443)로 이동시킵니다.
- Quick tunnel은 가용성 보장이 없고 동시 요청 200개 제한, SSE 미지원입니다. 데모용입니다.
- Tailscale Serve/Funnel은 안드로이드 앱에서 지원되지 않습니다(다른 노드에서 프록시).
- 일부 공유기·회사 Wi-Fi는 단말 간 통신(AP isolation)을 막습니다. 그때는 Tailscale을 씁니다.

## PC에서 접속

게스트 안의 Dropbear SSH(포트 2222, 키 인증만)로 접속합니다.

```bash
# 폰(Termux): PC의 공개키 등록 후 서버 시작
andlinux ssh-key add "ssh-ed25519 AAAA... me@pc"
andlinux svc start ssh
andlinux ip                     # 접속할 주소 확인
```

PC의 `~/.ssh/config`:

```
Host phone
  HostName 192.168.0.23        # 또는 Tailscale 100.x 주소
  Port 2222
  User dev
```

- 터미널: `ssh phone` → 바로 Ubuntu(Claude Code 포함)
- VS Code: Remote-SSH 확장 → `phone`. 게스트는 glibc Ubuntu라 VS Code 서버가 동작합니다
  (Termux 자체는 bionic libc라 불가).
- 브라우저 IDE: `full` 프로필의 code-server → `andlinux svc start code-server`, PC에서
  `ssh -L 8080:127.0.0.1:8080 phone` 후 `http://localhost:8080` (비밀번호는 게스트
  `~/.config/code-server/config.yaml`).
- Termux 자체 셸이 필요하면 Termux의 `sshd`(포트 8022)를 별도로 씁니다.

부팅 시 SSH 자동 시작: Termux:Boot 설치 후 `andlinux config set AL_BOOT_SERVICES ssh`
→ `andlinux setup`.

## Claude Code 활용

- 시작: `andlinux claude` (또는 데스크톱 터미널·SSH에서 `claude`)
- 환경 인식: 설치 시 `~/.claude/CLAUDE.md`에 이 환경의 제약(systemd·Docker 없음, 포트,
  파일 위치, 안드로이드 도우미)을 관리 블록으로 넣어 Claude가 처음부터 알고 시작합니다.
- 권한: 기본은 Claude Code 자체 기본값. `AL_CLAUDE_DEFAULT_MODE`(예: `acceptEdits`, `auto`,
  `bypassPermissions`)로 기본 모드를 정할 수 있습니다. `--dangerously-skip-permissions`는 비루트
  사용자라 동작하지만, 접근 범위가 Termux 데이터와 공유 저장소 전체라는 점을 감안하세요
  ([architecture.md#보안-모델](architecture.md#보안-모델)). `/sandbox`는 proot에서 불가합니다.
- 다른 기기에서 조종: 게스트에서 `claude remote-control`(또는 세션 안 `/remote-control`)을
  켜면 PC 브라우저(claude.ai/code)나 Claude 앱에서 폰의 세션을 이어서 조작할 수 있습니다
  (claude.ai 구독 로그인 필요, 폰과 프로세스가 깨어 있어야 함).
- VS Code 확장: 데스크톱의 VS Code에서 Marketplace의 Claude Code 확장을 설치합니다.

## 서비스

systemd가 없으므로 상주 프로세스는 `andlinux svc`가 proot-distro의 분리 세션으로
관리합니다. 로그: ssh는 게스트 `/var/log/andlinux/ssh.log`, code-server는
`~/.local/state/code-server.log`. 그 밖의 장기 실행 작업은 게스트에서 `tmux`를 쓰세요
(세션을 닫아도 유지하려면 `andlinux desktop --detach`처럼 분리 세션 안에서 실행).

## 한국어

- 폰트: Noto CJK, 나눔, 컬러 이모지. 입력기: fcitx5-hangul.
- 전환: **한/영(Hangul) 키, Shift+Space, Ctrl+Space**. 설정 도구: 메뉴 › fcitx5 설정.
- UI 언어를 한국어로: `andlinux config set AL_LANG ko_KR.UTF-8` → `andlinux setup`
  (한국어 언어팩·Firefox 한국어팩 설치).

## GPU 가속 (선택, 실험적)

기본은 소프트웨어 렌더링(llvmpipe)으로 모든 기기에서 동작합니다. 브라우저·VS Code가
무겁다면 `andlinux config set AL_GPU virgl` → `andlinux setup` → `andlinux desktop`
(Termux의 virglrenderer-android, ANGLE 기반). 문제가 있으면 `none`으로 되돌립니다.

## 백업과 복원

```bash
andlinux stop                    # 일관된 백업을 위해 세션 정지
andlinux backup                  # /sdcard/AndLinux/backups/andlinux-날짜.tar.zst (최근 3개 유지)
andlinux restore /sdcard/AndLinux/backups/andlinux-20261018-120000.tar.zst
```

- 공유 저장소에 저장하므로 Termux를 지워도 남습니다.
- Google Drive에도 올리기: Termux에서 `pkg install rclone && rclone config`(원격 이름 예:
  `gdrive`) → `andlinux config set AL_BACKUP_RCLONE_REMOTE gdrive:claude5/AndLinux/backups`.
- 코드는 백업보다 git 원격 저장소가 우선입니다.

## 설정 바꾸기

```bash
andlinux config show                         # 현재 값
andlinux config set AL_PROFILE full          # 또는: andlinux setup --profile full
andlinux config set AL_MODULES_EXTRA "code-server hosting"
andlinux setup                               # 적용 (멱등)
```

설정 항목과 설명: [config/defaults.env](../config/defaults.env).
