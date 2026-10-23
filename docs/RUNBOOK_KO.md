# AI용 실행 안내

저장소 루트에서 기존 CLI/MCP를 직접 사용한다. 별도 자체 실행기는 없다.

## 설치와 도구 조회

~~~powershell
pnpm install --ignore-scripts --frozen-lockfile
pnpm exec mcporter list oracle --schema --config config/mcporter.json
~~~

Node 24 이상이 필요하다. config/mcporter.json의 cwd는 설정 파일 디렉토리 기준 '..'로 저장소 루트를 가리킨다. command와 args를 나누고 Node가 패키지의 원래 MCP entrypoint를 실행한다. 절대 사용자 경로를 저장소에 넣지 않았다.

Oracle 프로젝트 설정은 .oracle/config.json에 있다. browser engine, 기존 Chrome 연결, manualLogin=false, cookieSync=false, archive=never를 지정한다. Windows 기본 manual-login 프로필을 새로 만드는 경로를 선택하지 않는다. 외부 환경의 ORACLE_BROWSER_PROFILE_DIR가 설정돼 있으면 프로필 선택이 달라질 수 있으므로 실행 환경을 확인한다.

## 모델 비연결 요청 확인

~~~powershell
Get-Content -LiteralPath requests/pro-review.json -Raw -Encoding utf8 |
  pnpm exec mcporter call oracle.consult --args - --output json --config config/mcporter.json
~~~

예시 파일은 dryRun=true다. 실제 MCP 호출은 하지만 모델에 질문하거나 브라우저를 만지지 않는다. 입력 자료·모델·기존 브라우저 연결 여부를 확인한다. 실제 작업을 배정할 때 목적·GitHub 기준 SHA·관련 파일·대표 화면·완료 조건을 채운다.

## Pro 질문·회수

기존 Chrome의 DevTools 연결이 허용된 환경에서 dryRun=false로 바꾼 작업 요청을 consult에 전달한다. 모델과 effort를 명시하고 waitForCompletion=false로 별도 worker를 시작한다. **반환된 실제 sessionId를 작업 문서에 기록한다.**

~~~powershell
pnpm exec mcporter call oracle.wait id=ACTUAL_SESSION_ID timeoutMs=60000 --timeout 75000 --output json --config config/mcporter.json
pnpm exec mcporter call oracle.sessions id=ACTUAL_SESSION_ID detail=true --output json --config config/mcporter.json
~~~

한 번의 wait가 시간 제한에 닿아도 worker를 취소하지 않는다. 같은 ID로 다시 기다린다. 바깥 mcporter 제한을 Oracle의 대기 시간보다 길게 둔다. 출력에는 계정·대화 내용이 섞일 수 있으므로 원본 전체를 공개 커밋하지 않는다.

원래 Oracle CLI의 회수·followup도 사용할 수 있다.

~~~powershell
pnpm exec oracle status --hours 72
pnpm exec oracle session ACTUAL_SESSION_ID
pnpm exec oracle session ACTUAL_SESSION_ID --harvest
pnpm exec oracle --followup ACTUAL_SESSION_ID -p "이 제약을 추가해서 검토해 줘" --file docs/DESIGN_KO.md
~~~

custom slug는 3~5단어이고 충돌 시 접미사가 붙을 수 있다. 요청한 이름을 실제 sessionId로 단정하지 않는다. followup은 부모 브라우저 설정과 대화 URL을 상속한다. restart는 새 전송이므로 회수 대용으로 쓰지 않는다.

## 계정 교체

Switchy 1.0.39는 접근 제한 누락을 확인해 보류하고 중지했다. [보류 근거](ACCOUNT_DECISION_KO.md)와 [STATUS](STATUS.md)를 먼저 읽는다. 현재 원본 QuotaCrew 0.3.0 기본 CLI를 Python 3.12.14 venv에 설치했다. [CLI 준비 안내](QUOTACREW_CLI_KO.md)를 따른다. 원본 init·빈 프로필 두 개·doctor 관찰까지 완료했다. GUI·실제 로그인·전환·자동 감시는 실행하지 않았다.

원본 profile add → profile login은 도구 소유 CODEX_HOME에 정상 로그인한다. main auth를 가져오는 CLI는 확인되지 않았다. Windows 실제 전환은 Desktop 강제 종료와 재시작을 포함할 수 있고, packaged Desktop의 자식에서 실행하면 전환을 거부한다. CLI 설치만으로 무중단 전환이나 상시 자동 감시가 준비됐다고 판단하지 않는다.

기존 계정 관리자와 동시에 자동 전환을 켜지 않는다. QuotaCrew에서 설치된 Codex와 지정 대화의 지원 상태를 확인하고, 전환 전후 실제 계정·같은 대화·재개된 작업·외부 작업 링크·GitHub 접근을 대조한다. 그 다음 upstream의 감시·자동 전환·continuation 설정을 사용한다. 자동 재개가 지원되지 않는 연결은 미지원으로 남기며 다른 세션으로 몰래 대체하지 않는다.

[비교 관문](COMPARISON_KO.md)을 사용하고, 실제 결과는 STATUS와 결과 문서에 기록한다. 기존 총괄이 커밋·전송 중인 순간에 이 실행 프로세스가 자기 계정을 바꾸는 방식으로 점검하지 않는다.

## 화면과 이미지

현재 브라우저 도구를 먼저 쓴다. Oracle는 파일·이미지를 모델에 첨부할 수 있지만 Dify를 직접 조작한 결과를 대신하지 않는다. 화면을 실제로 보고 클릭·입력·캔버스 이동을 확인한다.

config/mcp-servers.example.json은 Oracle와 Chrome DevTools MCP를 native MCP host에 등록할 때의 참고 형태다. REPO_ROOT를 실제 설치 경로로 바꿔 사용한다. 현재 mcporter의 기존 Chrome 정책에서 해당 경유 정의가 거절됐으므로 기본 mcporter 구성에는 Oracle만 있다. 정책을 끄거나 자동 재시도하지 않는다.

Chrome DevTools MCP는 원본의 --autoConnect와 --experimentalVision 설정을 참고한다. 기존 Chrome 연결 승인과 소유권을 확인한 뒤에만 사용하며, Oracle가 사용하는 탭을 동시에 조작하지 않는다. 이미지 파일을 모델에 붙이는 것과 총괄이 스크린샷을 실제로 보는 것을 구분한다.

## Cloud·Claude·DSH

현재 Codex CLI에서 확인한 원래 명령:

~~~text
codex cloud list --json --limit 5
codex cloud exec --env ENV_ID --branch BRANCH --attempts 1 "범위와 완료 조건이 있는 작업"
codex cloud status TASK_ID
codex cloud diff TASK_ID --attempt 1
~~~

list 이외의 JSON 출력을 가정하지 않는다. 실제 환경 ID·기준 브랜치·반환 task ID를 확인하고 새 작업 하나의 결과 회수부터 연결한다. 패치를 자동 apply하지 않는다.

Claude는 기존 사용 환경에 주제별로 배정한다. 이 노트북에서는 CLI가 확인되지 않았으므로 검증되지 않은 명령을 구성에 넣지 않았다. Oracle의 Anthropic API 지원을 기존 Claude 크레딧과 같은 경로로 가정하지 않는다.

DSH는 이후 좁은 처리 작업 하나에 upstream headless 스크립트를 붙인다. exit code와 실제 final·산출물을 함께 확인하고, 예제 provider 설정을 사용자의 실제 결제·자격증명 경로로 오인하지 않는다.

## GitHub 결과

results/<작업ID>/RESULT.md에 목적·기준 SHA·실제 session/task ID·결과·접근 가능한 증거·미실행·총괄 판단을 남긴다. 로컬 경로와 해시만 남긴 화면 증거는 다른 세션이 회수할 수 없으므로 공유 증거로 보지 않는다.
