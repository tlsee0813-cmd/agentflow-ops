# 같은 Business 워크스페이스의 사용자 구분 · 2026-10-23

## 실제 관찰

사용자는 같은 Business 워크스페이스의 서로 다른 사용자 계정 두 개로 정상 로그인을 진행했다. 초기 판정에서 총괄이 중복 계정 오류를 같은 사용자 로그인으로 단정한 것은 잘못이었다.

| 관찰 | 결과 |
| --- | --- |
| primary 프로필 auth / binding | true / true |
| secondary 프로필 auth / binding | true / false |
| 원본 secondary bind | 중복 계정으로 거부 |
| 각 프로필의 새로운 native account 조회 | 성공 |
| snapshot account_id 동일 | true |
| snapshot email 동일 | false |
| 실제 main 계정 전환 | 미실행 |

비교는 원본 AccountService.read_snapshot을 각 프로필에서 새로 실행해 메모리에서 수행했다. ID·이메일·토큰·인증 원문은 출력하거나 이 저장소에 저장하지 않았다. auth 존재만으로 정상 binding 완료로 판단하지 않는다.

## 원인과 판정

[adapter](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/adapters/app_server.py)는 account_id에 rateLimits의 accountId 또는 workspaceRouting.chatgptAccountId 등을 사용하고 email은 별도 표시 필드로 둔다. [binding](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/accounts/service.py)은 이 account_id의 중복을 거부한다.

같은 ID는 active profile 선택·현재 인증 보존·전환 대상 검증·continuation에도 쓰인다. 따라서 DB의 중복 제한만 제거하는 수정은 올바르지 않다. 사용자와 workspace를 구분하는 identity를 관련 경로에 일관되게 반영해야 한다.

**QuotaCrew 0.3.0은 이 환경의 실제 전환 후보로 보류한다.** 빈 프로필 준비·로그인 동작과 같은 워크스페이스의 여러 사용자 지원을 구분한다. 사용자에게 같은 로그인을 반복시키거나 계정이 같다고 다시 단정하지 않는다. 이미 저장한 인증은 기존 비공개 프로필에 보관하고 DB나 인증 파일을 임의로 수정하지 않는다.

확인 시 upstream 최신 main과 release는 설치 source 9667dd561b6507e4ec0ea09fc9f1055e1f242f84 / v0.3.0과 같았다. workspace 키워드의 공개 issue/PR 검색에서는 일치 결과를 찾지 못했다. 검색 결과가 없다는 사실을 upstream의 전체 지원 부재 증거로 확대하지 않는다.

## 다음 비교

기존 Gaebabi codex-switch는 AuthDocument.Parse에서 workspace accountId와 JWT sub를 함께 해시한 Key를 사용한다. 서로 다른 user subject를 구분하는 구조다. 실제 등록·적용·검증 경로까지 이어지는지 확인하며, 소스 구조를 이 노트북의 실제 전환 성공으로 표현하지 않는다.

서로 다른 사용자에게 각각 어떤 한도가 적용되는지는 별도 원본 조회로 확인해야 한다. 같은 워크스페이스라는 이유만으로 한도를 공유한다거나 전환이 불필요하다고 추정하지 않는다.

현재 실행 상태와 선택은 [STATUS](../../docs/STATUS.md), [계정 판단](../../docs/ACCOUNT_DECISION_KO.md)을 따른다.

## 기존 대안의 identity 검토

- Gaebabi codex-switch의 [AuthDocument.Parse](https://github.com/Gaebabi/codex-switch/blob/2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c/src/core/Models.cs#L134-L145)는 workspace accountId와 사용자 JWT sub를 함께 Key로 만든다. 원본 등록은 GUI의 현재 로그인 import 또는 격리 로그인이다. Windows CLI의 --switch-account는 있지만 계정 등록/import CLI와 QuotaCrew DPAPI 가져오기 경로는 확인되지 않았다. 실제 지원을 확인하기 전 인증 저장소를 임의로 옮기지 않는다.
- CC Switch v4.0.18 release source cb90a2440d1a771d67f46b65b2e0f2ea5106ce85도 [workspace+sub 중복 판정과 같은 workspace의 두 사용자 테스트](https://github.com/farion1231/cc-switch/blob/cb90a2440d1a771d67f46b65b2e0f2ea5106ce85/src-tauri/src/proxy/providers/codex_oauth_auth.rs#L1783-L1809)가 있다. [live marker 검증](https://github.com/farion1231/cc-switch/blob/cb90a2440d1a771d67f46b65b2e0f2ea5106ce85/src-tauri/src/codex_config.rs#L529-L570)도 workspace와 사용자 sub를 함께 검사한다. GUI·provider 관리 범위가 넓으며 이 노트북 설치/전환은 미실행이다.
- JJLiebig codex-account-switcher는 [workspace key를 우선](https://github.com/JJLiebig/codex-account-switcher/blob/045cb4f6ce2136ef3ecb2386d6f8aa841367c3ca/src/identity.rs#L43-L48)하고 [다른 email·같은 key를 동일 계정으로 처리](https://github.com/JJLiebig/codex-account-switcher/blob/045cb4f6ce2136ef3ecb2386d6f8aa841367c3ca/src/repository.rs#L455-L471)해 이번 조건의 대안으로 선택하지 않는다.

이 비교는 소스의 저장·identity 검증 기준이다. 실제 실행 중인 Codex가 새 계정을 채택하거나 동일 총괄이 재개됐다는 증거와 구분한다. 도구를 선택하기 전 사용자에게 추가 로그인을 다시 요청하지 않는다.