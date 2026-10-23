# 브라우저 위임·응답 회수 하네스 소스 조사

조사 기준: 2026-10-23. 공개 GitHub의 현재 소스와 LICENSE, npm 메타데이터·provenance를 읽었다. 설치, 브라우저 연결, 실제 모델 질문, 계정 조작은 하지 않았다. 이 문서는 다른 실행기·AGENTS.md 조사의 브라우저 채널 부분이다.

총괄 추가 확인: 설치된 Oracle 0.22.0의 `dist/src/mcp/tools/wait.js` 6행에서도 terminal 상태는 completed/partial/error/cancelled이며, 158행은 `readSessionLogTail(metadata.id, 4_000)`, 168행 output은 그 logTail이다. 이 두 회수 주의사항은 최신 main만의 추론이 아니라 설치 파일에서도 확인했다. 실제 웹 질의·답변 회수는 실행하지 않았다.

## 판단

현재 목적에는 **Oracle의 기존 비동기 세션 기능을 우선 사용하고, mcporter는 필요할 때만 도구를 발견·호출하는 얇은 입구로 사용**하는 조합이 가장 작다. Oracle이 이미 맡는 세션 저장, detached worker, 기다림, 결과·이미지 회수를 새 플랫폼으로 다시 만들 이유가 없다. BrowserChatBridge는 기존 Windows Chromium 탭을 읽고 조작하는 보조 도구로 검토할 수 있다. chatgpt-browser-channel은 전송 영수증과 불확실성 처리의 좋은 설계 참고지만 Linux 호스트와 비공개 ChatGPT 응답 형식에 의존하므로 현재 Windows 조합의 첫 선택은 아니다. [Oracle MCP](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/mcp.md), [channel README](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/README.md), [BCB bridge](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/mcp-server/src/bridge.ts).

**이 네 저장소 어느 것도 웹 ChatGPT Pro·Cloud Codex·Claude 웹/Code·DeepSeek 웹을 모두 지원하는 하네스가 아니다.** 아래의 `Claude 지원`을 Claude 웹 구독 또는 Claude Code 작업 위임으로 읽으면 안 된다. Oracle의 Claude 경로는 API 모델 상담이며, Claude Code는 Oracle을 호출하는 호스트로 연결할 수 있다는 뜻이다. Cloud Codex 작업 생성·완료·결과 가져오기 및 DeepSeek 웹 어댑터는 조사한 코드에 없다. 기존 화면 관찰·조작 도구는 별도로 유지해야 한다. [Oracle 엔진·모델 설명](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/skills/oracle/SKILL.md), [Oracle 에이전트 연결](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/agents.md), [BCB provider 프로토콜](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/shared/protocol.ts).

## 조사한 버전과 라이선스

`현재 main 소스`와 `설치 가능한 npm 배포물`을 분리했다. package.json 버전이 같아도 소스 내용이 같다는 의미는 아니다.

| 후보 | 확인한 현재 main SHA | package 버전 / Node | LICENSE 원문 | 위치 |
| --- | --- | --- | --- | --- |
| Oracle | `998d11bce7e253fbcde319ec5a3c0174f1748469` | `0.22.0` / `>=24` | MIT, Peter Steinberger, 2026 | 우선 실행·회수 도구 |
| chatgpt-browser-channel | `df26898e6b80f74a84354b53b711a969ce83b4a8` | `0.1.0` / `>=22` | MIT, Contributors, 2026 | 영수증 설계 참고 |
| BrowserChatBridge-Plugin | `ae1b61808124f7f97665807994fa1f31f8c409e4` | `0.2.1` / `>=20` | MIT, BrowserChatBridge contributors, 2026 | Chromium 탭 보조 채널 |
| mcporter | `5f9eee19b4216359e5937032705f7ce274b2ef4d` | `0.16.0` / `>=24` | MIT, Peter Steinberger, 2026 | MCP 호출·문맥 절약 보조 |

각 package와 LICENSE: [Oracle package](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/package.json) / [LICENSE](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/LICENSE), [channel package](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/package.json) / [LICENSE](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/LICENSE), [BCB package](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/package.json) / [LICENSE](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/LICENSE), [mcporter package](https://github.com/openclaw/mcporter/blob/5f9eee19b4216359e5937032705f7ce274b2ef4d/package.json) / [LICENSE](https://github.com/openclaw/mcporter/blob/5f9eee19b4216359e5937032705f7ce274b2ef4d/LICENSE). MIT 허용 조건과 저작권 고지 유지 의무가 실제 파일에 있다. 서비스 접근 권한이나 웹 서비스의 운영 안정성을 MIT가 보장하지는 않는다.

배포물 pin은 다음과 같다. registry JSON을 읽었고 tarball 설치·서명 검증은 하지 않았다. `gitHead`는 두 package 모두 없었으며 아래 source SHA는 registry의 SLSA provenance `resolvedDependencies.gitCommit` 값이다.

| npm pin | npm 게시 시각 (UTC) | 배포 provenance source SHA | 현재 main과 관계 |
| --- | --- | --- | --- |
| `@steipete/oracle@0.22.0` | `2026-10-20T20:36:23.156Z` | `bfd25bd1d85c028af60bb708391d49e936c40701` | 현재 main `998d…`와 다름 |
| `mcporter@0.16.0` | `2026-10-20T21:16:40.651Z` | `9a8ed529e313f452a0ce977894cb63c4620ddd7c` | 현재 main `5f9e…`와 다름 |

근거: [Oracle registry](https://registry.npmjs.org/@steipete%2foracle/0.22.0), [Oracle provenance](https://registry.npmjs.org/-/npm/v1/attestations/@steipete%2foracle@0.22.0), [mcporter registry](https://registry.npmjs.org/mcporter/0.16.0), [mcporter provenance](https://registry.npmjs.org/-/npm/v1/attestations/mcporter@0.16.0). 최신 main의 추가 skill·수정사항을 설치된 배포물의 기능으로 단정하지 않는다. 재현 가능한 운영은 npm exact pin과 lockfile을 사용하고, main에서만 확인한 기능은 별도 검토 대상으로 남긴다.

## 실제 기능 비교

| 항목 | Oracle | chatgpt-browser-channel | BrowserChatBridge | mcporter |
| --- | --- | --- | --- | --- |
| 실제 위임 경로 | ChatGPT/Gemini 브라우저 상담, 여러 provider API | ChatGPT 전용 | ChatGPT/Gemini 탭 | 연결한 MCP 도구를 호출; 자체 모델 위임 없음 |
| 질문 후 다른 일 | native detached worker + session ID | durable request receipt + 관찰 | `ask`를 기다리는 MCP 요청; pending 메모리 | Oracle async 호출을 CLI로 전달 가능 |
| 호출자 종료 후 회수 | 저장 세션·CLI session/harvest·MCP wait | acknowledged 관찰 재개; ambiguous dispatch는 uncertain | 연결 재수립은 가능하나 in-flight 회수 영수증 없음 | 하위 서버가 제공하는 지속성에 의존 |
| 모델·Pro 확인 | UI 모델/effort 선택 증거, 미확인 표시 | 최종 답변 metadata의 model slug 확인 | 모델 파라미터·선택/최종 검증 없음 | 하위 도구 출력 전달 |
| 문맥 선택 | 파일/glob/exclude, 크기 제한, dry-run 토큰 보고 | prompt·첨부, 이력 projection | prompt·현재 DOM 이력 scrape | 도구 schema를 필요할 때 조회 |
| 의미 기반 압축·검색 | 이 조사 범위에서 자동 RAG/요약 압축 없음 | history export/index hook; 검색·압축 엔진은 호스트 담당 | 없음 | 없음; 연결한 검색 MCP는 별개 |
| 영수증 강도 | durable session/lineage/artifacts; exactly-once 전송 보장은 아님 | UUID + prompt/model/binding + 전송 단계 ledger | random RPC ID와 일시적 pending | JSON-RPC 기록·재생, 작업 완료 영수증은 아님 |
| Windows 적합성 | 지원하나 upstream도 브라우저 경로의 변동성 명시 | 호스트 Linux + `flock` 필수 | Chromium extension + Node, 기존 로그인 탭 사용 | Node 기반 CLI/MCP 호출 |

표의 세부 근거와 경계는 아래에 적었다. 도구 수·파일 묶음·모델 이름을 실제 토큰 절감률이나 최종 backend 모델 보장으로 바꾸어 해석하지 않는다.

## Oracle: 바로 재사용할 핵심

### 비동기 왕복과 결과 회수

MCP `consult`의 `waitForCompletion:false`는 로컬 detached worker를 시작하고 durable `sessionId`를 돌려준다. 이후 `wait`는 저장된 세션 상태를 읽으며 파일 변경 알림과 1초 fallback을 사용한다. wait의 timeout·취소는 대기자만 끝내고 worker는 끝내지 않는다. 같은 ID로 다시 wait할 수 있다. 원래 MCP 프로세스 수명과 모델 작업 수명이 분리되어 있다. remote browser **service**를 통한 detached consult는 현재 거절하며, 로컬 attach/CDP 경로와 remote service를 혼동하면 안 된다. [consult 구현](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/mcp/tools/consult.ts#L645-L741), [detached worker](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/cli/detachedSession.ts), [wait 구현](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/mcp/tools/wait.ts).

`wait`의 terminal 집합은 `completed/partial/error/cancelled`이다. 따라서 terminal을 곧 성공으로 처리하면 안 된다. 반환 `output`도 전체 답변을 보장하지 않고 log tail 4,000자다. 완성 답변은 저장된 `response.md`, transcript와 artifacts, `oracle session <실제 ID>`에서 회수한다. MCP `sessions detail:true`는 metadata뿐 아니라 **전체 log와 request**도 가져오므로 가벼운 상태 확인 때 상시 사용하면 문맥과 개인정보 노출량이 커진다. [wait 결과 생성](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/mcp/tools/wait.ts#L201-L254), [sessions 구현](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/mcp/tools/sessions.ts), [세션 파일 구조·회수](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/sessions.md).

반복 요청 방지는 존재하지만 완전한 사용자 request-ID dedupe는 아니다. `shouldBlockDuplicatePrompt`는 현재 running 세션의 정규화된 prompt와 follow-up 문자열을 비교한다. 모든 상태·파일·계정까지 동일하게 묶는 exactly-once ledger로 볼 수 없다. 세션 ID를 분실했거나 timeout이 났다고 새 consult를 보내지 말고 status/session을 먼저 확인해야 한다. [중복 prompt guard](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/cli/duplicatePromptGuard.ts).

주제별 continuation은 `--followup <실제 session ID>`로 저장된 대화와 browser/model 설정을 상속한다. 사용자가 지정한 slug와 실제 ID는 충돌 시 달라질 수 있으므로 반환 ID를 기록한다. 새 질문 제출, 기존 세션 harvest, 명시적 follow-up을 구분한다. `session --restart`는 다시 보내는 동작이므로 결과 조회 대체 명령으로 쓰지 않는다. 대화 유지가 필요하면 archive 설정도 명시한다. Work 대화 follow-up 제약을 Cloud Codex 작업 지원으로 오해하지 않는다. [세션·follow-up 문서](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/sessions.md), [브라우저 follow-up](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/followup.md).

### Pro·이미지·기존 브라우저

브라우저 모델 전략은 `select/current/ignore`를 구분하며 모델 picker·effort 증거를 남긴다. **선택된 UI와 실제 서버의 최종 생성 모델은 다른 주장**이다. 최신 `oracle-advisor` skill도 이를 명시하고 native desktop 위임은 미구현이라고 적는다. 필요한 Pro 선택이 미확인인 상담을 성공한 Pro 결과로 보고하면 안 된다. 모델 alias와 UI는 변하므로 설치된 버전의 실제 mapping과 dry-run을 기준으로 선택한다. [model selection](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/browser/actions/modelSelection.ts), [advisor 결과 계약](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/skills/oracle-advisor/SKILL.md), [native 미구현 범위](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/advisor.md).

이미지·문서를 브라우저 첨부로 보내고 생성 이미지·파일을 로컬 artifacts로 회수하는 경로가 있다. `chatgpt_image`는 기존 image-aware wait/download 경로의 wrapper이며 이미지 입력·출력이 모두 text-only 상담과 구분된다. 다운로드에는 ChatGPT의 provider 내부 경로도 쓰므로 DOM만 읽는 만능 안정 계층은 아니다. [MCP image 기능](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/mcp.md), [브라우저 모드](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/browser-mode.md), [선택적 conversation 증거](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/browser/chatgptConversation.ts).

Windows에서 기존 Chrome attach와 별도 manual-login profile을 지원한다. attach-running은 이미 로그인한 브라우저에 별도 탭을 만들고 cookie 복사를 생략하지만, Chrome 디버깅·연결 승인 등 브라우저의 조건을 충족해야 한다. 지원된 profile lock/tab slot 조정은 별도 대화 탭 동시성을 위한 것으로, 동일 대화 탭에 여러 작업이 안전하게 동시에 쓰는 보장이 아니다. [브라우저 모드](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/browser-mode.md), [공유 profile 조정](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/docs/agents.md#multi-agent-shared-profile-browser-mode).

### 토큰 비용에 실제 도움 되는 부분

Oracle의 직접적인 장점은 필요한 파일만 glob/exclude로 선택하고, 1MB 기본 파일 한도·dry-run·files report로 입력 크기를 **보이게 하는 것**이다. prompt assembly는 파일 내용을 구성하고 연속 빈 줄을 줄인다. 토큰 추정은 tokenizer와 고정 buffer를 사용한다. 이것은 의미를 보존하는 자동 요약, 코드 검색, 지속적 RAG가 아니다. 여러 파일을 한 text/ZIP attachment로 묶어도 내용을 읽는 모델의 문맥이 공짜가 되지는 않는다. [파일 선택·토큰 workflow](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/skills/oracle/SKILL.md), [prompt assembly](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/oracle/promptAssembly.ts), [token estimate](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/src/oracle/tokenEstimate.ts).

## chatgpt-browser-channel: 영수증 설계는 강하고 배포 전제는 다름

UUID를 prompt/model/binding과 묶고, `prepared → dispatched → acknowledged → completed`를 디스크에 저장한다. click 전에 dispatched를 남기고, 실제 대화의 새 user message를 찾아 accepted를 기록한다. acknowledged 이후 관찰은 재시작 후 이어가지만, 전송했는지 모르는 dispatched 상태는 `uncertain`으로 남긴다. 파일 write도 임시 파일·fsync·rename을 사용한다. 이 부분은 단순히 ask를 재시도하는 wrapper보다 명확하다. [receipt·재개](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-subscription.ts#L15-L140), [전송 전후 기록](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-subscription.ts#L210-L255), [click와 user-message 대조](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-browser.ts#L174-L263).

완료는 단순 DOM 안정화가 아니라 bound user 이후 final answer의 `end_turn/status`와 active branch를 확인한다. Pro는 최종 answer metadata의 `resolved_model_slug/model_slug`를 검사한다. 다만 불일치 때 **원본 코드가 같은 대화에서 한 번 자동 재질문**한다. 재질문도 ledger를 남기며 불명확하면 재전송하지 않지만, 자동으로 두 번째 질문을 보낸다는 정책 자체를 알고 채택해야 한다. [완료·모델 검사](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-subscription.ts#L261-L348).

실제 운영의 제약은 Linux + util-linux `flock`, 단일 state/browser owner, 비공개 `/api/auth/session`·`/backend-api` 대화/검색 응답 의존성이다. README는 reference 추출물이며 원래 host도 아직 이 package로 전환하지 않았다고 명시한다. CLI/HTTP ask는 새 대화 경로이고 기존 native binding 활용은 library embedding 영역이다. HTTP 202는 로컬 수락이며 ChatGPT의 accepted가 아니다. hardcoded **6회/시간, 최소 120초**는 자체 burst 방지 정책이며 서비스 공식 한도가 아니다. [README](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/README.md), [CLI](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/cli.ts), [pacing 상수](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-subscription.ts#L22-L24).

이력 raw snapshot·projection·index 연결점은 있으나 retrieval backend와 장기 문맥 관리는 host 책임이다. 이 코드를 가져오면 자동으로 검색 기반 AGENTS 하네스가 생기는 것은 아니다. [refresh 구현](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/src/chatgpt-refresh.ts), [library 통합 범위](https://github.com/tejasdc/chatgpt-browser-channel/blob/df26898e6b80f74a84354b53b711a969ce83b4a8/README.md#library-integration).

## BrowserChatBridge: Windows 탭 도구, durable 작업 실행기는 아님

MCP stdio → localhost bridge → Chromium extension → ChatGPT/Gemini DOM adapter 구조다. `ask/list_tabs/get_last_response/scrape_conversation/health_check`를 제공한다. `get_last_response`는 새 질문 없이 현재 답변을 읽으므로 단순 자동 회수에 유용하다. 그러나 scrape는 렌더링된 DOM만 읽으므로 긴 대화의 가상화로 전체 이력이 보이지 않을 수 있다. provider는 ChatGPT와 Gemini뿐이다. [MCP tools](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/mcp-server/src/index.ts), [provider 타입](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/shared/protocol.ts), [ChatGPT adapter](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/extension/src/content/adapters/chatgpt.ts).

request ID는 매 RPC의 random UUID이고 pending map은 메모리다. timeout은 pending을 지우며 extension에서 진행 중인 send를 취소하지 않는다. disconnect는 in-flight를 실패시키고, leader/follower 재연결은 미래 호출을 복구하는 것이지 과거 작업을 durable하게 resume하는 기능은 아니다. tab ID와 last-used tab도 장기 주제 세션 영수증이 아니다. [bridge pending·timeout·disconnect](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/mcp-server/src/bridge.ts#L187-L250), [메모리 탭 선택](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/mcp-server/src/index.ts#L132-L173).

특히 extension `runAsk`는 `callContent(action:send)`를 호출하고, 그 helper는 `internal_error/no response` 등에 최대 3회 재시도한다. click은 성공하고 reply만 잃어버리면 중복 전송 여지가 있다. 탭별 직렬 queue·durable 수신 dedupe도 보이지 않는다. **상위 wrapper에 receipt만 붙이고 내부 send 재시도를 남기는 방식으로 해결했다고 하면 안 된다.** 채택한다면 우선 수정은 (1) send의 모호한 실패 재시도 중단, (2) durable request ID와 수신 dedupe, (3) 탭별 queue, (4) 선택 모델·최종 모델 불확실성 표시다. 현재 사용자 목표에서 이 fork 비용을 먼저 부담할 이유는 약하다. [send 호출](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/extension/src/background.ts#L174-L248), [내부 재시도](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/extension/src/background.ts#L337-L361).

완료도 DOM의 새 turn·generating 여부·안정 시간으로 판단한다. 이것은 provider의 terminal 메시지나 최종 model ID 검증과 다르다. 모델을 선택하는 tool input도 없다. 로그인된 Pro 계정 탭을 사용한다는 사실만으로 Pro 답변 증거가 생기지 않는다. [완료 관찰](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/extension/src/background.ts#L180-L248), [입력 schema](https://github.com/satabd/BrowserChatBridge-Plugin/blob/ae1b61808124f7f97665807994fa1f31f8c409e4/mcp-server/src/index.ts#L34-L43).

## mcporter: 도구 문맥을 줄이는 입구

mcporter는 새 총괄 에이전트나 queue가 아니다. MCP를 CLI·TypeScript에서 호출하고 schema를 필요할 때 읽게 한다. upstream의 권장 방식도 generic 대형 skill 하나보다 **서버/작업별 작은 skill**이다. `list <server> --brief`, 필요한 경우 `--schema/--all-parameters`, 이어서 필요한 도구만 `call`하는 방식은 모든 도구 schema를 항상 모델 문맥에 넣는 부담을 줄일 수 있다. 다만 실제 Astra 토큰 절감률을 측정한 결과는 이 조사에 없다. 호출 shell output과 큰 도구 응답을 전부 다시 읽으면 절감 효과가 사라질 수 있다. [작은 skill 패턴](https://github.com/openclaw/mcporter/blob/5f9eee19b4216359e5937032705f7ce274b2ef4d/docs/agent-skills.md), [도구 호출 문법](https://github.com/openclaw/mcporter/blob/5f9eee19b4216359e5937032705f7ce274b2ef4d/docs/tool-calling.md).

`record/replay`는 JSON-RPC params/result 전체를 NDJSON으로 기록하고 **같은 순서·같은 params** 요청에 응답을 재생하는 디버깅 기능이다. 실제 브라우저에서 작업이 수락되었는지 확인하거나 중복 제출을 막는 ledger는 아니다. 기록에는 원문 prompt·파일·비밀이 포함될 수 있어 raw capture를 GitHub 작업 영수증으로 바로 공유하면 안 된다. [record/replay 실제 범위](https://github.com/openclaw/mcporter/blob/5f9eee19b4216359e5937032705f7ce274b2ef4d/docs/record-replay.md).

## 작은 AGENTS/skill에 남길 계약

새 실행 코드를 만드는 대신 아래 정도를 기존 도구를 호출하는 지침으로 남기는 것이 적절하다. 이는 조사 권고이며 이 문서 작성으로 설치·실행 지침을 적용하지 않았다.

1. 로컬 총괄이 질문의 목적·현재 Git SHA·필요한 파일 목록·출력 계약을 정한다. 검색/파일 선택은 먼저 로컬에서 하고 repo 전체를 매번 보내지 않는다.
2. 위임 작업은 실제로 지원하는 transport·model·effort를 명시한다. Cloud Codex·Claude 웹·DeepSeek 웹은 지원 어댑터가 확인되기 전까지 사용 가능 목록에 넣지 않는다. 화면 관찰·조작 도구도 계속 사용하되 현재 도구 권한을 따른다.
3. Oracle native async consult에서 받은 **실제 ID**를 보관한다. 로컬 총괄은 다른 일을 진행하고, 필요할 때 같은 ID로 wait/기존 결과 조회를 한다. timeout을 새 제출 신호로 해석하지 않는다.
4. 결과를 `completed/partial/error/uncertain`으로 구분하고 요청 model/effort와 관찰 증거를 함께 기록한다. UI 선택 확인과 최종 backend 모델 증명을 구분한다.
5. 총괄에게 되돌리는 기본 결과는 결론·근거 파일/행·검증 방법·남은 불확실성과 원본 artifact 경로다. 큰 원문은 로컬 파일로 보존하고 필요할 때 부분만 읽는다. 이 요약 계약이 실제 재입력 토큰을 줄이는 부분이다.
6. GitHub에는 검토 가능한 diff/결론/출처 pin/비밀을 제거한 작업 ID 등 최소 증거를 남긴다. 브라우저 profile·cookies·원본 RPC capture·계정 email·인증 토큰·민감 prompt를 올리지 않는다. 결과 회수만을 이유로 GitHub에 자동 게시하지 않는다.
7. 같은 주제는 명시적 follow-up으로 잇고, 다른 주제는 별도 세션을 쓴다. 같은 탭·대화에 동시에 질문하지 않는다. 기본 동시성은 도구가 지원하는 서로 다른 탭에 한정한다.

Oracle의 기존 skill도 최소 파일 집합·dry-run·세션 재접속을 권장한다. 최신 advisor skill의 evidence 계약은 이 AGENTS 지침에 참고할 수 있지만, 새 실행 backend를 제공하지는 않는다. [기존 Oracle skill](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/skills/oracle/SKILL.md), [advisor skill](https://github.com/steipete/oracle/blob/998d11bce7e253fbcde319ec5a3c0174f1748469/skills/oracle-advisor/SKILL.md).

## 이번 환경에서의 실행 준비와 조사 한계

이 세션에서 앞서 보고된 CUA 상태 오류는 `Browsers: Error: Local browser use is disabled in Work settings`였다. 따라서 소스상 browser attach가 가능하다는 사실을 현재 장치에서 실행 가능하다는 주장으로 바꾸지 않았다. Oracle/Chrome MCP/다른 extension으로 같은 브라우저 작업을 우회 시도하지 않았다. 현재 사용자 설정을 지원된 경로로 변경한 뒤 별도 실제 왕복 검증이 필요하다. 위 비교는 공개 소스의 구현 조사이며 실제 Pro 응답·로그인 유지·완료 회수의 성공 검증은 아니다.

이 조사는 브라우저 왕복과 작업 회수에 한정했다. Astra 비용·구독 한도 절감량, UI의 현재 모델 노출, Cloud Codex/Claude/DeepSeek의 별도 인터페이스, 전체 하네스의 압축 품질·성능은 측정하지 않았다. **확인된 재사용 대상은 Oracle 세션 실행·회수와 mcporter 호출 계층이며, channel의 ledger는 설계 참고, BCB의 내구성 보강은 별도 개발 과제다.**
