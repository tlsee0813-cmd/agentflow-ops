# Pro 작업 CLI

submit은 설치된 Oracle 0.22.0 원본 CLI를 foreground --wait로 실행한다. ORACLE_NO_DETACH=1로 worker 분리를 끄고 stdout/stderr 진행 출력과 실제 sessionId 안내를 즉시 전달한다. 호출 프로세스는 완료까지 유지해야 한다. Codex exec_command가 실행 중 session_id를 반환하면 해당 실행을 유지한 채 다른 작업을 진행할 수 있다. 자체 큐·데몬·재시도는 없다.

~~~powershell
node scripts/pro-task.mjs submit requests/my-request.json --dry-run
node scripts/pro-task.mjs submit requests/my-request.json
node scripts/pro-task.mjs status SESSION_ID
New-Item -ItemType Directory -Force .ops/results | Out-Null
node scripts/pro-task.mjs result SESSION_ID > .ops/results/SESSION_ID.log
$LASTEXITCODE
~~~

요청 JSON 허용 필드는 prompt, engine(browser만), model(기본 gpt-6-pro), files, slug, dryRun, browserArchive, browserAttachments, browserThinkingTime, browserKeepBrowser, browserManualLoginProfileDir뿐이다. 알 수 없는 필드와 이전 MCP용 waitForCompletion은 오류로 거부한다. files는 저장소 루트 기준이다. 기본 수동 로그인 프로필은 .ops/oracle-browser-profile이며 경로를 명시적으로 원본 CLI에 전달한다. 로그인 방식은 저장소 Oracle 설정을 따른다.

작업 JSON 자체는 `.ops`에 두어도 되지만 `files`의 첨부 경로는 다르다. Oracle 파일 수집은 `.gitignore`를 존중하므로 `.ops` 안의 파일은 실제로 존재해도 첨부되지 않는다. 추적되는 공개 파일을 첨부하거나 짧은 공개 자료를 prompt에 포함한다. 비공개 파일의 ignore 규칙을 풀어 첨부하지 않는다. 요청 준비 후 dry-run으로 파일 수집을 확인할 수 있다.

~~~json
{"prompt":"Review the requested public code","model":"gpt-6-pro","browserThinkingTime":"pro","browserArchive":"never","browserAttachments":"always","browserKeepBrowser":true,"files":["docs/DESIGN_KO.md"]}
~~~

submit --dry-run은 원본 CLI 미리보기이며 세션·질문을 생성하지 않는다. 실제 submit은 원본 출력 형식을 유지하고 원본 CLI가 정상 종료하면 0, 실패하면 1을 반환한다. 실패 또는 출력 중단 시 다시 전송하지 말고 기존 sessionId나 Oracle sessions 목록을 확인한다. 프롬프트는 native CLI argv에 전달되므로 이 경로의 요청에는 공개 자료만 사용한다.

status/result만 mcporter 0.16.0을 통해 Oracle MCP sessions를 읽는다. 질문 전송·재시작·브라우저 재연결을 하지 않는다. 종료 코드는 0 completed, 3 running/pending/queued, 4 partial, 5 error/failed, 6 cancelled, 7 알 수 없는 상태, 1 호출 실패, 2 사용법 오류다. partial/error/cancelled는 성공이 아니다.

result는 wait의 4,000자 logTail이 아니라 저장된 전체 log(답변과 진행 줄 포함)를 원문 그대로 stdout에 쓴다. running이면 결과를 출력하지 않는다. 상태 메타데이터는 stderr에 쓴다. 원본 session attach는 상태나 브라우저에 영향을 줄 수 있으므로 이 조회 경로에서 사용하지 않는다.
