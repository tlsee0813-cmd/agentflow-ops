# 계정 우선순위와 같은 대화 재개 준비

2026-10-23 밤–24일 KST. 사용자 요청으로 계정 작업을 재개했다. Business 두 사용자 우선, Plus·크레딧 대체, Pro 비상용이며 Business 회복 후 안전 경계에 돌아오는 정책이다. 현재 Pro를 즉시 교체하지 않고 최초 소진을 기다린다.

## 현재 결론

**실제 자동 전환·Resume 성공은 아직 검증하지 않았다. 자동 실행은 꺼져 있다.** 현재 Work 총괄의 native monitor는 active였지만 설치된 Codex의 최신 턴 조회는 interrupted를 반환했다. 진행 중 턴을 정확히 귀속할 수 없어 감시를 중지했다. 새 로컬 Codex 총괄 UUID를 정한 뒤 해당 대화 관찰을 확인하는 좁은 설정이 남는다. 외부 Pro·Claude 로그인, Oracle 프로필, DSH 인증을 다시 준비할 필요는 없다.

## 실행과 검토

- 작성: Sol high. 독립 코드 검토: Astra high. 계정의 실제 전환 없이 합성 입력으로 중요한 실패 경계를 재현했다.
- 계정 정책 테스트 26개, 보완 실행기 테스트 45개 통과. 독립 검토자가 최종 변경분을 재검토해 범위 내 미해결 P1/P2가 없음을 확인했다. 테스트 개수는 실제 계정 전환 횟수가 아니다.
- 네 역할 매핑을 원본 vault에서 확인했다. 두 Business는 서로 다른 사용자이며 지정 Plus와 현재 Pro를 구분했다. 네 프로필 모두 codex 단일 bucket, fresh, 해석 가능, 현재 사용 가능한 캐시 값이었다. 키·이메일·토큰은 공개하지 않았다.
- private config를 사용한 `-CheckOnly`는 exit 0, `waiting_for_current_account_exhaustion`, currentRole emergency였다. 인증/설정 해시 불변, ledger/status 미작성으로 읽기 전용을 확인했다.
- Task Scheduler로 대기 감시를 한 번 명시 기동했다. 실제 상태는 waiting_for_current_account_exhaustion, 전환 claim은 없었다. 현재 대화의 메타데이터 불일치를 발견해 중지했다.
- `.ops/account-priority/current-test/config.json`은 enabled=false. 예약 작업은 Ready이고 자동 시작 트리거는 없다. 원본 계정 전환·Resume·로그아웃·브라우저 프로필 변경은 하지 않았다.
- 설치된 schema의 `thread/turns/list`를 실제 1회 호출해 최신 턴 ID 존재와 interrupted/usageLimitErrorConfirmed=false를 확인했다. 전체 대화 원문을 출력하지 않았다. Work 현재 턴을 Codex 턴으로 추정하지 않았다.

## 독립 검토에서 고친 경계

1. 같은 active 턴 도중 canonical 계정이 달라져도 실패를 새 계정에 귀속하지 않도록 고정했다.
2. 두 계정의 연속 실패가 단일 슬롯에서 덮어써져 첫 실패 계정을 다시 고르는 문제를 계정별 기록으로 고쳤다.
3. 다른 작업이 끝나기를 오래 기다렸다는 이유로 이미 확정한 같은 실패 턴의 재개 조건이 없어지지 않도록 했다.
4. 불확실 Resume 이후 사용자가 정상 새 턴을 만들면 중복 Continue 없이 claim을 정리하도록 했다.
5. 공통/model quota window가 같은 길이라는 이유로 값이 섞여 회복으로 오판되는 문제를 bucket+window 정체성으로 고쳤다.
6. 실제 monitor의 상태 필드 누락을 최신 턴 한 개 조회로 처리한다. 상태 또는 알려진 턴 ID가 불일치하면 관찰 기록·정책 시작 전에 `target_turn_not_observable`로 막는다. endpoint 미지원은 중지로 처리한다.

원본 Codex Switch 1.41.1 전환·재개 엔진을 수정하지 않았다. 실행기는 우선순위, 실제 상태 대조와 중복 실행 방지 기록을 맡는다. 새 인증 저장 형식이나 브라우저 제어 엔진은 만들지 않았다.

## 다음 확인

[계정 운영 문서](../../docs/ACCOUNT_OPERATIONS_KO.md)의 새 총괄 연결 절차를 따른다. 올바른 새 Codex UUID 관찰 → 읽기 전용 점검 → 감시 활성화 → 최초 실제 한도 사건에서 전환 및 동일 대화 재개 검증 순서다. 현재 같은 노트북의 세션이 보존된다는 사용자 경험과 자동 Resume의 실행 증거는 구분한다.
