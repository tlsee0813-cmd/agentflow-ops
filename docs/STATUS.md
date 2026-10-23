# 현재 상태

**2026-10-23 · 두 사용자 로그인 후 QuotaCrew의 같은 Business 워크스페이스 구분 문제를 확인했다. 실제 전환은 미실행이며 QuotaCrew 0.3.0을 보류한다.**

## 최신 관찰과 판단

- 사용자가 서로 다른 두 사용자로 정상 로그인했다. 각 프로필의 새 native 조회에서 account_id는 같고 email은 달랐다. 계정 원문은 출력하지 않았다.
- primary는 auth/binding이 모두 있다. secondary는 auth는 있으나 QuotaCrew의 중복 account_id 제한으로 binding이 완료되지 않았다.
- 초기 중복 오류만 보고 사용자가 같은 계정을 골랐다고 단정한 것은 잘못이었다. 같은 Business 워크스페이스의 사용자 구분 문제다. 추가 로그인 반복을 요청하지 않는다.
- QuotaCrew는 이 ID를 활성 계정과 전환 검증에도 쓰므로 DB 중복 제한만 풀지 않는다. 실제 전환 후보로 보류했다.
- 기존 후보 Gaebabi codex-switch의 workspace+user subject 구분 구조와 원래 등록/전환 경로를 확인하고 있다. 아직 설치·전환 성공으로 기록하지 않는다.
- Switchy 1.0.39는 제어 경로 검토 후 중지·보류 상태를 유지한다. 신규 PowerShell profile은 원래 부재 상태로 복원했다.
- 어느 도구에서도 자동 회전·감시나 실제 main 계정 전환을 수행하지 않았다. 기존 총괄은 계속 동작 중이다.

[Business 사용자 구분 관찰](../results/quotacrew-business-identity-2026-10-23/RESULT.md) · [계정 채택 판단](ACCOUNT_DECISION_KO.md) · [이전 QuotaCrew 준비 영수증](../results/quotacrew-preparation-2026-10-23/RESULT.md) · [Switchy 준비/보류](../results/switchy-preparation-2026-10-23/RESULT.md)

## 남은 실제 관문

같은 워크스페이스의 다른 사용자를 정확히 등록·선택·검증하는 기존 도구를 사용해야 한다. 소스의 identity 구분, 실제 등록, 실제 전환, 같은 총괄 재개, 모델·도구 유지 결과를 따로 확인한다.

현재 exec는 packaged Codex Desktop의 자식이다. Desktop 종료가 포함된 도구를 이 총괄의 자식에서 자기 전환하는 방식으로 실행하지 않는다. 소스 보호 조건을 우회하지 않는다. 두 프로필의 인증은 로컬 도구 저장소에 비공개로 남기며 임의 auth writer나 DB 수정으로 옮기지 않는다.

## 브라우저 접근 제한

기존 브라우저 도구가 다음을 반환했다.

> Browsers: Error: Local browser use is disabled in Work settings

Work 로컬 브라우저 기능의 비활성화 진단이다. 개인 설정인지 관리 정책인지는 현재 도구로 구분할 수 없다. 앱의 Browser 허용 상태를 수동으로 확인해야 하는 지점이다. 같은 동작을 다른 도구로 우회하지 않았다.

별도 읽기 진단에서 Chrome 155는 실행 중이지만 remote-debugging flag·Chrome 소유 TCP listener·기본 DevToolsActivePort는 발견되지 않았다. 로그인 부재로 단정하지 않는다. Oracle 실제 질문·회수와 Dify 조작은 미실행이다.

## 유지한 기존 도구

- Oracle 0.22.0, mcporter 0.16.0, Chrome DevTools MCP 1.12.0 프로젝트 로컬 설치.
- Oracle 모델 비연결 렌더 exit 0, MCP 도구 5개 조회, consult dry run 성공. browser engine·gpt-6-pro·기존 Chrome 연결·manualLogin=false·cookie copy OFF·archive=never 확인.
- Chrome MCP의 mcporter 경유 정의는 기존 Chrome 소유권 정책에서 거절됐다. 재시도·정책 해제를 하지 않았다. 기본 mcporter 구성은 Oracle만 포함한다.
- Codex CLI 0.163.0-alpha.11.2 Cloud 도움말·실제 빈 작업 목록 조회 확인. 새 작업 제출·완료·결과 회수 미실행.
- Claude CLI는 이 로컬 PATH와 일반 설치 위치에서 미발견. 다른 기존 사용 환경의 부재를 뜻하지 않는다.
- DSH는 후순위, 미설치·미실행.

## 보관

공유 가능한 설정·판단·결과는 GitHub에 둔다. 자격증명·계정 DB·원본 세션 로그·개인 백업은 공개하지 않는다. 중지한 Switchy의 로컬 데이터도 자격증명을 포함하므로 비공개 상태로 남겼다.

임시 추출 폴더 삭제는 자동 승인 검토가 blocked by policy로 거부했다. 폴더는 남겨두고 재시도하지 않았다.

현재 실행 상태는 이 파일을 기준으로 한다. 연구 문서는 당시의 소스 판단이며, 실제 완료 여부를 대신하지 않는다.
