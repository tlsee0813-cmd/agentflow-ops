# AgentFlow Ops

계정을 바꿔도 로컬 총괄 작업을 이어가고, 기존 Pro·Claude·Cloud·브라우저·GitHub 작업을 더 편하게 쓰기 위한 **기존 도구의 조립 저장소**입니다.

노트북의 대화·브라우저 세션이 유지되는 사용 환경을 전제로 합니다. **현재는 사용자가 선택한 Pro를 유지하고 계정 전환 시험을 미뤘습니다.** 우선 작업은 Astra의 반복 조사·구현 부담을 줄이는 작업 분배와 결과 회수입니다.

## 지금 작업하는 방법

총괄 AI에게 작업을 주면 **웹 Pro에 조사 → Claude Code에 구현 → GitHub 브랜치 회수 → 로컬 검증·통합** 순서로 진행합니다. Pro는 로그인된 Oracle 프로필과 CLI를 사용합니다. CLI를 실행 도구의 세션에 유지해 두고 총괄은 다른 일을 계속합니다. Claude Code와 화면 조작은 기존 CUA 도구를 사용합니다. 사용자가 프롬프트나 답변을 직접 옮길 필요는 없습니다.

파일 문맥 준비는 Oracle 원본 기능을 그대로 사용합니다.

~~~powershell
pnpm pro:bundle -p "비교할 질문과 완료 조건" --file 관련/파일.md
~~~

CUA로 작업할 때는 이 출력 전체를 브라우저 초안에 넣고 확인한 후 한 번 전송합니다. 답변이 늦으면 같은 URL로 돌아가 회수합니다. Oracle는 별도 전용 Chrome 프로필을 사용하며 앱 브라우저의 대화를 자동으로 가져오는 방식은 아닙니다.

현재 연결된 Oracle는 [세 명령](docs/PRO_TASK_CLI_KO.md)으로 전송·상태·전체 결과를 다룹니다. 자체 큐나 상주 서버를 추가하지 않고 Oracle의 세션을 재사용합니다.

~~~powershell
node scripts/pro-task.mjs submit .ops/my-work.json
node scripts/pro-task.mjs status ACTUAL_ORACLE_SESSION_ID
node scripts/pro-task.mjs result ACTUAL_ORACLE_SESSION_ID
~~~

my-work.json은 prompts/WORK_ORDER.md를 채운 prompt와 관련 files, engine:browser, model:gpt-6-pro, dryRun:false를 넣은 실제 작업 요청입니다. 기존 requests/pro-review.json은 안전한 dry run 예제입니다. CUA 대화 URL과 Oracle sessionId는 서로 호환되지 않습니다. `pnpm pro:doctor --json --dry-run`은 설치·설정 확인용이며 반복 실행할 필요는 없습니다.

## 현재 선택

| 역할 | 우선 후보·도구 | 확인 상태 |
| --- | --- | --- |
| 계정 전환·한도 후 같은 대화 재개 | **Codex Switch 1.41.1 원본** | Business 2·Plus·Pro 보관. 자동 회전 비활성, 자동 재개 미검증. 사용자 Pro 선택 유지 |
| 작업 분배·문맥 절약 | **AGENTS.md + 좁은 작업 지시/결과 규약** | 저장소 지침 반영. 모델 자동 변경·외부 채널 자동 연결을 의미하지 않음 |
| 웹 Pro 질문·비동기 답변 회수 | **Oracle 0.22.0 + mcporter 0.16.0** | 전용 프로필 로그인 후 실제 Pro 요청·완료·전체 결과 회수 확인. CLI 전송/조회 연결 |
| 웹 Pro 직접 시험 | **기존 CUA 브라우저 도구** | 로그인 후 질문·완료·답변 회수 확인. Oracle 실행 성공과 구분 |
| CLI에서 MCP 호출 | **mcporter 0.16.0** | Oracle 도구 5개 조회·dry run 성공 |
| 화면 보기·이미지·조작 | **기존 브라우저 도구 유지** | 현재 CUA 조작·화면 증거 보관 확인. Chrome DevTools MCP는 별도 후보 |
| 원격 작업 | **브라우저의 기존 Cloud 환경** | 생성·실행·후속 결과 회수 확인. GitHub 직접 조회는 프록시 연결 실패; 제공 자료 검토 가능 |
| Codex Cloud CLI | **현재 Codex CLI** | 도움말·실제 목록 조회 성공. 위 브라우저 경로와 별개 |
| Claude 위임 | **기존 Claude Code 웹 환경** | 실제 CLI 구현을 브랜치 커밋으로 회수, Windows 검사와 독립 수정까지 실행. 로컬 CLI와 구분 |
| DeepSeek | **DSH의 기존 headless 실행** | 후순위 |

QuotaCrew는 같은 Business workspace 사용자 구분 문제로 보류했습니다. 원본 Codex Switch에 연결할 우선순위 정책과 경계 전환 스크립트는 준비 중이며 실행하지 않았습니다. Oracle의 세션 저장·wait·harvest·followup을 재사용합니다.

## AI가 바로 쓰는 환경

Node 24 이상, pnpm 기준입니다. 저장소 루트에서 실행합니다.

~~~powershell
pnpm install --ignore-scripts --frozen-lockfile
pnpm exec mcporter list oracle --schema --config config/mcporter.json
Get-Content -LiteralPath requests/pro-review.json -Raw -Encoding utf8 |
  pnpm exec mcporter call oracle.consult --args - --output json --config config/mcporter.json
~~~

Oracle의 CLI 왕복과 CUA의 Pro·Claude 작업 경로를 연결했습니다. 두 Business 사용자는 Codex Switch의 원본 암호화 vault에 보관되어 있습니다. 계정 전환/복귀와 한도 후 자동 회전은 현재 보류입니다.

예시 요청은 **dryRun=true**입니다. 실제 질문을 보내거나 브라우저를 조작하지 않습니다. 연결할 때는 [실행 안내](docs/RUNBOOK_KO.md)를 따릅니다. 자격증명·브라우저 프로필·계정 데이터는 공개 저장소에 넣지 않습니다.

- [채택 판단과 전체 작업 흐름](docs/DESIGN_KO.md)
- [하네스 선택과 소스 비교](docs/HARNESS_SELECTION_KO.md)
- [작업 분배·회수 운영](docs/HARNESS_RUNBOOK_KO.md)
- [워커 지시](prompts/WORK_ORDER.md) · [결과 반환](prompts/WORK_RESULT.md)
- [새 세션·웹 Pro·Claude·Cloud 시험과 화면 증거](results/harness-smoke-2026-10-23/RESULT.md)
- [실제 CLI 작업·Claude 구현·통합 결과](results/ops-live-2026-10-23/RESULT.md)
- [계정 전환 방식과 우선 확인 순서](docs/ACCOUNT_DECISION_KO.md)
- [현재 계정 운영과 가져오기 범위](docs/ACCOUNT_OPERATIONS_KO.md)
- [보류한 QuotaCrew 초기 준비](docs/QUOTACREW_CLI_KO.md)
- [Switchy 준비 후 보류 기록](docs/SWITCHY_CONTROL_KO.md)
- [이전 작업과의 비교 기준](docs/COMPARISON_KO.md)
- [실행·회수 안내](docs/RUNBOOK_KO.md)
- [현재 상태와 다음 단계](docs/STATUS.md)
- [오픈소스 코드 검토](docs/UPSTREAM_REVIEW.md)
- [버전·소스 고정 기록](upstreams.lock.json)

작업 기준·정리된 결과·대표 증거는 GitHub에 남기고, 총괄이 원문·코드·화면을 대조해 판단·통합합니다.
