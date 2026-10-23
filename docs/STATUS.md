# 현재 상태

2026-10-24. **Codex 앱 총괄용 하네스**를 구성했다. 사용자 별도 새 세션 시험을 검토했고 계정 자동 전환 로직을 보완했다. 실제 활성화 여부는 아래 계정 상태를 따른다. 제품의 진행 상태는 해당 제품 저장소의 ACTIVE 등에서 별도로 확인한다.

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

[총괄 스킬·DeepSeek 연결 결과](../results/coordinator-harness-2026-10-23/RESULT.md) 이후 [실제 새 세션 시험](../results/new-session-2026-10-23/RESULT.md)에서 Pro·Claude·DeepSeek 왕복과 IAB 화면·링크 조작을 확인했다. 시험 전후 운영 설정과 제품은 바꾸지 않았다. 모든 채널로 한 제품 변경을 완수하거나 계정 교체 후 동등성까지 검증했다는 뜻은 아니다. 원래 프로젝트 총괄에게 전달할 [환경 설명·인수인계 요청](../prompts/ORIGINAL_COORDINATOR_HANDOFF_KO.md)을 준비했다.

## 완료 근거와 회수 규칙

- `ops-live-routing-review`: completed 2분 56초, 전체 2,962자 회수. `ops-doctor-live-review`: 최종 submit 경로로 completed 2분 06초, 전체 2,387자 회수. Pro 지적 두 오판을 수정했다.
- Claude 커밋 `c03ed872c103ef2d08947148611a017eae5f8aee`를 회수하고 독립 수정·Windows 검사 9개를 통과했다. [실무 조립 결과](../results/ops-live-2026-10-23/RESULT.md).
- `ops-cli-result-review`는 worker 유실이다. 원본 메타데이터 running을 실행 성공으로 세거나 같은 작업을 다시 보내지 않는다.
- `result`는 진행 줄을 포함한 전체 원본 로그다. 상태/완료 조건을 따로 확인하고 공개용 결과만 검토해 GitHub에 남긴다. 인증·프로필·비공개 원문은 올리지 않는다.

## 계정 전환

**자동 순환은 Business 두 사용자와 지정 Plus 크레딧 계정 세 개만 사용한다.** Business 소진 시 다른 Business가 가능하면 그 계정으로, 아니면 Plus로 전환한다. Plus에서 작업하는 동안 Business 한도가 실제 회복되면 바로 Business로 전환한다. 매번 원본 Codex Switch의 Capture → 계정 변경 → 앱 재시작 → 같은 대화 재개를 사용하며 전체 세션 idle을 기다리지 않는다. Pro는 자동 선택 대상에서 제외한다.

명시적인 실제 Pro → Business 전환과 같은 대화 자동 재개는 검증했다. 처음 활성화했던 감시는 실제 소진 시 불필요한 idle 조건 때문에 대기했고, 이 결함을 수정했다. 자연 한도 소진 후 자동 전환·재개의 성공 여부는 실제 receipt로 별도 확인한다. [실전 기록](../results/account-priority-2026-10-24/LIVE_SWITCH.md).

최종 수정본은 2026-10-24 01:03 KST 재기동했다. enabled=true·예약 작업 Running이며 사용자가 수동 선택한 사용 가능 Pro에서 소진 대기 중이다. 자동 선택 대상에 Pro를 넣지는 않는다. 실행기 68개·정책 26개 검사와 독립 검토를 통과했다. 계정 교체 대상은 총괄 Codex뿐이다. 전환 후 Claude 로그인·기존 답변, Oracle 기록, GitHub 접근과 DSH 설치/키 존재를 확인했다. [계정 운영](ACCOUNT_OPERATIONS_KO.md) · [공통 환경](SHARED_SETUP_KO.md).

과거 설치·연결 실패는 [초기 시험](../results/harness-smoke-2026-10-23/RESULT.md)과 Git 이력에 남아 있다. 과거의 미연결 문장을 현재 상태로 해석하지 않는다. 연구 문서는 당시 판단이며 현재 연결 성공의 증거가 아니다.

공통 스킬·로컬 Git 인증·외부 워커 설정과 계정별 연결 범위는 [공통 환경](SHARED_SETUP_KO.md)에 정리했다. 로컬 Git 비대화형 push 권한 확인을 통과했다.
