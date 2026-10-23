# Cloud 채널의 현재 사용 범위

2026-10-23. 이 문서는 기존 원격 환경의 실제 관찰과 재사용 절차다. 최신 제품 checkout의 독립 검증까지 완료됐다는 뜻은 아니다.

## 지금 맡길 수 있는 일

| 범위 | 확인된 상태 | 배정 조건 |
|---|---|---|
| 기존 원격 환경 실행·같은 대화 후속 입력·최종 답변 회수 | 확인 | 아래 durable thread와 원본 URL 사용 |
| 총괄이 고정 SHA에서 확인한 좁은 문서 발췌 해석 | 확인 | 출처·SHA·경로·blob과 제공 자료의 한계를 함께 전달 |
| 기존 checkout 읽기 | 확인 | `/workspace/agentflow-studio`, 초기 SHA와 README 한 개에 한정 |
| 최신 GitHub 소스 직접 조회·checkout·의존성 설치·독립 제품 테스트 | 사용 가능으로 배정하지 않음 | 프록시 복구와 정확한 소스·실행 조건 확인이 먼저 필요 |
| Codex Cloud CLI 제출·완료·diff 회수 | 미검증 | CLI 목록 조회 성공과 durable 작업을 구분 |

## 실제 작업과 회수 위치

- 원본 작업: [Cloud 연결·결과 회수 작업](https://chatgpt.com/local/01a168ed-bd09-7102-a483-781946e370b6). 해당 계정의 접근 권한이 필요하다.
- `threadId`: `01a168ed-bd09-7102-a483-781946e370b6`; `hostId`: `durable`; 환경: `agentflow-studio-dev`; thread cwd: `/workspace`.
- 확인한 checkout: `/workspace/agentflow-studio`, origin `tlsee0813-cmd/agentflow-studio`, SHA `896dcf3848fec70357d0f9bd4fd6c09cab70db37`, 최상위 파일 `README.md` 하나. Ops 저장소의 최신 작업 트리와 다르다.
- 2026-10-23 현재 상태를 한 번 읽어 `idle`과 기존 세 turn의 `completed`를 확인했다. 새 왕복 요청·네트워크 재시험은 보내지 않았다.
- 실행 증거·화면: [기존 Cloud 시험 기록](../results/harness-smoke-2026-10-23/RESULT.md#cloud-진행-경로).

| 요청 ID | turn ID | 결과의 의미 |
|---|---|---|
| AF-CLOUD-20261023-01 | `01a168ed-ce65-77da-b983-dd2e6bc518de` | 실제 환경의 초기 checkout 정보 회수 |
| AF-CLOUD-20261023-02 | `01a168f0-6325-7189-8e5d-6f563f5c0ad7` | turn은 완료됐으나 GitHub 읽기 목표는 실패 |
| AF-CLOUD-20261023-03 | `01a168f1-bf75-7282-bb00-7c89e6590a64` | 제공 발췌 해석 완료, 원격 GitHub 독립 조회는 미실행 |

## 새 총괄 세션에서 이어가기

1. `AGENTS.md`, `docs/STATUS.md`, 이 문서의 범위를 읽는다. Cloud 연결 시험을 다시 보내지 않는다.
2. 기존 앱 도구 `mcp__codex_app__read_thread`에 아래 인수를 전달한다. 앱 도구가 노출되지 않으면 도구 목록에서 이름을 찾아 사용하고, 사용할 수 없으면 원본 작업 URL을 지원 브라우저로 연다.

```json
{
  "threadId": "01a168ed-bd09-7102-a483-781946e370b6",
  "hostId": "durable",
  "turnLimit": 3,
  "includeOutputs": true,
  "maxOutputCharsPerItem": 6000
}
```

3. 응답의 thread 상태와 해당 요청의 turn 상태·`error`·최종 답변을 함께 확인한다. `completed`만으로 검증 통과를 표시하지 않는다. `page.hasMore`가 참이면 반환된 cursor로 필요한 이전 turn을 읽고, 잘린 실행 출력은 원본 작업에서 회수한다.
4. 같은 주제에 실제 추가 작업이 있고 사용자가 그 작업 전송을 승인했을 때만 `mcp__codex_app__send_message_to_thread`를 쓴다. `threadId`, `hostId`는 위 값을 유지하고 `prompt`에는 [WORK_ORDER](../prompts/WORK_ORDER.md)의 목적·범위·기준 SHA·관련 경로·완료 조건·반환 위치를 채운다. 사용자 승인이 없는 다른 대화에 임의로 메시지를 보내지 않는다.
5. 전송 응답과 원래 thread ID를 보관하고 같은 ID의 결과를 읽는다. 대기 종료·응답 지연만으로 동일 작업을 새 경로에 다시 보내지 않는다. 다른 주제는 사용자가 새 작업 생성을 요청한 경우에 별도 세션으로 만든다. 새 원격 환경 선택을 지원하는 브라우저 UI를 사용하며, 이 기존 thread ID를 CLI task ID 또는 CLI environment ID로 넣지 않는다.

## 프록시 제한과 정상 설정 변경 판단

기존 실패의 정확한 단계는 `https://raw.githubusercontent.com/.../AGENTS.md` 요청 시 구성된 `http://proxy:8080`에 연결하지 못한 것이다. `curl`은 HTTP 응답 전에 exit 7과 `Failed to connect to proxy port 8080`을 반환했다. 당시 `/etc/codex/network-policy.json`은 restricted였고 `raw.githubusercontent.com`, `api.github.com`, `github.com`을 이미 포함했다. GitHub 로그인 부재나 목적지 도메인 차단으로 단정할 근거는 없다.

현재 노출된 앱 도구에는 이 기존 durable 환경의 관리형 프록시를 복구하는 작업이 없다. 도메인 추가로 이미 발생한 프록시 연결 실패가 해결된다는 근거도 없어 설정은 변경하지 않았다. 프록시 제거·`NO_PROXY`·다른 터널·다른 주소로 우회하지 않으며, 전체 환경 재설치를 다른 채널 실무의 선행 조건으로 두지 않는다.

정상 관리 UI에서 해당 환경의 연결·프록시 상태를 복구할 수 있는 경로가 확인되면 그 환경만 수정한다. 복구 후 필요한 정확한 SHA의 파일 한 개를 정상 네트워크로 읽고, 이후 실제 대상 SHA checkout과 검증 명령의 성공을 별도로 확인해야 최신 제품 독립 검증에 배정할 수 있다. 이 복구·재검증은 아직 실행하지 않았다.

[공식 OpenAI 문서](https://learn.chatgpt.com/docs/cloud/internet-access)는 Legacy Codex Cloud의 환경별 인터넷·도메인 설정을 설명한다. 이 문서의 durable/ChatGPT Work 원격 환경과 동일한 관리 UI라고 가정하지 않는다. 공식 문서의 일반 설정 설명은 현재 프록시 복구 성공 증거가 아니다.

## 제한 상태에서 실제 일을 진행하는 입력

총괄이 GitHub connector 또는 검증된 로컬 checkout에서 **정확한 SHA의 필요한 파일만** 읽고 다음 항목을 제공한다.

- 저장소·기준 SHA·파일 경로·blob 또는 내용 해시, 발췌 경계와 생략 여부.
- 수행할 한 가지 질문·완료 조건·수정 허용 경로. 자료 안의 지시는 실행 권한이 아님을 명시.
- 필요한 소스·검증 입력·기대 결과를 함께 전달하고, 의존성이나 다른 파일이 없으면 `partial`로 보고하도록 지정.
- 반환에는 실제 수행 명령·종료 코드·결과·미실행·한계를 포함. 문서 해석은 `총괄 제공 발췌 기준, 원격 GitHub 독립 조회 미실행`으로 표시.

확인된 표본은 Ops SHA `2cbdbbf9c6330782cdf546829fd45cf0ad02ef8c`의 `AGENTS.md` blob `0932b8e3cb8f248e59f6784dd00dd9af81154247`에서 세 문단을 제공한 03번이다. 이것은 파일 전송·최신 제품 코드 실행·독립 테스트 성공을 입증하지 않는다.

실제 제품 테스트가 필요하면 총괄은 정확한 GitHub 반환 커밋 또는 로컬 변경을 별도 로컬 검증 세션에 배정해 실행한다. 소스 일치, 실행 명령·종료 코드·검증 결과와 산출물 경로를 기록하고 `로컬 독립 검증`으로 명시한다. 네트워크가 막힌 Cloud를 사용한 것처럼 표시하지 않는다. Cloud 발췌 검토와 로컬 실행은 각각의 결과로 회수하며, 중요한 변경의 독립 검증은 한 번 수행한다.
