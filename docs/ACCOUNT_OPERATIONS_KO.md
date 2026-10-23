# 계정 전환 운영

현재 실행 결과는 [STATUS](STATUS.md)를 먼저 읽는다. 비밀번호를 문서에 적는 방식 대신 이미 로그인한 인증을 원본 전환기의 Windows 사용자 DPAPI vault에 보관한다. 실제 계정 정보와 vault는 GitHub에 넣지 않는다.

2026-10-24 현재: 우선순위·같은 대화 재개 로직을 보완했지만 **자동 실행은 꺼져 있다**. 잠깐 대기 감시를 실행한 결과 현재 Work 총괄의 monitor는 active인데 native 최신 턴은 interrupted여서 대상을 일관되게 관찰하지 못했다. 계정 교체 없이 감시를 중지했고 private config는 enabled=false, 예약 작업은 Ready·시작 트리거 0개다. 실제 전환·한도 실패 자동 재개는 아직 검증하지 않았다.

사용자가 정한 순서는 Business 두 사용자 → Plus·보유 크레딧 → Pro 비상용이다. 현재 사용 가능한 Pro는 최초 한도 소진까지 유지하고, 정책이 시작된 후에는 Business의 실제 회복을 확인해 안전 경계에 복귀한다. vault 네 역할 매핑 및 캐시 한도 데이터는 확인했다. 아래 세 항목 가져오기는 최초 준비 당시 기록이다.

## 새 Codex 총괄에 연결할 때만 필요한 설정

외부 워커·Oracle·DSH 연결 시험은 다시 할 필요 없다. 계정 감시는 대화 UUID에 묶이므로 새 총괄에서 아래 좁은 연결을 한 번 수행한다.

1. 새 세션이 Codex 앱의 로컬 Codex 총괄인지 확인하고 실제 thread UUID를 얻는다. 원래 Work 총괄이나 이번 Ops 대화의 UUID를 그대로 복사하지 않는다.
2. 기존 private config `.ops/account-priority/current-test/config.json`은 네 역할의 원본 Key와 설치 경로를 보관한다. 값을 출력하지 않고 새 `.ops/account-priority/<thread UUID>/config.json`으로 필요한 설정만 옮기며 threadId를 바꾼다. 기존 ledger를 복사하거나 transition/resume claim을 지우지 않는다. 사용자 전용 ACL을 유지한다.
3. 원본 native monitor의 active/idle과 `thread/turns/list(limit=1, sortDirection=desc, itemsView=notLoaded)`의 현재 턴이 일치하는지 읽기 전용으로 확인한다. 특히 실제 진행 중 턴이 inProgress로 관찰돼야 실패 계정 귀속을 검증할 수 있다. 불일치 시 `target_turn_not_observable`로 보류한다. 지원하지 않는 API를 다른 경로로 우회하지 않는다.
4. config를 enabled=true로 정한 뒤 `run-account-priority.ps1 -ConfigPath ... -CheckOnly`를 실행한다. 이 모드는 전환·재개·ledger 쓰기를 하지 않는다. 상태가 `disabled`일 때는 연결 확인 성공으로 세지 않는다.
5. 기존 예약 작업을 조회해 Ready/중지 상태와 전환 중인 기록이 없음을 확인한다. 기존 실행기와 원본 프로그램의 미해결 전환이 있으면 먼저 원본 receipt로 확인한다. 같은 사용자 task가 이전 config를 가리키면 중지된 그 task만 제거한 뒤 새 config로 `start-account-priority.ps1 -ConfigPath ...`를 명시적으로 실행한다. launcher는 다른 config의 task를 자동 덮어쓰지 않는다.
6. Running 상태, 해당 UUID의 관찰 기록, fresh 상태를 확인한다. 최초 실제 한도 사건 후 원본 전환 receipt·계정 일치·같은 UUID·설정 해시·새 턴 접수까지 확인해야 전환+재개 성공이다. 대기 감시 기동만으로 이를 통과 처리하지 않는다.

launcher는 Windows Task Scheduler의 현재 사용자 Interactive/Limited 작업으로 Codex 앱 재시작과 독립시킨다. 로그인/재부팅 자동 시작 트리거는 만들지 않는다. 중지는 같은 사용자의 `AgentFlow-AccountPriority-*` task에 Stop-ScheduledTask를 적용하고 private config.enabled=false로 설정한다. 이 작업은 브라우저 로그인이나 원본 vault를 변경하지 않는다. 상태 JSON은 마지막 관찰일 수 있으므로 실제 task 상태·시각과 함께 읽는다.

## 실행기에서 보완한 것

- 최초 소진 전 현재 Pro 유지; 이후 Business 우선과 Plus 크레딧·Pro 비상 순서.
- 원본 active 턴/계정 관찰을 고정하고, 사용자가 중간에 계정을 바꾸면 실패를 새 계정에 잘못 귀속하지 않는다.
- 확정 실패는 계정별로 남긴다. 오래된 정상 quota나 단순 시간 경과로 실패를 없애지 않는다. 서로 다른 bucket·window를 섞어 회복으로 오판하지 않는다.
- 전환 및 Resume 전 claim을 저장하고 불명확한 결과에 재전송하지 않는다. 실제 새 사용자 턴이 확인되면 미확인 Resume를 중복 실행하지 않고 정리한다.
- monitor 메타데이터가 부족하면 최신 턴 하나만 읽는다. 대화 전체를 반복해서 모델 문맥에 넣지 않는다. 대상 상태 불일치나 API 미지원은 전환을 막는다.
- native 원본 전환 엔진·ResumeAsync를 사용한다. 실패 대화의 설정 해시와 계정·UUID를 대조한다. 마지막 idle 확인 직후 외부에서 새 작업이 시작되는 경쟁 가능성은 남아 있어 완전한 무중단을 보장하지 않는다.

[검증·활성화 상태 기록](../results/account-priority-2026-10-24/RESULT.md). 원본 엔진·빌드 정보와 수동 전환 절차는 아래에 이어진다.

## 준비된 원본

Gaebabi Codex Switch 1.41.1 portable을 사용한다. release tag는 bfd96517e08d9e697c201ae7dc11588e12763c51, 배포 binary build source는 98af9e4687d26bcc14198d8adc71922f0ca46d89다. workspace account ID와 JWT 사용자 sub를 함께 식별하므로 같은 Business workspace의 두 사용자를 구분한다. EXE와 전환 엔진을 수정하지 않았다.

세 등록 항목의 표시명은 primary, secondary, current다. 앞의 둘은 추가한 Business 사용자이고 current는 원래 Codex 디스크 로그인을 보존한 항목이다. 별칭은 표시명이며 실제 선택은 원본의 복합 Key로 한다.

사용자는 시작 메뉴의 **AgentFlow Accounts**로 원본 GUI를 열 수 있다. 명령 호출은 원래 옵션을 사용한다.

~~~powershell
& $nativeExecutable --data-dir $physicalDataDirectory --codex-home $codexHome --switch-account ACTUAL_ACCOUNT_KEY
~~~

Windows 원본 CLI는 이메일 또는 Key를 받으며 primary/secondary 같은 별칭으로 선택하지 않는다. 실제 값은 비공개 로컬 원본 vault에서 확인한다. 예시의 문자열을 그대로 전송하지 않는다. exit 0는 기존 창에 요청을 전달한 것일 수 있어 실제 완료를 뜻하지 않는다.

## MSIX 경로와 독립 실행

패키지 앱 안의 LOCALAPPDATA 논리 경로는 외부 프로세스에서 같은 폴더를 가리키지 않을 수 있다. 이번에는 외부에서 logical EXE/data 경로가 보이지 않아 실패했고, 실제 package LocalCache 물리 경로로 원본을 실행해 해결했다.

설치 경로를 추측해서 복사·재설치하지 않는다. 로컬 .ops/native-manager-launch.json의 NativeExecutablePath, DataDirectoryPath, CodexHomePath가 이번에 확인한 값이다. 공개 저장소에는 개인 절대 경로 대신 이 절차만 남긴다. 시작 메뉴 바로가기도 실제 물리 경로를 사용한다.

현재 utility는 Codex의 자식이 아닌 독립 프로세스로 실행했다. 일회성 Windows 예약 작업은 실행 후 삭제했으며 반복 작업·시작 프로그램 등록을 추가하지 않았다. Windows 원본 DPAPI vault는 directory entropy를 쓰지 않으므로 같은 사용자의 동일 물리 파일을 두 경로에서 읽을 수 있다. 이는 임의 사용자의 복호화를 허용한다는 뜻이 아니다.

## 실제 교체와 복귀 확인

1. 원본 DesktopSessionMonitor가 보는 active root 집합에 현재 CODEX_THREAD_ID만 포함되는지 새로 확인한다. 원본 전환기는 active root 전체를 포착하며 UUID allowlist 옵션은 없다.
2. 원본 credential backend 검사, 선택할 프로필의 identity·사용량을 확인한다. 작업·커밋·외부 전송 기준을 저장한 뒤 원본 CLI에 정확한 Key로 전환 요청을 한 번 보낸다.
3. 원본은 채팅 이름 백업, Desktop 정상 종료, 인증 적용, 앱 실행, 같은 thread 재개를 수행한다. 사용자 입력이 필요하면 미확인으로 남기며 강제 종료·새 대화 대체로 성공을 꾸미지 않는다.
4. 재개 후 원본 PendingSwitch와 last-switch 기록을 읽어 대상 Key·현재 canonical Key·같은 thread UUID·실제 재개 상태를 대조한다. 전체 원문에는 개인 대화와 이름이 있어 공개하지 않는다.
5. 같은 작업 폴더·모델/도구 설정, GitHub 접근과 기존 외부 작업 회수를 별도로 확인한다. 단순 요청 전달·auth 파일 교체·채팅 열기만으로 전체 합격을 표시하지 않는다.

원본 Windows GUI는 수동 전환과 적격 대화 자동 재개를 제공한다. 한도 소진 시 자동 계정 선택·회전 정책이 이미 설정됐다는 뜻은 아니다.

## 한 번 사용한 가져오기 어댑터

[가져오기 결과](../results/codex-switch-import-2026-10-23/RESULT.md)의 세 스크립트는 Q 원본 credential reader와 G 원본 parser/vault API를 연결하는 **버전 고정 내부 API용 일회성 어댑터**다. upstream의 공식 import CLI라고 표현하지 않는다. 새 암호화·JWT 파서·auth writer·watcher·전환 엔진을 만들지 않았다.

실제 가져오기는 새 pwsh -NoProfile 프로세스에서 관리자를 모두 종료한 상태로 수행했다. 초기 process 확인과 원본 mutex는 보조 장치이며, 다른 경로 별칭으로 import 도중 관리자를 새로 실행하는 경쟁까지 전역으로 막는다고 표현하지 않는다. 현재 관리자가 켜져 있으면 live wrapper는 인증을 읽기 전에 거부한다.

현재 canonical과 같은 Key에는 기존 canonical 자격을 우선한다. canonical이 두 Business 사용자 밖이면 세 번째 항목으로 보존한다. 기존 같은 Key에 다른 auth가 있거나 PendingSwitch가 있으면 전체 저장 전에 거부한다. 새 로그인·갱신을 위해 이 어댑터를 반복 실행하지 않는다. 이후 관리는 원본 GUI가 담당한다.

버전 또는 DLL이 바뀌면 그대로 실행하지 않는다. 원본 parser·vault·암호화 코드와 hash/API를 다시 확인한 뒤 필요한 최소 부분만 갱신한다. 사용자 비밀번호·토큰은 채팅이나 GitHub로 받지 않는다.
