---
name: agentflow-coordinator
description: Run the local Codex app coordinator for AgentFlow work using the installed Ops channels. Use for coordinating AgentFlow research, implementation, verification, or resuming its worker tasks; not for ordinary standalone questions or account switching.
---

# AgentFlow 총괄

사용자의 현재 목표를 기준으로 범위·배정·판단·통합을 담당한다. 워커 결과를 전달하는 데서 끝내지 않는다. 이 스킬은 Codex 앱 총괄용이며 외부 워커마다 설치하지 않는다.

## 시작

1. 이 스킬 옆 `runtime.json`의 `opsRoot`와 `nodePath`를 읽는다. 없으면 설치된 Ops checkout에서 `node scripts/install-coordinator-skill.mjs`를 실행한다. 새 checkout으로 브라우저 프로필을 복사하지 않는다.
2. Ops의 `docs/STATUS.md`와 `docs/COORDINATOR_STATE.md`만 먼저 읽는다. 이후 제품 저장소의 현재 상태 문서와 실제 Git 상태를 확인한다. Ops 상태를 제품 진행 상황으로 오해하지 않는다. 이전 연구 전체를 한꺼번에 읽지 않는다.
3. 사용자 요청, 실제 변경, 진행 중 작업을 대조하고 이번 결과물·완료 조건을 정한다. 현재 워커 ID가 있으면 먼저 회수한다. 과거 완료 기록을 실행 중으로 간주하지 않는다.

## 배정과 판단

- 최신 조사·후보 비교는 Pro, 좁은 구현은 Claude Code, 독립 실행 검증은 준비된 Cloud 또는 로컬 담당, 좁은 추출·분류는 연결된 DeepSeek에 맡긴다. 작업별 최신 연결 상태는 STATUS가 기준이다.
- 기존 도구로 가능한 짧은 확인은 직접 한다. 큰 조사·구현을 내장 Astra에게 반복 배정하지 않는다. 내장 보조가 필요한 경우 사용자 지정 Sol high를 기본으로, 어려운 판단만 Astra high를 쓴다. 모델 override 때는 새 독립 문맥과 필요한 자료만 전달한다.
- 독립된 작업만 병렬화하고 파일 작성자는 한 명씩 정한다. 같은 주제는 기존 세션에 변경분만 전달하고 다른 주제는 새 세션으로 나눈다. 다른 세션 생성·메시지 전송은 사용자가 승인한 범위에서 수행한다.
- `prompts/WORK_ORDER.md`에서 목적·근거 SHA/관련 파일·수정 범위·완료 조건을 채운다. 워커에는 총괄의 전체 대화나 이 스킬 전체를 복제하지 않는다.
- 결과는 결론·산출물 링크·검증·미확인부터 받고, 결정에 필요한 원문만 확인한다. 중요한 변경에는 독립 검증을 한 번 수행한다. 실제 실행, 작성자 주장, 화면 검사, 사람 사용성은 구분한다.
- 한 채널의 설치·연결 실패가 전체 작업을 멈추게 하지 않는다. 한정된 진단을 맡기고 사용 가능한 경로로 독립 작업을 진행한다. 권한 거부나 서비스 정책을 우회하지 않는다.

## 실행 경로 — 필요할 때만 세부 문서 읽기

Ops 스크립트 호출만 runtime.json의 opsRoot에서 실행한다. 제품의 Git 조회·수정·검증은 선택한 제품 저장소에서 수행한다. node가 PATH에 없으면 nodePath를 사용한다. Pro 첨부 상대 경로는 Ops 루트 기준이므로 다른 제품 파일은 해석된 경로를 dry-run으로 확인한다.

| 채널 | 실행과 회수 | 필요한 문서 |
|---|---|---|
| 웹 Pro | `node scripts/pro-task.mjs submit .ops/작업.json`; 원본 sessionId로 `status` / `result` | `docs/PRO_TASK_CLI_KO.md` |
| Claude Code | 허용된 브라우저 도구로 repo·SHA·범위를 전달; 브랜치/커밋을 회수 | `docs/COORDINATOR_STATE.md`의 기존 주제 링크 |
| Cloud | 실제 연결 상태에 맞는 task 도구 또는 브라우저; 실행 환경·기준 SHA를 먼저 확인 | `docs/CLOUD_CHANNEL_KO.md` |
| DeepSeek/DSH | 인증·설치 확인 후 원본 headless 실행 | `docs/DEEPSEEK_WORKER_KO.md` |
| 화면 조사·조작 | 현재 세션에서 허용된 브라우저 도구 | 해당 도구의 사용 지침 |

Pro submit의 exec 세션을 완료까지 유지한다. 실행 도구가 반환한 session_id와 Oracle sessionId는 다르다. 대기 중 다른 일을 하되 부모 실행을 종료하지 않는다. 상태 조회는 재전송이 아니다. 접수 여부가 불분명하면 원래 기록부터 확인하고 자동 재시도하지 않는다. CUA 대화 URL은 Oracle ID로 조회하지 않는다.

Pro 작업 JSON은 `.ops`에 둘 수 있지만 첨부 `files`는 Git ignore 대상 파일을 수집하지 못한다. 공개 추적 파일이나 prompt 안의 짧은 공개 요약을 사용한다.

## 이어가기

전송 전에 `docs/COORDINATOR_STATE.md`에 채널·주제·기준 SHA·요청 파일/slug를 `접수 확인 전`으로 기록한다. ID/링크가 나오면 즉시 채우고 다음 회수 행동을 남긴다. 새 세션은 이 미확인 행의 원본 접수 여부를 확인하기 전 재전송하지 않는다. 완료되면 채택/수정/보류와 공유 결과 링크로 갱신한다. 로컬 실행 PID는 같은 기계에서 확인할 힌트일 뿐 다른 세션에서도 살아 있다는 보장이 아니다.

전체 결과 로그는 `.ops/results`에 저장하고 상태·종료 코드를 확인한 다음 결론과 필요한 구간부터 읽는다. 이미 submit에서 받은 전체 답변을 문맥에 다시 출력하지 않는다. 잘린 터미널 출력만으로 결과를 통합하지 않는다.

공유할 코드·결정·증거는 GitHub에 둔다. 인증키·프로필·비공개 원문은 `.ops` 등 로컬 비공개 경로에 둔다. 진행 중 작업의 기록은 세션 재시작 복구용이며 별도 자동 큐나 백그라운드 스케줄러가 아니다.

계정 자동 전환은 현재 범위에서 제외한다. 사용자가 선택한 총괄 모델·계정과 외부 Pro/Claude 로그인은 유지한다. 새로운 사용자의 범위 지시가 이 운영 지침보다 우선한다.
