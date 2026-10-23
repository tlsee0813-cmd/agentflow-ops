# 계정 전환 운영

현재 실행 결과는 [STATUS](STATUS.md)를 먼저 읽는다. 비밀번호를 문서에 적는 방식 대신 이미 로그인한 인증을 원본 전환기의 Windows 사용자 DPAPI vault에 보관한다. 실제 계정 정보와 vault는 GitHub에 넣지 않는다.

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
