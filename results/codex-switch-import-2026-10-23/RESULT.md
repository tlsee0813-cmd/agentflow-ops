# 두 Business 사용자 가져오기와 독립 실행 · 2026-10-23

## 결과

**추가 재로그인 없이 두 Business 프로필과 기존 현재 로그인을 원본 Codex Switch vault에 등록했다.** 실제 main 계정 교체는 이 기록 시점에 아직 실행하지 않았다. 이후 실제 교체는 [STATUS](../../docs/STATUS.md)와 원본 전환 기록으로 확인한다.

| 항목 | 실제 관찰 |
| --- | --- |
| 원본 버전 | Codex Switch 1.41.1 portable |
| 계정 가져오기 | exit 0, 원본 vault에 세 항목 |
| 가져온 Q 프로필 | 2개, 같은 workspace·서로 다른 원본 복합 Key |
| 기존 canonical | 두 Business 프로필 밖의 별도 Key, 세 번째 항목으로 보존 |
| main auth / config | 가져오기 전후 각각 동일 |
| 계정 원문·비밀번호·토큰의 공개 저장 | 없음 |
| 원본 utility 독립 실행 | 성공, Codex 부모 계보 없음 |
| 독립 실행 뒤 원본 quota 조회 | 세 항목 모두 새 CheckedAt, ordinaryUsageAllowed=true |
| 원본 credential backend 검사 | secondary 대상 통과 |
| native Desktop 상태 검사 | 원본 CLI exit 0, 36 samples, available/owner RPC 확인 |
| 원본 monitor의 active 캡처 집합 | 현재 총괄 UUID 1개, 다른 active root 0개, 제목 존재 |
| 실제 auth 적용·Desktop 재시작·동일 작업 재개 | 이 기록 시점 미실행 |

원본 저장소의 IsCurrent/Error는 JsonIgnore 필드라 vault 파일을 다시 읽은 값으로 GUI의 실시간 상태를 주장하지 않았다. 현재 판단은 원본 parser의 canonical Key 비교, live quota는 독립 프로세스 시작 이후 새로 저장된 CheckedAt으로 확인했다. 사용량 숫자가 같거나 workspace가 같다는 사실로 사용자 한도가 공유된다고 추정하지 않는다.

## 재사용한 코드와 최소 연결

- [원본 AccountVault](https://github.com/Gaebabi/codex-switch/blob/98af9e4687d26bcc14198d8adc71922f0ca46d89/src/application/Storage.cs)의 Upsert/Save와 원본 AuthDocument.Parse를 그대로 호출했다.
- Q의 기존 FileCredentialStore.read_profile을 사용해 선택한 두 프로필만 메모리 pipe로 전달했다. 이 API는 남은 profile plaintext가 있으면 원래의 DPAPI 봉인 처리를 수행한다. pure read-only라고 표현하지 않는다.
- 원본 G DPAPI·atomic vault writer를 재사용했다. CLI 전환 엔진·원본 EXE·계정 DB schema를 변경하지 않았다.
- 연결은 [core](../../scripts/codex-switch-import-core.ps1), [일회성 reader](../../scripts/import-quotacrew-to-codex-switch.ps1), [synthetic 검사](../../scripts/test-codex-switch-import.ps1)다. upstream 공식 import CLI가 아니라 고정 DLL 내부 API 연결임을 공개한다.

## 검증과 발견한 차이

가짜 자격으로 원본 DLL 로드, 동일 workspace의 다른 사용자, DPAPI 재열기, 현재 canonical 우선, 별도 canonical의 세 번째 보존, 세 번째 충돌 시 전체 무저장, malformed/크기/별칭/PendingSwitch/동시 mutex 거부를 확인했다. 최종 synthetic 검사 20개가 통과했다. 이 수는 live 계정 전환 검사 수가 아니다.

실제 첫 가져오기는 canonical이 두 Q 프로필 중 하나여야 한다는 좁은 전제에서 저장 전에 중단됐다. 확인 결과 현재 디스크 로그인은 두 Business 사용자 밖의 별도 identity였다. 원본 current import와 같이 이를 세 번째 항목으로 보존하도록 보완·검토한 후 가져오기를 완료했다. 현재 로그인을 새 Q 자격으로 덮어쓰지 않았다.

관리자가 이미 실행 중일 때 live wrapper가 context 단계의 고정 guard로 거부하는 것도 확인했다. 이 검사는 인증 읽기 전에 끝났다. wrapper의 모든 timeout·과대 출력 분기를 별도 실계정으로 실행했다고 주장하지 않는다.

## MSIX와 프로세스

논리 LOCALAPPDATA 경로로 외부 예약 작업을 시작할 때 FileNotFound/PathNotFound가 발생했다. 담당이 실제 package LocalCache 물리 경로를 확인해 해결했다. 복사·재인증으로 우회하지 않았다.

원본 manager의 독립 실행 계보에는 Codex가 없고, 관련 일회성 task 잔류는 0이다. CLI override 없이 독립 실행 후 세 항목의 새 quota 결과가 저장됐다. 사용자 시작 메뉴의 AgentFlow Accounts 바로가기는 원본 EXE와 물리 data-directory를 가리킨다. 개인 경로가 든 설치·실행 receipt는 비공개 로컬에만 둔다.

## 제한

자동 승인 검토가 시험 임시 폴더 삭제를 blocked by policy로 거부했다. 해당 삭제는 재시도하지 않았으며 작은 synthetic 자료를 남겼다.

실제 계정 전환과 동일 대화 재개, 모델·도구 동등성, 브라우저 Pro 왕복, 한도 소진 후 무인 계정 회전은 이 결과로 통과시키지 않는다. 시작 메뉴와 원본 CLI의 사용·다음 검증은 [운영 안내](../../docs/ACCOUNT_OPERATIONS_KO.md)에 있다.
