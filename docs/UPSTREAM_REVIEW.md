# 오픈소스 채택 검토

2026-10-23 코드 기준. 전체 SHA는 [upstreams.lock.json](../upstreams.lock.json)에 보관한다. 현재 실행 여부는 [STATUS](STATUS.md)에만 기록한다.

## Oracle — 먼저 재사용

검토한 최신 main은 `998d11bce7e253fbcde319ec5a3c0174f1748469`다. 설치한 npm 배포판은 `@steipete/oracle@0.22.0`이며 registry provenance는 배포 소스를 `bfd25bd1d85c028af60bb708391d49e936c40701`로 연결한다. 최신 소스와 배포 소스는 다르다. provenance JSON을 읽었으며 서명 자체를 암호학적으로 검증하지는 않았다. 배포 tarball integrity와 전이 의존성은 잠금 파일에 기록한다. [배포 메타데이터](https://registry.npmjs.org/@steipete%2Foracle/0.22.0) · [provenance](https://registry.npmjs.org/-/npm/v1/attestations/@steipete%2foracle@0.22.0)

배포 소스에도 기존 Chrome 연결, Windows detached 실행, 파일·이미지 첨부, `--no-wait`, 출력 저장, 세션 회수·followup이 있다. 이 부분을 새로 만들지 않는다. 일반 화면 조작은 기존 브라우저 도구가 맡는다. 모델 UI 선택과 최종 내부 모델 검증은 구분한다. [배포 CLI](https://github.com/steipete/oracle/blob/bfd25bd1d85c028af60bb708391d49e936c40701/bin/oracle-cli.ts) · [Windows worker](https://github.com/steipete/oracle/blob/bfd25bd1d85c028af60bb708391d49e936c40701/src/cli/detachedSession.ts) · [followup](https://github.com/steipete/oracle/blob/bfd25bd1d85c028af60bb708391d49e936c40701/src/cli/followup.ts)

custom slug는 3~5단어이며 충돌하면 접미사를 붙인다. 따라서 자체 작업 ID로 실제 세션 ID를 추정하지 않는다. [세션 이름 코드](https://github.com/steipete/oracle/blob/bfd25bd1d85c028af60bb708391d49e936c40701/src/sessionManager.ts)

MIT 라이선스다. 이번 저장소는 패키지를 의존성으로 사용하고, 해당 프로젝트의 저작권·라이선스는 배포판에 유지한다. [LICENSE](https://github.com/steipete/oracle/blob/bfd25bd1d85c028af60bb708391d49e936c40701/LICENSE)

## codex-switch — 계정 적용 기능 재사용

`2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c`, MIT. README의 자동 회전 없음과 별개로 Windows 코드에 `--switch-account`가 있다. 이메일 또는 Key 하나가 일치하면 추가 확인 대화 없이 전환 요청을 큐에 넣는다. [Program](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/windows/Program.cs) · [MainWindow](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/windows/MainWindow.cs#L746-L751)

CLI exit 0는 전환 완료가 아니다. 기존 `last-switch.json`의 새 plan·대상·Finished·실패/불확실 수와 실제 재개를 확인하는 얇은 wrapper를 붙일 수 있다. 기본 Capture는 모든 active thread이며 재개 문장은 `Continue`다. 우리 환경에 맞게 지정 thread만 계획에 담고, 한도 후 idle인 총괄도 명시 선택할 수 있도록 좁은 패치를 먼저 검토한다. [Capture/재개](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/application/DesktopSwitchBackend.cs) · [완료 상태 저장](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/windows/MainWindow.cs#L686-L698)

Windows 경로는 Codex desktop 재실행을 포함한다. CLI 총괄도 허용되지만 앱을 전혀 사용하지 않는 Windows 전용 전환을 이미 제공한다고 설명하지 않는다. 소스 package 버전 1.41.2와 README의 릴리스 파일 1.41.1도 같은 실행물로 단정하지 않는다.

## chatgpt-browser-channel — 영수증·복구 참고

`df26898e6b80f74a84354b53b711a969ce83b4a8`, MIT. prepared/dispatched/acknowledged/completed와 요청 ID·바인딩으로 전송 불확실 시 무조건 다시 보내지 않는 구조가 유용하다. Linux `flock`, CDP, 내부 웹 인터페이스 의존성이 있어 Windows 조립의 첫 런타임으로 채택하지 않는다. 자체 시간당 6회·120초 간격은 저자가 정한 pacing이며 서비스의 공식 한도가 아니다. [구독/영수증](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-subscription.ts) · [owner lock](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/owner-lock.ts)

## BrowserChatBridge — 확장 연결이 유리할 때의 대안

`ae1b61808124f7f97665807994fa1f31f8c409e4`, MIT. 로그인된 ChatGPT·Gemini 탭의 DOM 입력·Markdown 회수·MCP를 제공한다. Claude 웹·Cloud·Dify adapter는 아니다. request UUID는 메모리 RPC 상관관계이며 영속 중복 방지를 이미 구현한 것으로 보지 않는다. 전송 응답이 사라질 때 내부 `callContent` 재시도로 중복 전송 가능성이 있어, 사용한다면 전송 재시도와 탭별 직렬 처리부터 고쳐야 한다. [background](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/extension/src/background.ts) · [MCP bridge](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/mcp-server/src/bridge.ts)

Oracle의 기능으로 첫 왕복을 만들 수 있으므로 이 확장과 별도 broker를 동시에 도입하지 않는다.

## omp 계정 풀 — 정책 참고

`ff0cc0fae04c91749557592c41138541524549e9`. `omp`용 확장이다. 계정별 사용량·라우팅을 참고하되 현재 Codex Desktop/CLI에 바로 설치하는 자동 전환기로 설명하지 않는다. 사용량 조회 실패 후 남은 오래된 값과 unknown 잔여량을 다루는 방식을 특히 검토했다. package.json에는 MIT 선언이 있고 해당 tree에서 LICENSE 전문은 찾지 못했다. [routing](https://github.com/realestsora/omp-openai-account-pool/blob/ff0cc0fae04c91749557592c41138541524549e9/src/routing.ts) · [package](https://github.com/realestsora/omp-openai-account-pool/blob/ff0cc0fae04c91749557592c41138541524549e9/package.json)

## handova — 이번 환경에서는 보류

`7e74dbff39fab0ca82099feb93c11c383fd65444`, MIT. 계정별 로컬 대화 인계가 중심이며 Windows 미지원이다. 사용자가 확인한 세션 유지 환경에서는 기억 이전 기능이 우선 과제가 아니다. [README](https://github.com/DeveloperAspire/handova/blob/7e74dbff39fab0ca82099feb93c11c383fd65444/README.md) · [인계](https://github.com/DeveloperAspire/handova/blob/7e74dbff39fab0ca82099feb93c11c383fd65444/src/handoff.ts)

## DSH helper — 나중에 작은 워커 하나

`5b6c9392c86bbeeeb6263bc54375abf607c3ef60`. 스크립트·설정 MIT, 설명 문서 CC BY 4.0. `dsh --profile headless --json -`의 이벤트·오류·final 텍스트 회수는 재사용한다. Grok 감독·Bash 전제이며 Codex 연결·워커 풀·계정 회전까지 구현된 것은 아니다. timeout·취소·작업별 잠금·final 검증도 별도다. [run-dsh.sh](https://github.com/diginno-net/grokbot-dsh-orchestrator-vn/blob/5b6c9392c86bbeeeb6263bc54375abf607c3ef60/scripts/run-dsh.sh)

먼저 다른 경로의 실제 왕복을 안정화하고, 반복되는 좁은 자료 처리 하나에 적용한다. 캐시 적중률이나 비용 절감률을 보장하는 근거는 없다.

## 추가 검색 후 우선순위 갱신

최우선 기준을 계정 전환과 기존 작업 유지로 정리한 뒤 추가 검색했다. 아래 판단을 위의 개별 코드 검토보다 우선 적용한다.

### QuotaCrew — 계정 전환의 첫 확인 후보

[erkanpulat/codex-quotacrew](https://github.com/erkanpulat/codex-quotacrew) · MIT · source 9667dd561b6507e4ec0ea09fc9f1055e1f242f84 · [release v0.3.0, 2026-10-19](https://github.com/erkanpulat/codex-quotacrew/releases/tag/v0.3.0).

Windows용 배포판에 Python이 포함된다. 단순 auth 교체를 넘어 quota watcher, 대상 상태 재확인, 실제 계정 적용 후 identity 검증, 한도 중단 대화의 continuation과 결과 관찰을 구현한다. 우리가 같은 기능을 새로 조립할 부담이 가장 적다. [watcher](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/monitoring/watcher.py) · [계정 적용](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/auth/transaction.py) · [중복 claim/자동 재개](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/continuity/automation.py)

Desktop/IDE 자동 재개는 upstream도 experimental이다. 로컬 CLI/App Server에는 같은 thread의 resume/start 경로가 있지만 원래 CLI 프로세스의 제자리 교체는 아니다. 원격·WSL·Cloud·다른 기기의 대화는 로컬 재개 범위 밖이다. 현재 총괄은 앱 목록에서 로컬 Codex 대화로 확인했지만, 이 노트북 버전과의 실제 continuation 지원 확인은 아직 남아 있다. [지원 범위](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/docs/continuity.md)

### 계정 대안 비교

- [JJLiebig/codex-account-switcher](https://github.com/JJLiebig/codex-account-switcher): MIT, Windows 단일 실행 파일, 사용량 JSON·계정 적용 CLI. release v0.1.10(2026-07-13), source 045cb4f6ce2136ef3ecb2386d6f8aa841367c3ca. 자동 중단 감지와 같은 대화 재개가 함께 있는 것으로 확인하지 못했다.
- [farion1231/cc-switch](https://github.com/farion1231/cc-switch): MIT, release v4.0.18(2026-10-21), source 79ba7982aa3980b001c0b68efde05505884c1f8b. 최신 Accounts beta와 Codex Official direct 경로가 실제 auth를 적용한다. proxy-only로 분류하면 틀린다. 다만 이번 목적보다 범용 provider/config 관리가 넓고 QuotaCrew 같은 한도 중단 thread의 자동 재개까지 확인하지 못했다.
- [router-for-me/CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI): MIT, release v8.0.40(2026-10-23), source d946c4fba6fc9a5cfbca1f3d85184d62ad2fb683. 요청 경로에 별도 프록시를 추가하므로 현재 최소 조합에서 제외한다.

### mcporter — Oracle를 CLI에서 호출

현재 canonical 저장소는 [openclaw/mcporter](https://github.com/openclaw/mcporter)다. 옛 steipete URL은 이동한다. MIT, npm/release 0.16.0(2026-10-20), 게시 provenance source 9a8ed529e313f452a0ce977894cb63c4620ddd7c, 검토 main 5f9eee19b4216359e5937032705f7ce274b2ef4d. 자체 MCP client를 만들지 않고 기존 call/list를 사용한다. Codex·Claude가 native MCP를 쓰면 필수는 아니다.

실제 설치판에서 config 파일 기준 cwd 상대 경로, Oracle schema 조회, consult JSON stdin·dryRun을 확인했다. 다만 이 버전은 기존 Chrome 연결에 정규 global 구성/소유권 정책이 있고, 이번 project-local Chrome 정의는 거절됐다. 그래서 기본 mcporter 구성에는 Oracle만 남긴다. 이 문제를 위해 새로운 OpenClaw 환경이나 자체 browser broker를 도입하지 않는다.

### 화면 도구 후보

[ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) 1.12.0(2026-10-22), release/gitHead af2834411a564d366f9cab63efb046d9084f4dba, 검토 main 0ca821f3ac7d8e4d843efc3d7399d6b8d3f4d77d. Apache-2.0. 같은 패키지에 MCP와 CLI가 있다. 기존 Chrome autoConnect/CDP, snapshot, screenshot, 입력·클릭·드래그를 지원한다. 좌표 조작은 experimentalVision 설정이 필요하다. 일반 화면 조작에 필요한 도구가 빠지는 slim 설정은 이번 용도에 맞지 않는다. [원본 연결 안내](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/af2834411a564d366f9cab63efb046d9084f4dba/docs/advanced-usage.md) · [도구 목록](https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/af2834411a564d366f9cab63efb046d9084f4dba/docs/tool-reference.md)

대안으로 [agent-browser 0.39.2](https://github.com/vercel-labs/agent-browser/tree/50c34e78c98dbe8add0b3ff36b4bcd7a47f1022b)와 [Playwright MCP 0.0.83](https://github.com/microsoft/playwright-mcp/tree/f183dad4a52965583e3cc1d59b88cdc279e2e57d)도 확인했다. 둘 다 Apache-2.0이며 기존 Chrome CDP 경로가 있다. 여러 도구를 동시에 추가할 근거는 부족하므로 현재 화면 도구를 유지하고 필요한 경우 한 후보만 도입한다.


계정 후보의 현재 우선 비교 순서와 종료·설정 변경 차이는 [ACCOUNT_DECISION_KO](ACCOUNT_DECISION_KO.md)를 따른다. CLI 허용 조건에서 Switchy의 열린 세션 routing을 먼저 비교하되 실제 전환 합격 전에는 자동 활성화하지 않는다.


### 추가 CLI wrapper 제외

[yunkai93/codex-switch-account](https://github.com/yunkai93/codex-switch-account/tree/218dde4287194d798f88a23c1a1f78411f1a3d17)도 한도 후 자동 resume 후보로 확인했다. MIT, 마지막 커밋 2026-06-04, GitHub release 없음. native PowerShell/CMD 미지원이고 별도 shared home의 초기 복사 범위가 config·installation_id·version뿐이어서, 현재 Windows 작업과 기존 skills/plugins를 그대로 쓰기 위한 첫 선택에서는 제외한다. 일반 실행의 대화 ID 추정도 최신 history/rollout fallback이므로 동시 세션에서 확실한 현재 대화 식별로 확대하지 않는다.

