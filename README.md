# AgentFlow Ops

계정을 바꿔도 로컬 총괄 작업을 이어가고, 기존 Pro·Claude·Cloud·브라우저·GitHub 작업을 더 편하게 쓰기 위한 **기존 도구의 조립 저장소**입니다.

노트북의 대화·브라우저 세션이 유지되는 사용 환경을 전제로 합니다. **현재는 사용자가 선택한 Pro를 유지하고 계정 전환 시험을 미뤘습니다.** 우선 작업은 Astra의 반복 조사·구현 부담을 줄이는 작업 분배와 결과 회수입니다.

## 현재 선택

| 역할 | 우선 후보·도구 | 확인 상태 |
| --- | --- | --- |
| 계정 전환·한도 후 같은 대화 재개 | **Codex Switch 1.41.1 원본** | Business 2·Plus·Pro 보관. 자동 회전 비활성, 자동 재개 미검증. 사용자 Pro 선택 유지 |
| 작업 분배·문맥 절약 | **AGENTS.md + 좁은 작업 지시/결과 규약** | 저장소 지침 반영. 모델 자동 변경·외부 채널 자동 연결을 의미하지 않음 |
| 웹 Pro 질문·비동기 답변 회수 | **Oracle 0.22.0** | 설치·입력 렌더·MCP dry run 성공, 실제 브라우저 왕복 미실행 |
| CLI에서 MCP 호출 | **mcporter 0.16.0** | Oracle 도구 5개 조회·dry run 성공 |
| 화면 보기·이미지·조작 | **기존 브라우저 도구 유지** | Work 로컬 브라우저 비활성화로 점검 대기. Chrome DevTools MCP는 추가 후보 |
| Codex Cloud | **현재 Codex CLI·기존 브라우저** | CLI 도움말·실제 목록 조회 성공, 제출/완료 회수는 미실행 |
| Claude 위임 | **기존 Claude Code 사용 환경** | 현재 로컬 PATH에서는 CLI 미발견, 기존 경로 유지 |
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

현재 이 세션의 Work 로컬 브라우저 기능은 비활성화 오류를 반환하므로 실제 브라우저 왕복은 대기 상태입니다. 추가 재로그인 없이 두 Business 사용자를 Codex Switch의 원본 암호화 vault로 가져왔고, 기존 현재 로그인도 보존했습니다. 실제 전환/복귀와 한도 후 자동 회전은 아직 합격으로 표시하지 않습니다.

예시 요청은 **dryRun=true**입니다. 실제 질문을 보내거나 브라우저를 조작하지 않습니다. 연결할 때는 [실행 안내](docs/RUNBOOK_KO.md)를 따릅니다. 자격증명·브라우저 프로필·계정 데이터는 공개 저장소에 넣지 않습니다.

- [채택 판단과 전체 작업 흐름](docs/DESIGN_KO.md)
- [하네스 선택과 소스 비교](docs/HARNESS_SELECTION_KO.md)
- [작업 분배·회수 운영](docs/HARNESS_RUNBOOK_KO.md)
- [워커 지시](prompts/WORK_ORDER.md) · [결과 반환](prompts/WORK_RESULT.md)
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
