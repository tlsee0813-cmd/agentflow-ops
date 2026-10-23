# Switchy 준비 결과 · 2026-10-23

## 최종 판정

**Switchy 1.0.39는 상시 사용 보류·프로세스와 listener 중지 완료다.** 아래 준비 성공은 역사적 관찰이며 현재 채택 상태가 아니다.

독립 소스 검토에서 commands/invoke에 있는 loopback·Origin 검사가 accounts/switch에는 없고 router 전체에 open CORS가 적용됨을 확인했다. 실제 공격 실험은 하지 않았다. 정상 종료 신호 뒤에도 앱이 남아 자신이 시작한 PID만 중지했다. 신규 loader 한 줄만 있던 PowerShell profile 두 개는 비공개 보관 폴더로 이동해 원래 부재 상태를 복원했고 Codex config 동일성을 확인했다. 원본 데이터는 자격증명을 포함하므로 비공개 로컬에 남겼다.

[현재 채택 판단](../../docs/ACCOUNT_DECISION_KO.md) · [전체 상태](../../docs/STATUS.md)

## 목적

기존 OSS의 계정 전환 기능을 실제 로컬 환경에 준비하고, 기존 총괄의 설정·로그인을 유지하면서 AI가 원래 제어 API를 사용할 수 있는지 확인했다.

## 설치·실행

| 항목 | 관찰 |
| --- | --- |
| 원본 release | Switchy v1.0.39 |
| source/tag | fd5cbf163aaa745a2b53f6f7f87c43ce25a8bd0a |
| MSI bytes | 10,121,216 |
| MSI SHA-256 | b1ffbadf89b9f0fc236bfc7cb6f4e81c1b7519b533e15452147d3ed684d6b42b |
| 실행 파일 bytes | 24,632,832 |
| 실행 파일 SHA-256 | 42603b1cce48a7f9e8be321549f214f7a601d15ff0669f4d4958b38266b6eccf |
| 실행 방식 | 원본 MSI 관리 추출 후 사용자 로컬 경로, --autostart |
| 실제 제어 주소 | 127.0.0.1:15721 loopback listener |
| 원래 명령 조회 | 195개 |

한글 경로에서는 MSI 추출이 실패했고, 담당이 ASCII 임시 경로에서 표준 관리 추출로 해결했다. 추출 원본과 최종 실행 파일의 해시가 같았다. 전역 설치 등록을 수행하지 않았다.

## 계정과 설정 관찰

| 항목 | 결과 |
| --- | --- |
| 현재 Codex 로그인 import | true |
| 실제 연결 계정 | 1개 |
| 추가 Official 카드 | 준비, 로그인 없음 |
| 현재 provider 선택 | 준비 전후 동일 |
| 기존 auth.json | 준비 전후 hash 동일 |
| 기존 Codex config.toml | 준비 전후 hash 동일 |
| 정상 CLI 로그인 상태 | Logged in using ChatGPT |
| GitHub 준비 후 조회 | 성공 |
| 자동 rotation / warm-up / shared-session | OFF |
| Codex routing / auto-failover / Windows 자동 시작 | OFF 확인 |
| PowerShell profile | 원래 없던 두 파일에 loader 각 1개 생성 |
| shared-session enabled marker | 없음 |
| 등록된 WSL 배포 | 0개 |

계정 ID·이메일·토큰·auth 원문·DB·원본 로그는 이 공개 기록에 넣지 않았다. 해시는 기존 파일 내용의 동일성을 확인한 내부 비교이며 자격증명 해시를 공개한 것이 아니다.

## 판정

**도구 실행, 제어 API 호출, 현재 로그인 등록, 기존 설정 유지까지 확인했다.** 다른 계정으로 바꾼 것은 아니므로 계정 교체 성공·자동 회전·모델/도구 동등성으로 확대하지 않는다.

Codex 추가 계정 로그인은 Switchy의 Official 카드 선택 후 정상 codex login과 watcher capture가 원래 지원 경로다. Codex 전용 managed OAuth API가 있는 것으로 오해하지 않는다. 아직 현재 live 로그인 변경을 수행하지 않았다.

브라우저 도구는 Work 설정의 비활성화 오류를 반환했다. 새 Chrome 연결 경로로 우회하지 않았고, Pro 질문·회수나 Dify 화면 검증을 수행했다고 기록하지 않는다.

임시 추출 폴더 삭제는 자동 승인 검토가 blocked by policy로 거부해 중지했다. 폴더는 남아 있다.

## 이어갈 지점

이 버전을 다시 시작하지 않는다. QuotaCrew 원본 CLI를 다음 후보로 준비했다. 실제 계정 교체 검증은 정상 추가 로그인과 독립 실행 환경이 준비된 뒤 비교표와 대조한다. 자체 보안 프록시나 auth writer는 만들지 않는다.
