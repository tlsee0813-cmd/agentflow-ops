# 현재 상태

2026-10-23. **Codex 앱 총괄용 하네스**를 구성했다. 계정 자동 전환은 사용자 지시로 제외하며 현재 선택한 계정을 유지한다. 제품의 진행 상태는 해당 제품 저장소의 ACTIVE 등에서 별도로 확인한다.

## 새 총괄 세션

개인 스킬 `agentflow-coordinator`가 기존 Ops runtime을 가리킨다. 새 Codex 앱 로컬 세션에서 `$agentflow-coordinator`와 이번 목표를 전달한다. [시작 방법](NEW_CODEX_SESSION_KO.md) · [진행 중 작업/기존 세션](COORDINATOR_STATE.md).

총괄은 목표·배정·결과 회수·채택 판단·통합을 맡는다. 외부 워커에게는 관련 자료와 좁은 작업 지시만 전달한다. 내장 보조는 Sol high, 어려운 판단은 Astra high로 제한한다. 이 지침은 모델 자동 전환기나 무인 스케줄러가 아니다.

## 채널별 실제 상태

| 채널 | 사용할 수 있는 범위 | 남은 제약 |
|---|---|---|
| Pro / Oracle 0.22.0 | 로그인된 전용 Chrome 프로필로 실제 작업 전송·completed·전체 결과 회수 확인 | submit 부모 실행을 유지. MCP detached consult는 worker 유실로 사용하지 않음 |
| Claude Code 웹 | 실제 구현을 GitHub 브랜치/커밋으로 회수하고 Windows에서 검증·통합 완료 | 새 세션의 브라우저 도구 접근 필요. 로컬 Claude CLI 설치와는 별개 |
| 화면 조사·조작 | 기존 허용된 CUA 도구 | 설치된 별도 Chrome MCP의 접근 거절을 우회하지 않음 |
| Cloud 기존 durable 환경 | 실행·후속 입력·회수, 제공한 고정 SHA 발췌 검토 | 관리형 프록시 연결 오류로 최신 GitHub 직접 조회·제품 독립 테스트 준비 안 됨. 필요시 로컬 독립 검증 |
| DeepSeek / DSH 0.2.1-rc.2 | 사용자 로컬 API 키로 실제 역할 분류 completed·exit 0·결과 회수 확인 | 좁은 텍스트 작업만. 셸·웹·파일·위임 도구는 비활성화. 비용/토큰 측정은 미제공 |

[Pro 실행 방법](PRO_TASK_CLI_KO.md) · [Cloud 사용 범위](CLOUD_CHANNEL_KO.md) · [분배 기준](HARNESS_RUNBOOK_KO.md).

[총괄 스킬·DeepSeek 연결 결과](../results/coordinator-harness-2026-10-23/RESULT.md): 개인 스킬 설치/재설치·형식 검사, 독립 새 문맥의 Pro dry-run, 실제 Pro 스킬 검토와 수정, DeepSeek 실제 분류 응답을 확인했다. 새 Codex 앱 세션의 UI 스킬 목록 발견과 모든 채널을 이용한 제품 작업 전체는 아직 별도 실행하지 않았다.

## 완료 근거와 회수 규칙

- `ops-live-routing-review`: completed 2분 56초, 전체 2,962자 회수. `ops-doctor-live-review`: 최종 submit 경로로 completed 2분 06초, 전체 2,387자 회수. Pro 지적 두 오판을 수정했다.
- Claude 커밋 `c03ed872c103ef2d08947148611a017eae5f8aee`를 회수하고 독립 수정·Windows 검사 9개를 통과했다. [실무 조립 결과](../results/ops-live-2026-10-23/RESULT.md).
- `ops-cli-result-review`는 worker 유실이다. 원본 메타데이터 running을 실행 성공으로 세거나 같은 작업을 다시 보내지 않는다.
- `result`는 진행 줄을 포함한 전체 원본 로그다. 상태/완료 조건을 따로 확인하고 공개용 결과만 검토해 GitHub에 남긴다. 인증·프로필·비공개 원문은 올리지 않는다.

## 제외한 계정 작업

Codex Switch 원본과 보관된 프로필은 유지한다. 자동 정책·전환 시험은 실행하지 않는다. 계정 교체 대상은 총괄 Codex뿐이며 Pro·Claude 브라우저 로그인은 유지한다. 재개 요청 때만 [계정 운영](ACCOUNT_OPERATIONS_KO.md)을 읽는다.

과거 설치·연결 실패는 [초기 시험](../results/harness-smoke-2026-10-23/RESULT.md)과 Git 이력에 남아 있다. 과거의 미연결 문장을 현재 상태로 해석하지 않는다. 연구 문서는 당시 판단이며 현재 연결 성공의 증거가 아니다.
