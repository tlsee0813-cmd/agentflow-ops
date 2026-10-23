# Codex 총괄의 비용을 줄이는 OSS 조정 계층 조사

2026-10-23. GitHub 최신 소스와 게시된 release 정보를 읽은 조사다. 설치, 로그인, API 호출, 계정 전환, 워커 실행은 하지 않았다. 여기서 확인한 구현과 이 노트북의 실행 검증을 구분한다. 브라우저 채널은 별도 조사 범위다.

## 권장 조합

**현재 Codex 총괄을 유지하고, 짧은 AGENTS 경로 안내 + 작은 작업 명세 + 결과 파일 회수부터 적용하는 것이 가장 작다.** 기존 OSS 중 Superpowers의 작업 명세·동일 유형 작업 묶기·중복 리뷰 금지 패턴이 가장 직접적이다. 여러 CLI 사이의 작업 수락·완료 기록이 실제로 필요해질 때는 Windows 지원이 있는 Squad를 좁게 검증할 수 있다. DeepSeek 작업은 커뮤니티 bash wrapper보다 공식 DSH의 headless·JSON·subagent 구현을 기준으로 붙이는 편이 낫다.

새 총괄 플랫폼, 항상 대기하는 워커 풀, 전 작업의 다단계 분해를 먼저 도입하지 않는다. 작은 변경마다 Astra 총괄·구현자·리뷰어가 각각 같은 저장소를 처음부터 읽으면 비용이 늘 수 있다. 계층은 기본적으로 총괄→담당자 한 단계로 두고, 서로 독립된 묶음을 관리해야 할 때만 중간 담당자를 둔다. 이 계층 선택은 본 조사에 따른 운영 제안이며 특정 OSS의 자동 절감 보장이 아니다.

## 확인한 기준점

표의 SHA는 실제 읽은 소스의 기준이다. latest release와 해당 HEAD가 같은 바이트라는 의미가 아니다. 날짜는 GitHub commit/release의 UTC 날짜다.

| 후보 | 읽은 전체 SHA / 마지막 commit | 확인한 배포 정보 | 라이선스 | 이번 환경에서의 판단 |
| --- | --- | --- | --- | --- |
| [obra/superpowers](https://github.com/obra/superpowers) | `2ce8aa15d05bd57213e6f746f953aafb7ded7a8b` / 2026-10-21 | v7.0.1, 2026-10-21 | MIT | 명세·문맥 분리·작업 묶기 패턴 우선. plugin 전체 도입은 별도 판단 |
| [numman-ali/openskills](https://github.com/numman-ali/openskills) | `57d933a4f0d5c8659bd8b285f50fb9554360f0b3` / 2026-01-18 | v1.5.0, 2026-01-17 | Apache-2.0 | AGENTS의 skill 목록/필요 시 본문 읽기. 이미 native skill 발견이 있으면 중복 설치 이득이 작음 |
| [mco-org/squad](https://github.com/mco-org/squad) | `8146bcc1c38c439aedaf3ff44548c830654c8621` / 2026-05-26 | v0.7.6, 2026-04-05 | MIT | 서로 다른 CLI의 작은 로컬 작업 버스 후보. Windows binary 지원, 자동 worker 시작은 별개 |
| [anomalyco/opencode](https://github.com/anomalyco/opencode) | `02671e66454260d77fe04d63cf5eb94e76921dee` / 2026-10-23 | v1.19.4, 2026-10-22 | MIT | 모델별 child session·재사용·권한이 실제 구현됨. 현재 총괄을 바꾸기에는 도입 범위가 큼 |
| DSH: [공식 runtime](https://github.com/deepseek-ai/deepseek-harness) + [기존 커뮤니티 조립](https://github.com/diginno-net/grokbot-dsh-orchestrator-vn) | 공식 `687f282e8625c6b8d11ff58211a90524be2e4317` / 2026-10-17; 조립 `5b6c9392c86bbeeeb6263bc54375abf607c3ef60` / 2026-10-21 | 공식 apps/cli package 0.2.1-rc.2; 조회한 두 repo의 latest GitHub release 없음 | 공식 MIT; 커뮤니티 scripts/config MIT, 문서·skill CC BY 4.0 | DeepSeek headless worker 후보. 공식 Claude subagent도 존재하나 fresh one-shot이며 기존 세션 resume는 안 됨 |

OpenSkills의 GitHub license API는 NOASSERTION이었지만 실제 [LICENSE](https://github.com/numman-ali/openskills/blob/57d933a4f0d5c8659bd8b285f50fb9554360f0b3/LICENSE)와 package.json은 Apache-2.0을 명시한다. DSH 커뮤니티 repo도 단일 MIT로 표시하지 않고 [분리 라이선스](https://github.com/diginno-net/grokbot-dsh-orchestrator-vn/blob/5b6c9392c86bbeeeb6263bc54375abf607c3ef60/LICENSE)를 따랐다.

## 1. Superpowers: 명세와 결과를 작게 전달하는 패턴

실제 [implementer-prompt.md](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/skills/subagent-driven-development/implementer-prompt.md)는 작업 본문·관련 맥락·완료 기준을 구성하고 상세 보고서는 파일에, 부모에게 돌려주는 상태는 짧게 두게 한다. 구현자가 다시 구현자나 리뷰어를 부르지 못하도록 명시해 총괄의 리뷰와 중복되는 비용을 막는다. [batching.md](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/skills/subagent-driven-development/references/batching.md)는 같은 형태의 작은 변경을 파일별 워커로 나누지 않고 한 명세·한 리뷰로 묶는다.

[SDD skill](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/skills/subagent-driven-development/SKILL.md)은 fresh 구현자·작업별 리뷰·최종 리뷰를 둔다. 반면 [executing-plans](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/skills/executing-plans/SKILL.md)는 같은 문맥에서 구현하고 마지막에 한 번 새 리뷰를 받는 경로도 제공한다. 후자를 단순·잘 정의된 작업에 검토할 수 있으나 두 방식의 실제 비용 차이는 우리 작업으로 측정해야 한다.

현재 Codex App/CLI plugin 설치 경로가 README에 있다. 다만 [Codex 도구 안내](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/skills/using-superpowers/references/codex-tools.md)의 config 키·모델 override·wait 길이를 이 호스트에 그대로 복사하면 안 된다. 실제 도구의 모델/effort allowlist와 상위 지시가 우선이다. plugin 전체에는 설계 승인·TDD·worktree 등 추가 절차도 있으므로 단순한 비용 절감 패키지로 표현하지 않는다. 스크립트 실행의 native Windows 적합성도 이번에 검증하지 않았다.

**우선 활용:** 작은 task brief, 상세 결과 파일+짧은 상태, 같은 유형 작업 묶기, 작업자가 중복 리뷰를 만들지 않는 규칙. 전체 plugin 설치는 미실행이다.

## 2. OpenSkills: AGENTS를 본문 창고 대신 목록으로 유지

[agents-md.ts](https://github.com/numman-ali/openskills/blob/57d933a4f0d5c8659bd8b285f50fb9554360f0b3/src/utils/agents-md.ts)는 skill 이름·설명·위치 목록과 필요 시 read하는 안내를 생성한다. [read.ts](https://github.com/numman-ali/openskills/blob/57d933a4f0d5c8659bd8b285f50fb9554360f0b3/src/commands/read.ts)는 선택한 SKILL.md를 stdout으로 내보낸다. 따라서 모든 skill 본문을 AGENTS에 넣지 않고 필요한 절차만 읽는 구성이 가능하다.

[sync.ts](https://github.com/numman-ali/openskills/blob/57d933a4f0d5c8659bd8b285f50fb9554360f0b3/src/commands/sync.ts)는 AGENTS를 실제로 생성·수정한다. 긴 설명을 많이 선택하면 목록 자체도 커지며, 이것은 실행 권한 제어·작업 큐·외부 worker 수명 관리가 아니다. 이미 이 호스트가 제공하는 native skill 목록과 중복되므로 지금 추가 설치를 권하지 않는다. 필요하면 공용 저장소에서 skill index를 생성하는 용도로만 평가한다. Node 기반 경로 API를 쓰지만 이 노트북의 Windows 실행 검증은 하지 않았다.

**우선 활용:** 루트 AGENTS에는 공통 규칙과 짧은 경로 안내만 남기고, 도메인 절차를 별도 파일로 읽는 구조. 큰 전역 목록의 자동 주입은 피한다.

## 3. Squad: 서로 다른 CLI의 수락·완료를 기록하는 작은 버스

[README](https://github.com/mco-org/squad/blob/8146bcc1c38c439aedaf3ff44548c830654c8621/README.md)는 Windows MSVC ZIP과 Codex/Claude/Gemini/OpenCode 등록을 제공한다. 핵심은 각 CLI가 사용하는 `.squad/messages.db`의 로컬 SQLite 버스다. [store.rs](https://github.com/mco-org/squad/blob/8146bcc1c38c439aedaf3ff44548c830654c8621/src/store.rs)의 create/ack/complete는 task UUID, assignee, lease owner와 상태 전이를 검사하고 조건부 UPDATE로 충돌을 거부한다. 부모가 긴 대화를 복제하는 대신 작업 명세와 결과 요약을 교환할 수 있다.

이 상태는 AI가 보고한 완료다. 테스트 통과·diff 품질·원격 작업 성공을 자동으로 검증하는 receipt는 아니다. 로컬 DB가 GitHub의 공유 작업 기록을 대체하지도 않는다. 최종 SHA·변경 경로·검증·결과 링크는 기존 GitHub 산출물로 회수해야 한다.

[setup.rs](https://github.com/mco-org/squad/blob/8146bcc1c38c439aedaf3ff44548c830654c8621/src/setup.rs)의 템플릿은 join 이후 receive 대기, timeout이면 재진입하도록 안내한다. 단순히 설치하면 유휴 비용이 사라진다고 볼 수 없다. [init.rs](https://github.com/mco-org/squad/blob/8146bcc1c38c439aedaf3ff44548c830654c8621/src/init.rs)는 `.gitignore`, AGENTS/CLAUDE/GEMINI 안내도 쓴다. 일부 명령 경로는 설치된 안내를 갱신하므로 전부 read-only라고 취급하지 않는다.

기본 Rust CLI와 [선택적 tmux launcher](https://github.com/mco-org/squad/blob/8146bcc1c38c439aedaf3ff44548c830654c8621/scripts/squad-tmux-launch.sh)는 별개다. 후자는 Unix, tmux, Ruby, Claude를 요구한다. Windows core binary 지원이 Claude CLI 자동 실행·감독의 검증까지 뜻하지 않는다. DSH는 내장 client 선택지에 없고 일반 bus 연동은 별도 적합성 확인이 필요하다.

**후보 관문:** 이미 동작하는 Claude CLI가 준비됐을 때 fake 명세 한 개로 create→ack→complete→결과 파일 회수만 검증한다. 여러 CLI를 상시 대기시키는 운영은 아직 채택하지 않는다.

## 4. OpenCode: 실제 child session 계층이 있지만 총괄 교체 범위가 큼

읽은 HEAD의 [subagent.ts](https://github.com/anomalyco/opencode/blob/02671e66454260d77fe04d63cf5eb94e76921dee/packages/core/src/tool/plugin/subagent.ts)는 fresh child 생성, agent/model 선택, 부모-child 관계 검사, sessionID를 통한 같은 child 후속 작업, background 완료 통지와 실패 처리를 구현한다. 기본 하위 깊이는 1이고 설정으로 늘릴 수 있다. 새 child에는 작업 prompt를 전달하며 부모 전체 transcript를 복제하지 않는다. 이는 README의 역할 설명만 있는 경우보다 구체적인 구현이다.

[instructions.ts](https://github.com/anomalyco/opencode/blob/02671e66454260d77fe04d63cf5eb94e76921dee/packages/core/src/session/instructions.ts)는 세션에서 이미 주입한 지시 파일을 중복 주입하지 않으며, compaction으로 보이는 문맥에서 사라지면 다시 읽을 수 있게 한다. [rules 문서](https://github.com/anomalyco/opencode/blob/02671e66454260d77fe04d63cf5eb94e76921dee/packages/web/src/content/docs/rules.mdx)는 AGENTS 경로와 필요할 때 참고 파일 읽기를 설명한다. 모든 glob 문서를 초기 instructions에 넣으면 오히려 초기 문맥이 커질 수 있다.

[Windows 문서](https://github.com/anomalyco/opencode/blob/02671e66454260d77fe04d63cf5eb94e76921dee/packages/web/src/content/docs/windows-wsl.mdx)는 native 실행이 가능하되 WSL을 권한다. 별도 세션·provider·설정 체계를 추가하는 도구이므로 현재 Codex App의 같은 대화, Cloud, Oracle, Claude 이용 상태가 그대로 이전된다고 보장하지 않는다. OpenCode의 모델 provider 지원은 기존 Claude CLI 구독·대화 이어받기와도 다르다. 최신 HEAD 구현과 하루 전 release의 동등성은 검증하지 않았다.

**판단:** 여러 모델을 하나의 새 harness에서 직접 관리하려는 경우에 유효한 후보. 현재 Codex 총괄을 유지하는 최소 조립에서는 우선순위가 낮다.

## 5. DSH: 기존 bash 조립과 공식 runtime의 경계를 분리

DSH는 DeepSeek Harness다. [DeepSeek 공식 소개](https://www.deepseek.com/en/harness/)가 `@deepseek-ai/dsh`와 [공식 소스](https://github.com/deepseek-ai/deepseek-harness)를 연결한다. 커뮤니티 조립은 Diginno의 **grokbot-dsh-orchestrator-vn**이며, Grok을 총괄로 전제한다. Codex 적용은 별도 작업·권한·결과 회수 규칙이 필요하다.

### 기존 커뮤니티 wrapper에서 실제 확인한 것

[run-dsh.sh](https://github.com/diginno-net/grokbot-dsh-orchestrator-vn/blob/5b6c9392c86bbeeeb6263bc54375abf607c3ef60/scripts/run-dsh.sh)는 작업 폴더에서 stdin prompt로 `--profile headless --json -`를 실행하고 stdout/stderr를 run.jsonl/run.err로 나눈다. `final` 이벤트의 text를 final.txt로 추출하며 DSH exit code를 반환한다. [config](https://github.com/diginno-net/grokbot-dsh-orchestrator-vn/blob/5b6c9392c86bbeeeb6263bc54375abf607c3ef60/config/cordis.patch.yml.example)는 OpenCode Go endpoint와 환경 변수 key, Flash/Pro 모델을 지정한다.

그러나 wrapper에는 exclusive task ID·중복 실행 방지·timeout·중단 receipt·입력 SHA 결합·결과 검증·자동 resume가 없다. 같은 폴더 재실행은 로그를 덮어쓴다. JSON parse 오류와 final 추출 오류를 무시해 final이 비어도 DSH exit 0을 그대로 돌려줄 수 있다. 상대 WORKDIR와 inline prompt 조합도 cd 이전/이후 경로 해석을 주의해야 한다. native PowerShell용 wrapper가 아니며 WSL/Git Bash 사용 또는 공식 CLI 직접 호출 검증이 필요하다. 문서의 작업별 가격·cache·성공 사례는 작성자 관찰이지 이 노트북의 절감 실측이 아니다.

### 공식 runtime이 이미 제공하는 구현

공식 [headless json-stream.ts](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/bundle/headless/src/json-stream.ts)는 sessionId/cwd로 시작하고 terminal final text를 내보낸다. 로그의 sessionId와 실제 결과를 결합해 회수할 수 있으나 이것만으로 요청 작업의 정확성까지 증명하지는 않는다. CLI는 [apps/cli package](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/apps/cli/package.json)의 0.2.1-rc.2 기준이며 preview라 실행 전에 해당 버전의 headless 옵션을 다시 확인해야 한다.

특히 공식 [subagent-claude-code](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/subagent/subagent-claude-code/README.md)가 있다. pinned Claude Agent SDK 0.3.263의 native payload를 쓰고, 부모에게는 최종 답변 또는 안전한 실패 진단만 돌려준다. [run.ts](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/subagent/subagent-claude-code/src/run.ts)는 success subtype, is_error=false, 비어 있지 않은 result와 정상 stream 종료를 확인한다. 기본 unattended 권한은 dontAsk이며 사용자 입력이 필요한 경로를 거절한다.

이 provider는 **매번 fresh one-shot**이다. host PATH의 claude로 fallback하지 않고, 기존 Claude 세션 resume·pool·진행 stream을 제공하지 않는다. native 설정·인증을 사용하지만 설치만으로 기존 Claude 이용 권한이 확인되는 것은 아니다. 부모와 같은 workspace에서 실행하므로 별도 폴더·허용 도구·diff 검토도 여전히 필요하다. CLI와 SDK/프로세스 관리 구현을 새로 작성하기 전에 검증할 가치가 있으나 이번에는 설치·인증·실행하지 않았다.

**먼저 맡길 좁은 일:** 고정 CSV 집계, 이미 모은 자료의 표 정규화, 변경 경로/누락 목록 추출, 정해진 형식의 초안. 새로운 사실 확인·브라우저 로그인·외부 발송·최종 채택은 현재 총괄과 기존 채널에 남긴다. 이미 가진 Pro 조사·Cloud·Claude와 역할이 겹치는 일부터 워커 풀로 늘릴 이유는 없다.

## AGENTS와 GitHub 산출물에 적용할 최소 계약

다음은 파일을 추가·수정한 결과가 아니라 향후 조립을 위한 제안이다.

1. 루트 AGENTS는 공통 규칙, 현재 상태 문서, 역할별 필요한 경로만 안내한다. 모든 조사 문서·skill 본문·과거 로그를 항상 읽게 하지 않는다.
2. 위임 입력에는 task ID, 기준 GitHub SHA, 필요한 경로, 읽기/쓰기 범위, 산출물 경로와 완료 조건을 넣는다. 이전 대화 전체 대신 이 명세를 전달한다.
3. 작업자는 할당 범위에서만 수행하고 하위 워커·독립 리뷰를 스스로 늘리지 않는다. 같은 형태의 작은 변경은 묶고, 같은 파일을 동시에 편집하지 않는다.
4. 결과는 상태, 관련 commit/diff, 검증 근거, 남은 문제, 상세 산출물 링크로 회수한다. 원본 세션/비밀은 비공개이며 GitHub에는 공유 가능한 결과만 둔다.
5. 실패·미완료·timeout을 성공과 구분한다. native session/task ID가 있으면 같은 실행을 먼저 조회하고, 답이 늦다는 이유로 새 작업을 중복 전송하지 않는다.
6. 현재 허용된 모델·도구·사용자의 위임 범위를 따른다. 외부 OSS의 예시 model ID·무제한 권한·config 키는 그대로 복사하지 않는다.

이 구조는 현재 Codex 총괄 + GitHub 결과 공유 + Oracle 웹 Pro + native Cloud + 기존 Claude + 후순위 DSH와 함께 쓸 수 있는 설계다. 각각의 실제 worker 연결과 같은 작업 회수는 별도 실행 증거가 필요하다. 브라우저 정책과 계정 전환 시스템은 이 조사에서 변경하지 않았다.

## 절감 여부를 판단할 측정

같은 완료 조건을 가진 대표 작업으로 현재 방식과 좁은 worker 경로를 비교한다. provider가 실제 보고한 부모/자식 input·output·cache 사용량, 재시도 수, 전체 시간, 검증 통과 여부를 따로 기록한다. 사용량을 제공하지 않는 채널은 미측정으로 남기며 stdout 길이를 토큰이나 비용으로 환산하지 않는다. 구독 quota와 별도 API 과금도 합치지 않는다.

목표는 Astra가 반복 탐색·중간 로그까지 모두 읽는 일을 줄이고, 요구 해석·애매한 판단·최종 검토에 집중하게 하는 것이다. 본 조사만으로 절감률, 99% cache, 무중단 worker pool, 모든 채널 기능 동등성을 주장하지 않는다.
