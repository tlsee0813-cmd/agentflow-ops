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

현재 원본은 Codex Switch 1.41.1이다. 사용자 시작 메뉴의 AgentFlow Accounts를 사용한다. 실제 경로·같은 workspace 사용자 구분·native CLI·완료 판정은 [계정 운영](ACCOUNT_OPERATIONS_KO.md)을 먼저 읽는다.

두 Business 사용자와 기존 canonical 로그인의 원본 DPAPI vault 보관, 독립 실행, 실제 quota 조회까지 완료했다. 계정 전환·같은 thread 재개·도구 동등성은 별도 관문이다. `--switch-account`의 인수는 실제 Key 또는 이메일이며 표시 별칭이 아니다. 단순 exit 0는 요청 전달일 수 있다.

가져오기 스크립트는 버전 고정 내부 API를 연결한 일회성 준비다. G가 실행 중인 채로 재실행하지 않으며, 정상 계정 관리·새 로그인·갱신은 원본 UI를 사용한다. 다른 전환 관리자와 자동 회전을 동시에 켜지 않는다.

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
