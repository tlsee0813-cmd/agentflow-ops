# AgentFlow Ops

계정을 바꿔도 로컬 총괄 작업을 이어가고, 기존 Pro·Claude·Cloud·브라우저·GitHub 작업을 더 편하게 쓰기 위한 **기존 도구의 조립 저장소**입니다.

노트북의 대화·브라우저 세션이 유지되는 사용 환경을 전제로 합니다. 계정 전환 품질을 먼저 판단하고, 이전 작업을 그대로 또는 더 편하게 수행하는 도구만 붙입니다.

## 현재 선택

| 역할 | 우선 후보·도구 | 확인 상태 |
| --- | --- | --- |
| 계정 전환·한도 후 같은 대화 재개 | **Switchy / QuotaCrew / codex-switch 비교** | 정상 종료와 자동 재개 방식 비교, 로컬 전환 미실행 |
| 웹 Pro 질문·비동기 답변 회수 | **Oracle 0.22.0** | 설치·입력 렌더·MCP dry run 성공, 실제 브라우저 왕복 미실행 |
| CLI에서 MCP 호출 | **mcporter 0.16.0** | Oracle 도구 5개 조회·dry run 성공 |
| 화면 보기·이미지·조작 | **기존 브라우저 도구 유지** | 기존 경로 사용. Chrome DevTools MCP 1.12.0은 추가 후보 |
| Codex Cloud | **현재 Codex CLI·기존 브라우저** | CLI 도움말·실제 목록 조회 성공, 제출/완료 회수는 미실행 |
| Claude 위임 | **기존 Claude Code 사용 환경** | 현재 로컬 PATH에서는 CLI 미발견, 기존 경로 유지 |
| DeepSeek | **DSH의 기존 headless 실행** | 후순위 |

계정 도구는 실제 전환 품질을 먼저 확인해 하나만 선택합니다. QuotaCrew는 자동화 기능이 넓지만 Windows 앱 강제 종료 경로가 있어 바로 확정하지 않았습니다. 별도 전환기·스케줄러·전송 장부를 새로 만들지 않습니다. Oracle의 세션 저장·wait·harvest·followup도 그대로 사용합니다.

## AI가 바로 쓰는 환경

Node 24 이상, pnpm 기준입니다. 저장소 루트에서 실행합니다.

~~~powershell
pnpm install --ignore-scripts --frozen-lockfile
pnpm exec mcporter list oracle --schema --config config/mcporter.json
Get-Content -LiteralPath requests/pro-review.json -Raw -Encoding utf8 |
  pnpm exec mcporter call oracle.consult --args - --output json --config config/mcporter.json
~~~

예시 요청은 **dryRun=true**입니다. 실제 질문을 보내거나 브라우저를 조작하지 않습니다. 연결할 때는 [실행 안내](docs/RUNBOOK_KO.md)를 따릅니다. 자격증명·브라우저 프로필·계정 데이터는 공개 저장소에 넣지 않습니다.

- [채택 판단과 전체 작업 흐름](docs/DESIGN_KO.md)
- [계정 전환 방식과 우선 확인 순서](docs/ACCOUNT_DECISION_KO.md)
- [이전 작업과의 비교 기준](docs/COMPARISON_KO.md)
- [실행·회수 안내](docs/RUNBOOK_KO.md)
- [현재 상태와 다음 단계](docs/STATUS.md)
- [오픈소스 코드 검토](docs/UPSTREAM_REVIEW.md)
- [버전·소스 고정 기록](upstreams.lock.json)

작업 기준·정리된 결과·대표 증거는 GitHub에 남기고, 총괄이 원문·코드·화면을 대조해 판단·통합합니다.
