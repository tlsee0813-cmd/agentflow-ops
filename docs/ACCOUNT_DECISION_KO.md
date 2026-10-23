# 계정 도구 선택 근거

2026-10-23 · 실제 실행 상태는 [STATUS](STATUS.md)에 모은다.

판단 순서는 **계정 교체 품질 → 기존 작업 기능 유지 → 그에 필요한 기존 OSS 추가**다. 같은 노트북의 대화·브라우저 기억 유지는 사용자 확인 전제다.

## 실제 사용자 로그인 후 판정 수정

두 로그인은 같은 Business 워크스페이스의 서로 다른 사용자였다. 새 native 조회에서 email은 다르지만 snapshot account_id가 같았다. QuotaCrew는 이를 중복 등록으로 거부했고, 그 ID를 전환 검증에도 쓰므로 이 환경에서 보류한다. [실제 관찰과 원인](../results/quotacrew-business-identity-2026-10-23/RESULT.md)을 우선한다.

중복 제한만 제거하거나 같은 로그인을 반복시키지 않는다. 기존 Gaebabi codex-switch의 workspace+user subject 구분을 다음 후보로 확인한다. 아래 초기 준비 관찰은 역사적 기록이다.
## 실행 후 선택 수정

Switchy는 열린 세션 routing 기능이 목적에 가까워 실제 준비를 진행했다. 원본 실행 파일·제어 API·현재 로그인 import까지 작동했고, 기존 auth/config를 유지했다. 그러나 다음 이유로 **1.0.39의 상시 사용은 보류했다.**

- 원본 server는 전체 router에 open CORS를 적용한다. /switchy/commands와 /switchy/invoke에는 loopback·Origin 검사 함수가 있지만, /switchy/accounts와 /switchy/switch에는 같은 검사가 없다.
- 이 차이는 소스에서 확인한 접근 제한 누락이다. 실제 브라우저 공격을 실행한 것은 아니다. localhost listener라는 사실만으로 모든 제어 경로가 웹 페이지에서 차단된다고 설명할 수 없다.
- 정상 종료 신호가 전달된 뒤에도 이 환경에서 앱이 종료되지 않아, 자신이 시작한 Switchy 프로세스만 중지했다. listener가 사라진 것을 확인했다.
- 새로 생긴 PowerShell profile 두 개는 생성된 loader 한 줄뿐임을 확인해 보관 폴더로 이동하고, 원래 파일이 없던 상태를 복원했다.

임시 방화벽·새 인증 프록시·자체 fork를 붙여 이 도구를 먼저 살리지 않는다. 수정된 upstream 버전을 확인할 때 다시 비교할 수 있다.

## 현재 비교 대상

| 후보 | 도움되는 기존 기능 | 확인해야 할 차이 |
| --- | --- | --- |
| **QuotaCrew 0.3.0** | quota 감시·계정 적용/검증·같은 대화 재개. CLI와 독립 로그인 프로필 | 같은 Business workspace의 다른 사용자 혼동으로 보류. 실제 전환 미실행 |
| **Gaebabi codex-switch** | 기존 계정 적용·정상 종료 요청·대화 재개 | 자동 회전 정책 없음, 기본 active 대화 전체 선택 |
| Switchy 1.0.39 | 열린 Codex WS routing·turn 경계 회전 | 위 접근 제한 누락과 로컬 종료 관찰로 보류 |

QuotaCrew의 기존 CLI를 설치·초기화하고 빈 로그인 프로필 두 개와 doctor 관찰까지 준비했다. 이 준비 시점에는 실제 인증이 없었으며 이후 로그인 관찰은 위 최신 판정을 따른다. 새 watcher나 auth 교체 코드를 만들지 않는다. 계정 등록 과정이 현재 총괄의 live 로그인에 끼치는 영향도 전환 품질에 포함한다.

## 계속 적용할 기준

전환 요청 성공, 계정 identity 적용, 같은 작업 재개, 모델·도구 동등성을 서로 구분한다. 실제 현재 exec 계보는 packaged OpenAI.Codex Desktop의 자식이며 QuotaCrew의 자기 종료 방지 조건에 해당한다. 이 세션에서 전환을 호출하지 않는다. 버튼 표시나 프로세스 exit 0만으로 합격 처리하지 않는다.

QuotaCrew의 일반 대화 재개는 native goal이 없어도 확인된 usageLimitExceeded turn에서 가능하다. goal 조회 실패·사용자 중단·미지원 연결을 자동 재개 성공으로 확대하지 않는다. 여러 대화가 같은 계정에서 한도 중단되면 여러 대화가 대상이 될 수 있다.

Gaebabi의 --switch-account exit 0는 IPC 전달과 구분한다. 실제 새 plan·대상 계정·Finished·실패/불확실 항목과 대화 재개를 대조한다.

서로 다른 두 사용자 로그인은 진행했다. QuotaCrew 내부 binding이 두 번째를 거부한 문제와 실제 로그인 실패를 혼동하지 않는다. 적합한 기존 도구의 정상 등록·전환 경로는 아직 남아 있다. 비밀번호·토큰을 채팅이나 GitHub로 받지 않는다. 다른 관리자를 동시에 자동 활성화하지 않는다.

## 원본 근거

- [Switchy 제어 경로](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/proxy/control.rs)
- [Switchy router와 CORS](https://github.com/registered2nd/switchy/blob/fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a/src-tauri/src/proxy/server.rs)
- [QuotaCrew 계정 전환](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/auth/transaction.py)
- [QuotaCrew Windows 종료](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/platform/windows.py)
- [Gaebabi 정상 종료](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/platforms/client/DesktopShutdown.cs)

QuotaCrew CLI의 수동 switch에는 --thread로 대상을 지정하는 경로가 있지만 GUI 자동 감시의 재개 대상을 단일 총괄로 제한한다는 검증은 남아 있다. 현재 기본 CLI에는 watch/monitor 명령이 없고 기존 상시 감시는 GUI/트레이에서 시작한다. 자동화를 쓰려면 먼저 이 원본 경로와 실제 현재 버전의 재개를 확인해야 한다.