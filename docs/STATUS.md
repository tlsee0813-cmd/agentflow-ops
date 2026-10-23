# 현재 상태

**2026-10-23 · QuotaCrew 원본 CLI 설치·정상 초기화·빈 프로필 2개·doctor 관찰 완료. Switchy 1.0.39는 실행 후 검토에서 보류하고 정리했다. 실제 계정 간 교체와 웹 Pro 왕복은 미검증이다.**

## 이번 판단과 실행

- Switchy 원본 MSI의 릴리스 SHA-256을 대조하고 관리 추출했다. 원래 제어 API 조회·현재 로그인 1개 import·빈 추가 카드 생성까지 작동했다.
- 독립 소스 검토에서 commands/invoke와 달리 accounts/switch 경로에는 loopback·Origin 검사가 없고 전체 router에 open CORS가 적용됨을 확인했다. 실제 공격 실험은 하지 않았다.
- 이 버전의 상시 사용을 보류했다. 정상 종료 신호 후에도 남은 자신의 Switchy 프로세스를 중지하고 listener 소멸을 확인했다.
- 처음 실행하며 생성한 PowerShell profile 두 개는 loader 한 줄만 있음을 확인해 비공개 보관 폴더로 이동했다. 원래 profile 파일이 없던 상태와 기존 Codex config를 복원 확인했다.
- QuotaCrew 0.3.0의 고정 소스로 Python 3.12.14 venv와 원본 CLI를 설치했다. 의존성 검사·UTF-8 도움말 확인, 원본 init과 빈 프로필 두 개 생성, doctor 관찰을 마쳤다. GUI 의존성은 설치하지 않았다. main auth/config는 전후 동일했다.
- 자동 계정 회전·감시는 어느 도구에서도 켜지 않았다. 자체 auth writer·watcher·보안 프록시를 만들지 않았다.

[계정 채택 판단](ACCOUNT_DECISION_KO.md) · [Switchy 준비와 보류 기록](../results/switchy-preparation-2026-10-23/RESULT.md) · [QuotaCrew 준비 기록](../results/quotacrew-preparation-2026-10-23/RESULT.md)

## 다음 실제 관문

현재 정상 확인된 Codex 로그인은 한 개다. Switchy의 빈 카드는 연결 계정이 아니다. QuotaCrew에는 agentflow-primary와 agentflow-secondary 빈 프로필을 준비했다. 둘 다 auth/binding이 없고 추가 계정 로그인은 하지 않았다.

QuotaCrew의 원본 profile add → profile login은 도구 소유 CODEX_HOME에 정상 로그인하는 경로다. main auth 가져오기 명령은 확인되지 않았다. 현재 로그인 복사·내부 DB 편집으로 이를 대체하지 않는다. 실제 전환에는 두 계정의 정상 등록이 필요하다.

QuotaCrew의 CLI 준비는 자동 감시 준비 완료와 다르다. GUI 없이 실행하는 CLI에는 상시 watcher 명령이 확인되지 않았다. Windows 실제 전환은 설치된 Desktop 종료를 포함하며 packaged Codex Desktop 자식에서 자기 전환을 시도하면 거부하는 경로가 있다. 실제 현재 exec 계보가 이 조건에 해당함을 읽기 진단으로 확인했다. 독립 실행과 재개 범위를 먼저 확인한다.

doctor exit 0은 모든 항목 합격이 아니다. 준비한 빈 두 프로필은 auth가 없어 원본 검사에서 FAIL이며, 이는 로그인 대기 상태를 뜻한다.

실제 대상 계정 적용·같은 작업 재개·모델과 도구 유지가 확인되기 전에는 계정 전환 합격이나 전체 조립 완료로 표시하지 않는다.

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
