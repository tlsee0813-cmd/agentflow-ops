# 새 Codex 앱 세션의 실제 통합 시험

사용자가 별도로 연 테스트 세션 `AF-ST-20261023-233533-34c50d`의 2026-10-23 23:35–23:40 KST 기록을 기존 총괄이 검토했다. 기준 Ops SHA는 `bb4dced6956bcef1ac90e1e804a8ee0339b05c78`이다. 기존 총괄 인계·제품 개발·계정 전환 없이 설치된 환경만 시험했다.

| 채널 | 판정 | 실제 근거 | 한계 |
|---|---|---|---|
| Pro | 실제 성공 | Oracle `st-233533-34c50d-pro`, 1분38초 뒤 부모 exit 0, status completed, 전체 결과 2,886자 | 공개 운영 문서의 정적 검토. 제품 구현 검증 아님 |
| Claude Code | 실제 성공 | [새 테스트 세션](https://claude.ai/code/session_016waEMizGzkXp3E2Nc86raH), checkout과 실제 원격 main SHA 일치, 요청한 답변 회수 | 읽기 전용 시험. 커밋·PR 작업은 하지 않음 |
| DeepSeek | 실제 성공 | `session-a8708eeb-3d2d-41fd-af2f-7f252323390f`, completed·turnReason completed·exit 0, 세 분류와 testId 일치 | 비용/토큰 미제공 |
| Cloud | 일부 성공 | 기존 durable thread의 후속 turn `01a16931-ad05-7030-bc5f-cfd8dc8c4bf9` 완료·해석 결과 회수 | 정상 프록시를 통한 조회는 curl 7 / HTTP 000 / proxy:8080 연결 실패. 최신 제품 검증 준비 안 됨 |
| 브라우저 | 실제 성공 | Example Domain 화면 → 링크 클릭 → IANA 도착 화면 확인 | 허용된 IAB 범위. 별도 Chrome MCP 성공으로 확대하지 않음 |

총괄은 원본 RESULT, verification, Pro 상태·부모 종료, DSH 결과, Claude 답변과 화면, 브라우저 전후 화면을 대조했다. Cloud 원문에서도 프록시 실패를 확인했다. 이 검토에서 모델 요청이나 브라우저 조작을 다시 실행하지 않았다.

## 근거

- [공개 가능한 실행 결과](receipts.json): 실제 작업 ID·종료 상태·원본 기록 SHA256. 개인 경로·인증 내용은 제외했다.
- [Claude 답변 화면](claude-final.png)
- [브라우저 이전 화면](browser-before.png) · [도착 화면](browser-after.png)

원본 시험 기록은 로컬 `.ops/session-test/AF-ST-20261023-233533-34c50d`에 보존되어 있다. 공유 링크만 받은 다른 총괄도 위 대표 화면과 실행 결과를 회수할 수 있다.

## 채택한 결론

새 Codex 앱 세션에서도 설치된 스킬과 runtime으로 Pro·Claude·DeepSeek를 사용하고 브라우저를 조작할 수 있었다. 기존 시험에서 미확인이던 새 세션의 실사용 경로를 확인한 것이다. 모든 채널로 한 제품 변경을 끝까지 완수했다거나 계정 교체 후까지 검증했다는 뜻은 아니다.

코드 수정은 필요하지 않았다. Claude의 `origin/main`은 로컬에 오래된 값이 남을 수 있으므로 실제 원격 SHA와 구분하는 지침을 반영한다. Cloud 제한은 유지한다. 시험 전후 HEAD·Git 상태와 STATUS/COORDINATOR_STATE/AGENTS/설정/worker 스크립트 해시가 동일했다.
