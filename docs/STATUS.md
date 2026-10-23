# 현재 상태

**2026-10-23 · 사용자 지시로 현재 Pro를 유지하며 계정 전환 시험을 보류했다. 현재 작업은 하네스·위임·회수 개선이다. 자동 계정 회전은 켜지 않았다.**

## 실제 왕복 시험 최신 결과

[시험 기록과 공유 화면 증거](../results/harness-smoke-2026-10-23/RESULT.md).

- 부모 대화 상속 없는 Sol High 새 보조 세션이 좁은 지시를 받고 역할·근거·미확인을 올바르게 반환했다. 외부 서비스나 절감률 검증과 구분한다.
- 앱 안 브라우저가 다시 사용 가능했다. 사용자 웹 Pro 로그인 후 질문 접수·응답 완료·전체 답변 회수를 확인했다. 여러 줄 native 입력이 분할 전송되어 첫 시험은 불완전했고, 초안 전체 확인 후 한 번 보내는 방식으로 보완했다. 실제 경로는 CUA이며 Oracle/Chrome attach 합격은 아니다.
- 브라우저의 기존 agentflow-studio-dev 원격 환경에서 읽기 전용 시험을 완료하고 같은 thread 후속 결과도 회수했다. checkout은 README만 있는 초기 커밋이었다. GitHub 직접 조회는 구성된 프록시 연결 실패로 막혔으며, 총괄이 connector에서 확인한 좁은 문서 발췌를 제공하자 해석·결과 회수가 됐다.
- Cloud CLI는 여전히 목록 조회만 확인했다. 위 durable host의 브라우저 원격 작업과 CLI 작업을 합치지 않는다.
- Claude Code 로컬 CLI·WSL 환경은 찾지 못했다. 웹 Code 주소는 로그인 화면까지 확인했으며 현재 앱 브라우저에서 사용자 로그인이 필요하다. 다른 브라우저의 기존 Claude 세션이 없다는 뜻은 아니다.
- 계정 교체는 총괄 Codex에만 적용한다. 외부 웹 Pro·Claude 등의 계정·작업 세션은 그대로 사용한다.

## 이번 갱신

- 저장소 AGENTS.md에 외부 채널 우선 배정, 내장 Sol High/Astra High 분담, 관련 문맥만 전달, 동일 주제 세션 재사용, 중복 조사·중복 검토 방지 규약을 반영했다. WORK_ORDER/WORK_RESULT를 추가했다. 이는 실행 지침이며 모델 자동 선택기나 연결 완료를 뜻하지 않는다.
- 하네스·OSS 선택 근거는 [HARNESS_SELECTION_KO](HARNESS_SELECTION_KO.md), 운영은 [HARNESS_RUNBOOK_KO](HARNESS_RUNBOOK_KO.md)에 둔다. 실제 토큰/한도 절감은 아직 측정하지 않았다.
- vault에는 Business 두 사용자, Plus, Pro 네 항목이 있다. 사용자가 수동으로 Pro를 선택했고 canonical과 현재 대화의 존재를 읽기 검사로 확인했다. 기존 수동 전환의 chats=0 기록은 자동 대화 재개 성공 증거가 아니다.
- 원본 관리자 재실행과 quota 갱신 확인. 임시 실행 task는 제거했다. 관리자의 quota 조회는 원본 기능이며 자동 계정 회전은 아니다.
- 새 브리지의 스냅샷·대화·설정 조회가 실제 환경에서 동작했다. 최근 interrupted turn은 usageLimitExceeded가 아니었다. 이 경우 한도 실패로 해석하지 않는다.
- 우선순위 정책의 가짜 입력 26개 통과. native-account-bridge와 run-account-priority는 개발 중 코드이며 자동 전환·실패 대화 재개를 실증하지 않았다. runner는 구문 검사만 수행했고 활성화·예약하지 않았다. failed-thread Resume와 실패 당시 계정 식별은 runner에 미구현이다.
- 향후 계정 우선순위는 Business 두 사용자 → Plus·보유 크레딧 → Pro 비상용이다. Business 실제 회복을 확인하고 안전한 시점에 돌아간다. 현재 Pro 유지 지시가 이 향후 정책보다 우선한다.
- GitHub connector 읽기를 다시 확인했다. 아래 외부 브라우저·Claude·Cloud 제한은 이전 관찰이며 이번 하네스 조사로 연결이 복구됐다고 주장하지 않는다.

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

## 계정 작업 재개 시 관문 — 현재 실행하지 않음

사용자가 계정 시험을 재개하면 fresh quota와 대화 상태, 수동 선택을 새로 확인한다. 이전 secondary 요청을 그대로 재전송하지 않는다. 원본 정상 종료·앱 실행·동일 UUID 재개 결과를 확인하고 CLI의 exit 0만으로 성공을 표시하지 않는다.

재개됐을 때는 요청을 다시 전송하기 전에 원본 PendingSwitch/last-switch와 canonical Key를 대조한다. 같은 thread UUID·모델/도구·작업 폴더·GitHub 접근 확인이 남아 있다. 자세한 절차는 ACCOUNT_OPERATIONS_KO를 따른다.

현재 기능은 수동 native 계정 전환과 원본의 적격 대화 자동 재개다. 한도 소진 후 계정을 자동 선택·회전하는 정책은 아직 설정하지 않았다. 웹 Pro·Cloud·Claude 등의 실제 동등성 관문도 그대로 남아 있다.

## 이전 브라우저 접근 제한 — 현재는 위 왕복 결과로 갱신

이전 계정/세션 상태에서 브라우저 도구가 다음을 반환했다. 이번에는 같은 지원 도구의 브라우저 조회와 조작이 성공했다.

> Browsers: Error: Local browser use is disabled in Work settings

당시 Work 로컬 브라우저 기능 비활성화 진단이었다. 정확한 원인은 확정하지 않았고 정책을 우회하지 않았다. 현재 CUA 왕복 성공과 Oracle 연결 조건은 별개다.

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
