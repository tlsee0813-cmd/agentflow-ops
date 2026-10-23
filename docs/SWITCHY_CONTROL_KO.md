# Switchy 기존 제어 API 검토 기록

2026-10-23 · **이 버전은 상시 사용 보류, 프로세스와 listener 중지 완료.** 아래는 준비 과정에서 확인한 원래 제어 기능의 기록이며 재실행 안내가 아니다. 별도 실행기나 MCP server를 만들지 않았다. 실제 현재 상태는 [STATUS](STATUS.md), 계정 방식 선택은 [ACCOUNT_DECISION_KO](ACCOUNT_DECISION_KO.md)를 본다.

## 준비된 실행 환경

- 실행 파일: %LOCALAPPDATA%/AgentFlowOps/tools/Switchy-1.0.39/switchy.exe
- 시작 방식: 원래 --autostart 옵션으로 숨겨진 main WebView와 tray 유지.
- 제어 주소: http://127.0.0.1:15721
- 데이터: %USERPROFILE%/.switchy — 자격증명이 포함되므로 공개 저장소에 올리지 않는다.
- 기존 설정 보관: %LOCALAPPDATA%/AgentFlowOps/backups/switchy-before-first-run
- 제품 등록을 동반하는 전역 설치 대신 원본 MSI의 관리 추출로 실행 파일을 배치했다.

처음 실행하면 Switchy가 두 PowerShell profile에 자신의 loader를 넣는다. 실행 종료 후 생성된 loader만 있는 두 파일을 보관 폴더로 이동해 원래 파일이 없던 상태를 복원했다. 첫 실행 전에는 해당 profile 파일이 없었고, 실행하며 새로 만들어졌다. 현재는 원래 부재 상태다. Codex config와 기존 auth 파일은 준비 과정 전후 동일함을 확인했다. 이 loader 변경을 설정 변경이 전혀 없는 설치로 설명하지 않는다.

## 조회

~~~powershell
Invoke-RestMethod -Uri 'http://127.0.0.1:15721/switchy/commands'
Invoke-RestMethod -Uri 'http://127.0.0.1:15721/switchy/accounts'
~~~

실제 명령 195개를 확인했다. commands는 명령 이름·인수 정의다. accounts는 pool의 현재 선택·순서·quota를 돌려준다. 업무용 이름이나 계정 메타데이터가 있을 수 있으므로 응답 전체를 공개 증거로 복사하지 않는다.

개별 명령은 원래 /switchy/invoke를 사용한다.

~~~powershell
$body = @{command='get_account_pool_config';args=@{}} |
  ConvertTo-Json -Depth 10 -Compress
Invoke-RestMethod -Uri 'http://127.0.0.1:15721/switchy/invoke' -Method Post -ContentType 'application/json' -Body $body
~~~

get_settings, get_proxy_config_for_app(appType=codex), get_account_pool_config 등을 조회할 수 있다. get_providers 같은 응답에는 자격증명이 담길 수 있으므로 원문을 채팅·로그·GitHub에 출력하지 않는다. 필요한 boolean·개수만 추린다.

## 이미 수행한 준비

원래 import_default_config(app=codex)로 현재 로그인을 등록했다. 명령은 true만 반환했고 현재 auth/config 파일은 변경되지 않았다. 이 import는 provider가 이미 있으면 건너뛰므로 로그인 추가 명령으로 반복 사용하지 않는다.

자동 회전, 예열, Codex shared-session은 OFF로 설정했다. Codex routing, auto-failover, Windows 자동 시작은 OFF 상태를 확인했다. 프로필 loader는 설치됐지만 shared-session enabled marker는 없다.

실제 사용할 두 번째 계정 대신 이름이 'AgentFlow - Codex Account 2 (sign-in pending)'인 빈 Official 카드를 준비했다. 현재 provider가 있는 상태에서 add_provider를 호출했고, 현재 선택·auth/config가 그대로임을 확인했다. **빈 카드를 실제 연결 계정으로 세지 않는다.**

## 당시 확인한 두 번째 로그인 경로 — 보류 버전에서는 실행하지 않음

Switchy 1.0.39에는 Codex 전용 managed OAuth start/poll/finish API가 없다. auth_start_login/auth_poll_for_account는 GitHub Copilot 전용이므로 Codex 로그인에 잘못 호출하지 않는다.

원래 등록 경로는 다음과 같다.

1. 실제 사용자가 로그인할 준비가 된 시점에 추가 Official 카드를 선택한다.
2. 정상 codex login 절차로 다른 Codex 계정에 로그인한다.
3. Switchy watcher가 현재 카드에 로그인 정보를 저장한다.
4. 실제 연결 계정이 두 개가 됐는지 확인하고 두 계정 사이 전환·quota·같은 작업 이어가기를 비교한다.

이 절차는 live 로그인 변경을 수반한다. 준비만 해놓고 빈 카드를 자동 선택하거나 현재 auth를 비우지 않는다. 비밀번호·토큰을 채팅이나 GitHub로 받을 필요는 없다.

정확한 준비된 카드 ID는 agentflow-codex-account-2다. 실제 전환 명령은 /switchy/switch 또는 switch_provider이며 **입력 준비·조회와 구분되는 변경 작업**이다. 두 번째 정상 로그인이 없는 현재 상태에서는 호출하지 않았다.

## 당시 확인한 라우팅 부작용 — 활성화하지 않음

계정 교체가 실제로 확인된 후 필요한 라우팅/회전 옵션만 사용한다. 라우팅을 켜면 Switchy가 자동 시작을 등록하는 동작이 있으므로 초기 OFF 상태가 계속 유지된다고 가정하지 않는다. shared-session과 Refresh는 별도 기능이며, 창 Refresh의 강제 종료 경로를 일반 turn 경계 전환과 혼동하지 않는다.

## 접근 제한

명령 조회 /switchy/commands 및 명령 호출 /switchy/invoke는 loopback·Origin 없음 조건을 검사한다. 현재 검토 버전의 /switchy/accounts 및 /switchy/switch에는 같은 검사가 없다. router는 open CORS를 적용한다. 이 차이 때문에 상시 사용을 보류하고 프로세스·listener를 중지했다. 실제 브라우저 공격은 수행하지 않았다.

브라우저 작업 도구는 현재 Work 설정에서 비활성화돼 있다. 이 API 준비가 Chrome·Pro·Dify의 실제 화면 조작 성공을 뜻하지 않는다. 해당 도구 접근이 정상 허용되기 전 새 브라우저 경로로 우회하지 않는다.

## 원본 근거

- [제어 API](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/proxy/control.rs)
- [현재 설정 import](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/services/provider/live.rs)
- [계정 등록 watcher](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/proxy/codex_pool.rs)
