# Pro 작업 CLI

설치된 Oracle 0.22.0 MCP 도구를 mcporter 0.16.0으로 한 번씩 호출하는 얇은 입구다. 자체 큐·데몬·저장소는 없고 세션은 Oracle의 `ORACLE_HOME_DIR`에만 남는다. 저장소 루트에서 `pnpm install --ignore-scripts --frozen-lockfile` 후 사용한다.

~~~powershell
node scripts/pro-task.mjs submit requests/pro-review.json --dry-run   # consult, waitForCompletion:false 강제; 실제 sessionId 출력
node scripts/pro-task.mjs status <sessionId>                          # sessions {id}: 상태만
node scripts/pro-task.mjs result <sessionId>                          # sessions {id, detail:true}: 저장된 전체 log를 stdout으로
~~~

- 종료 코드: 0 completed/접수, 3 running, 4 partial, 5 error, 6 cancelled, 7 알 수 없는 상태, 1 호출 실패, 2 사용법 오류. partial/error/cancelled는 성공이 아니다.
- 한 번 실행에 자식 호출은 한 번이며 재시도하지 않는다. submit이 실패하거나 ID가 없으면 다시 보내지 말고 status 또는 Oracle `sessions` 목록을 먼저 확인한다.
- status/result는 질문 전송·재시작·브라우저 재연결을 하지 않는다. `oracle session <id>` attach는 Chrome 재연결과 상태 변경을 할 수 있어 쓰지 않는다.
- result는 wait의 4,000자 logTail이 아니라 세션 전체 log(답변과 진행 줄 포함)다. running이면 아무것도 출력하지 않는다. 0.22.0 설치본에는 response.md가 없다.
- 요청 JSON의 `files`는 저장소 루트 기준이다. 저장된 log가 불완전할 때만 사람이 판단해 `pnpm exec oracle session <id> --harvest --no-recover`를 별도로 실행한다.
