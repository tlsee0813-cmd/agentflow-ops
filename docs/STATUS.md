# 현재 상태

**2026-10-23 · 원본 Codex Switch 1.41.1에 두 Business 사용자와 기존 현재 로그인을 보관하고 독립 실행·실제 quota 조회까지 완료했다. 실제 계정 교체/동일 대화 재개는 다음 검증이다.**

## 최신 완료와 근거

- QuotaCrew 0.3.0은 같은 workspace의 다른 사용자를 혼동해 보류한다. 두 사용자 정상 로그인은 유효하며 다시 로그인시키지 않았다.
- 원본 Gaebabi Codex Switch는 workspace+JWT sub로 사용자를 구분한다. 원본 EXE/전환 엔진을 유지하고, 버전 고정 내부 API용 일회성 가져오기 어댑터만 추가했다.
- Q 원본 reader → 메모리 pipe → G 원본 parser/vault/DPAPI로 두 사용자를 가져왔다. 현재 canonical은 두 Business 프로필 밖의 별도 identity여서 세 번째 항목으로 보존했다. 실제 import exit 0, 계정 수 3, main auth/config 각각 전후 동일.
- 원본 DLL·DPAPI를 사용하는 synthetic 검사 20개와 독립 소스 검토를 마쳤다. 실행 중 manager에서 wrapper가 인증 접근 전에 거부하는 것도 확인했다. 가짜 검사와 실제 계정 전환을 섞지 않는다.
- 독립 utility 실행에 성공했다. MSIX 논리/물리 경로 차이를 해결했고 Codex 부모 계보가 없다. 임시 실행 task 잔류 0, 사용자 시작 메뉴에 AgentFlow Accounts 바로가기 생성.
- 독립 process가 시작된 뒤 세 프로필 모두 원본 quota CheckedAt이 갱신됐고 ordinaryUsageAllowed=true였다. 별도 CLI override는 필요하지 않았다.
- secondary 대상 원본 credential backend 검사 통과. 원본 Desktop 진단은 exit 0/36 samples/owner RPC 확인. 원본 monitor의 active root 집합에는 현재 총괄 UUID 하나만 있었다.
- Switchy 1.0.39는 중지·보류, 원래 없던 PowerShell profile 상태 복원 완료를 유지한다.

[가져오기·독립 실행 결과](../results/codex-switch-import-2026-10-23/RESULT.md) · [원본 portable 영수증](../results/codex-switch-preparation-2026-10-23/RESULT.md) · [계정 운영](ACCOUNT_OPERATIONS_KO.md) · [이전 identity 문제](../results/quotacrew-business-identity-2026-10-23/RESULT.md)

## 다음 실제 관문

원본 manager가 현재 총괄의 active root 한 개를 정확히 포착하는지 다시 확인한 뒤, secondary의 실제 Key로 native 전환 요청을 한 번 보낸다. 현재 GitHub 기준과 로컬 상태를 저장하고 원본 정상 종료·앱 실행·동일 UUID 재개 결과를 확인한다. CLI의 exit 0만으로 성공을 표시하지 않는다.

재개됐을 때는 요청을 다시 전송하기 전에 원본 PendingSwitch/last-switch와 canonical Key를 대조한다. 같은 thread UUID·모델/도구·작업 폴더·GitHub 접근 확인이 남아 있다. 자세한 절차는 ACCOUNT_OPERATIONS_KO를 따른다.

현재 기능은 수동 native 계정 전환과 원본의 적격 대화 자동 재개다. 한도 소진 후 계정을 자동 선택·회전하는 정책은 아직 설정하지 않았다. 웹 Pro·Cloud·Claude 등의 실제 동등성 관문도 그대로 남아 있다.

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
