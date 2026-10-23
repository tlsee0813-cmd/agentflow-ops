# 계정 도구 비교와 우선 확인 순서

2026-10-23 · 실제 로컬 전환 전의 소스 비교다. 기준은 계정 교체의 부드러움과 기존 작업 기능 유지다. 기억 이전은 선행 작업이 아니다.

| 후보 | 가장 도움이 되는 점 | 현재 확인한 비용·제한 | 위치 |
| --- | --- | --- | --- |
| **Switchy 1.0.39** | 열린 Codex 연결의 실제 사용 계정을 turn 경계에서 바꾸는 routing | 로컬 프록시와 PowerShell profile loader를 설치. 계정 선택과 실제 WS 전환 사이 지연·재시도 한계 있음 | CLI 허용 조건에서 먼저 비교할 자동 회전 후보 |
| **QuotaCrew 0.3.0** | 사용량 감시→계정 적용/검증→같은 대화 재개가 이미 있음 | Windows Codex 앱 강제 종료, file 인증 저장소 변경. 여러 한도 중단 대화가 대상일 수 있음 | Desktop 자동 재개 대안 |
| **Gaebabi codex-switch** | 기존 계정 적용·정상 종료 요청·대화 재개 | 자동 회전 정책 없음, active 대화 전체 선택 | 부드러운 정상 종료의 기준·수동 전환 대안 |

## 판단

CLI도 괜찮다는 사용자 조건에서는 **Switchy의 기존 routing 경로를 첫 비교 대상으로 둔다.** 요청을 수행하는 계정이 바뀌어도 총괄 프로세스와 도구 연결을 유지하는 구조가 목적에 가장 가깝다. 프록시라는 구현 방식만으로 기각하지 않는다.

다만 최신 Switchy를 그대로 쓰면 Windows PowerShell profile 두 곳에 loader를 기록한다. 공유 세션 옵션을 꺼도 설치 코드가 먼저 실행된다. 따라서 설정 변경이 없는 도구로 소개하지 않는다. 프로필 변경을 피하는 자체 우회 런처도 만들지 않는다.

Switchy의 모델·툴·이미지 요청은 원문 프레임/HTTP body를 전달하는 경로가 있으나, 실제 Codex 앱·CLI에서 모든 기능이 동등하다는 관찰은 아직 없다. 원래 로그인·표시 계정과 실제 요청을 처리한 계정을 구분해야 한다. UI의 계정명 변경만을 성공으로 보거나, UI가 옛 계정이라고 실제 routing도 옛 계정이라 단정하지 않는다. 사용 모델·quota 동작·툴 연결을 함께 확인한다.

같은 노트북의 대화 기억은 사용자 확인 전제로 두고, 실제 계정 교체가 일어나도 Pro/Claude/Cloud/GitHub 작업과 화면 조작을 유지하는지를 본다. 이 관문을 통과하기 전 계정 관리 도구를 기본 자동 실행으로 켜지 않는다.

## 코드에서 확인한 전환 방식

Switchy의 일반 계정 회전은 turn이 없는 시점의 WS 종료이며 Codex 프로세스 종료가 아니다. 첫 실질 응답 전달 전의 429는 다른 계정 replay가 가능하고, 이미 실질 응답을 전달했으면 replay하지 않는다. 증분 turn은 잘못된 이전 응답 ID를 다른 계정에 재사용하기보다 Codex의 전체 재전송을 유도한다. 계정 선택 검사는 3초 idle tick이므로 버튼 클릭 직후 다음 요청이 반드시 새 계정이라는 보장은 없다. HTTP 연결 장애의 같은 계정 재시도도 있어 exactly-once로 설명하지 않는다.

Switchy의 별도 /status 동기화·Refresh 경로에는 taskkill /T /F가 있다. 일반 routing 전환과 구분하지만 도구 전체에 강제 종료가 전혀 없다고 말하지 않는다. Windows/WSL Codex 0.163.0 사용은 제작자 보고이며 이 노트북의 독립 검증이 아니다.

QuotaCrew는 shared auth 적용 후 계정 ID를 검증하고 Desktop을 재실행한다. 설정은 인증 저장소를 file로 바꾸며 다른 텍스트 설정·history/skills/plugins는 보존하는 코드다. 같은 대화 재개는 native goal이 없어도 확인된 usageLimitExceeded turn에서 가능하다. goal 조회 실패·사용자 중단·미지원 연결을 자동 재개 성공으로 확대하지 않는다. 여러 대화가 같은 계정에서 한도 중단되면 여러 대화가 대상이 될 수 있다.

Gaebabi는 Restart Manager로 정상 종료를 요청한다. --switch-account의 exit 0는 IPC 전달과 구분하고 실제 새 plan·적용 계정·Finished·불확실/실패 항목·대화 재개를 확인해야 한다.

## 실사용 확인 순서

1. 현재 총괄이 전송·커밋 중이지 않은 지점에서, 원본 도구가 바꾸는 설정과 복구 경로를 확인한다.
2. 새 사용 계정이 실제 반영됐는지, 같은 대화와 모델·도구가 이어지는지 확인한다.
3. 기존 GitHub 읽기·쓰기, Pro 기존 답변 회수, Claude 작업, Cloud 상태, 화면 관찰·조작을 대조한다.
4. 정상 turn 경계의 계정 변경과 한도 중단 후의 자동 전환을 구분해 기록한다.
5. 불필요한 자동 warm-up·shutdown·Refresh를 함께 켜지 않고 필요한 기능만 사용한다.

현재는 설치·로그인·실제 계정 전환을 수행하지 않았다. 사용자 계정 관리자를 여러 개 동시에 활성화하지 않는다.

## 근거

- [Switchy release / 정확한 source](https://github.com/registered2nd/switchy/tree/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a)
- [Switchy WS routing](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/proxy/codex_ws.rs)
- [Switchy PowerShell 설치·세션 엔진](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/proxy/codex_engine.rs)
- [QuotaCrew Windows 종료·재시작](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/platform/windows.py)
- [QuotaCrew 설정 적용](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/adapters/credential_store.py)
- [Gaebabi 정상 종료](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/platforms/client/DesktopShutdown.cs)
