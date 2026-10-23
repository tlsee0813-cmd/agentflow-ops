# QuotaCrew CLI 준비 결과

**이후 정상 로그인에서 같은 Business workspace의 사용자 identity 충돌을 확인해 보류했다. [후속 실제 결과](../quotacrew-business-identity-2026-10-23/RESULT.md)를 우선한다.** 아래는 로그인 전 준비 영수증이다.

2026-10-23. 원본 CLI 설치, 정상 초기화, 로그인 대기용 빈 프로필 두 개 생성과 doctor 관찰을 완료했다. 실제 로그인·계정 교체·자동 재개 성공을 의미하지 않는다.

## 설치 영수증

| 항목 | 확인 결과 |
| --- | --- |
| 도구 | `codex-quotacrew 0.3.0` |
| 원본 | [erkanpulat/codex-quotacrew](https://github.com/erkanpulat/codex-quotacrew) |
| 설치한 소스 SHA | `9667dd561b6507e4ec0ea09fc9f1055e1f242f84` |
| 설치 입력 | 해당 commit의 GitHub source ZIP, 3,286,735 bytes |
| source ZIP SHA-256 | `a74e2d1f4672179ac9a31932577a6264cde418773d0be9d7adc6526275a8352d` |
| Python | `3.12.14`, 별도 venv |
| 설치 범위 | 사용자 로컬의 전용 도구 폴더, 전역 Python/PATH 변경 없음 |
| 설치 방식 | 원본 source ZIP에 대한 기본 `pip install`, GUI extra 제외 |
| 의존성 검사 | `pip check`: `No broken requirements found.` |
| GUI 의존성 | `PySide6` 미설치 |
| CLI entry points | `codex-accounts`, `cx` |
| 별도 기록 | 로컬 설치 폴더에 `INSTALL_RECEIPT.json`, `installed-requirements.txt` 보관 |

위 ZIP 해시는 실제 내려받은 commit archive의 관찰값이다. 별도의 릴리스 바이너리 체크섬으로 표현하지 않는다. 소스는 고정했으며 upstream의 의존성 범위에 따라 설치된 하위 패키지 버전은 로컬 목록에 따로 기록했다.

[원본 pyproject.toml](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/pyproject.toml)에 따르면 Python 지원 범위는 `>=3.11,<3.14`다. `--no-gui`라는 설치 옵션은 없다. 기본 패키지를 설치하고 `[gui]` extra를 선택하지 않는 것이 원본 지원 경로다. GUI entry point가 생성돼 있어도 GUI 의존성이 설치됐다는 뜻은 아니다.

## 실행해 확인한 항목

- 설치 패키지 메타데이터: `codex-quotacrew 0.3.0`.
- 의존성 검사: 통과.
- 상위 CLI `--help`: UTF-8 모드로 exit 0.
- `codex-accounts.exe --help`: 프로세스 한정 `PYTHONUTF8=1`, `PYTHONIOENCODING=utf-8` 환경에서 exit 0.
- `codex --version`: `codex-cli 0.163.0-alpha.11.2`. 인증 상태나 내용을 조회하는 명령은 실행하지 않았다.
- 원본 `init`: exit 0.
- 원본 `profiles`: 지정 alias의 중복 여부 확인용으로 실행하고 원문은 공개하지 않았다.
- 원본 `profile add agentflow-primary`, `profile add agentflow-secondary`: 각각 exit 0. 같은 alias가 있으면 생성을 건너뛰도록 확인한 뒤 두 빈 프로필을 새로 만들었다.
- 원본 `doctor`: bundle 없이 exit 0. 전체 출력은 로컬에서만 파싱하고 아래 허용된 관찰값만 기록했다.

기본 Windows 코드페이지에서는 상위 도움말의 긴 대시를 출력하다 `UnicodeEncodeError`가 발생했다. 원본 코드를 수정하지 않고 Python의 UTF-8 실행 옵션으로 해결했다. 전용 runtime 안에서 다음처럼 호출할 수 있다.

```powershell
& .\venv\Scripts\python.exe -X utf8 -m codex_account_manager.cli.main --help
& .\venv\Scripts\python.exe -m pip check
```

이는 설치된 원본 모듈을 실행하는 명령이며 자체 실행기를 추가하지 않았다. 전역 환경변수나 PowerShell profile도 수정하지 않았다.

## 초기화와 진단의 쓰기 범위

[CLI의 공통 callback](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/cli/main.py#L47)은 실제 하위 명령을 수행하기 전에 `configure_logging()`과 `initialize_database()`를 호출한다. 따라서 명령 본문만 읽고 전체 명령을 read-only로 판단하면 안 된다.

`configure_logging()`은 [paths.ensure와 rotating file log](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/core/logging.py#L38)를 구성한다. [paths.ensure](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/core/paths.py#L27)는 도구 소유 데이터·프로필·로그·백업 폴더를 만들고 접근 권한을 제한한다. [데이터베이스 초기화](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/storage/migrations.py#L321)는 SQLite 파일을 열어 WAL을 설정하고 필요하면 백업·migration·schema 기록을 수행한다.

이 쓰기를 원본 도구의 정상 준비 범위로 허용한 뒤 `init`, 지정한 빈 프로필 생성과 `doctor`를 실행했다. read-only 진단이라고 표현하지 않는다. 자체 DB와 도구 폴더의 준비이며, 로그인이나 공유 main auth 교체와 구분한다.

| 명령 | 본문과 공통 시작 단계 | 이번 실행 |
| --- | --- | --- |
| `init` | DB 생성·migration. 공통 callback에서도 같은 초기화를 수행 | 실행, exit 0 |
| `status` | 본문은 설치됨 문구 출력이지만 공통 callback의 폴더·로그·DB 쓰기가 먼저 발생 | 미실행 |
| `profiles` | 프로필 목록 조회. 공통 callback에서 쓰기가 먼저 발생하며 계정별 메타데이터를 출력 | 중복 확인용 실행, 원문 비공개 |
| `profile list` | 이 버전 CLI에 해당 명령이 없음. 목록 명령은 상위 `profiles` | 미실행 |
| `doctor` | 공통 callback의 쓰기 이후 진단 수행 | 실행, exit 0, 허용된 항목만 공개 |
| `doctor --bundle` | 위 동작에 진단 ZIP 생성까지 추가 | 미실행 |
| 상위 `--help` | eager help 경로. 공통 callback을 실행하는 하위 명령을 선택하지 않음 | 실행, exit 0 |
| `doctor --help`, `profile --help` 등 하위 도움말 | 부모 callback의 부작용 가능성이 있어 안전한 도움말로 가정하지 않음 | 미실행 |

[doctor 원본](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/diagnostics/doctor.py#L29)은 CLI 경로·버전, 공유 home과 session history의 존재, 도구 DB, 프로필별 auth 존재·binding 여부, Desktop 설치·실행 상태와 pending recovery 존재를 확인한다. 실행 전에 해당 경로가 credential 본문이나 토큰을 읽지 않고 파일 존재와 binding 여부를 검사하는 것을 확인했다. credential 값을 읽는 `read_profile`이나 profile session은 doctor에서 호출하지 않는다. 내부 진단 함수를 우회 호출하지 않았으며 원래 CLI 명령을 실행했다.

## 실제 doctor 관찰

2026-10-23 06:40 UTC의 관찰이다. raw 출력, 개인 경로, 계정별 식별자와 해시 값은 공개하지 않는다.

| 항목 | 관찰 |
| --- | --- |
| 파싱한 doctor check 수 | 12 |
| Codex CLI 경로 존재 | true |
| Codex CLI 버전 | `0.163.0-alpha.11.2` |
| 공유 Codex home 존재 | true |
| session history 폴더 존재 | true; 내용 미열람 |
| QuotaCrew DB 존재 | true |
| Codex Desktop 설치 | true |
| Codex Desktop 실행 중 | true |
| profile 수 | 2 |
| `agentflow-primary` | auth 존재 false, binding false |
| `agentflow-secondary` | auth 존재 false, binding false |
| pending switch recovery | false |
| main auth 전후 동일 | true |
| main config 전후 동일 | true |

두 profile 항목은 인증이 없으므로 원본 doctor의 `FAIL` 조건에 해당한다. 의도적으로 준비한 빈 프로필 상태이며, doctor의 exit 0을 모든 항목 합격이나 로그인 성공으로 확대하지 않는다. main auth/config는 내용이나 해시 값을 출력하지 않고 전후 동일 여부만 비교했다. 인증 데이터의 본문을 해석하지 않았다.

총괄의 별도 프로세스 계보 관찰에서는 현재 작업 shell이 Codex와 패키지 Desktop의 자식으로 확인됐다. 이 준비에서 계정 전환은 시도하지 않았다. 원본의 독립 실행 요구를 충족하는 후속 경로를 마련하기 전에는 현재 세션에서 `switch`를 호출하지 않는다.

## 계정 등록 경로의 소스 확인

[profile add](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/accounts/service.py)는 도구 소유의 UUID 프로필 폴더와 `cli_auth_credentials_store = "file"` 설정을 만든다. `profile login`은 그 프로필 경로를 [`CODEX_HOME`으로 지정](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/codex/runtime.py)해 원래 `codex login`을 실행한다. Windows에서는 원본의 [DPAPI profile session](https://github.com/erkanpulat/codex-quotacrew/blob/9667dd561b6507e4ec0ea09fc9f1055e1f242f84/src/codex_account_manager/adapters/credential_store.py)을 사용한다.

실제 profile 생성 결과도 두 계정 모두 auth와 binding이 없는 것으로 확인했다. 별도 프로필의 정상 로그인 경로에 대한 설명은 소스 확인이며 실제 로그인 검증은 아니다. 공유 main auth를 교체하는 `switch` 경로와 구분한다. 현재 main auth를 가져오는 전용 CLI 명령은 확인하지 못했다. `bind`는 이미 해당 프로필에 있는 auth를 binding하는 명령이므로 main auth import와 같지 않다.

## 정확히 미실행인 항목

`status`, 진단 ZIP export, 지정한 두 빈 프로필 외의 profile 생성, profile 삭제·binding, 계정 import, 로그인, quota 조회, 계정 전환, GUI, 자동 감시, 자동 재개, sandbox setup, completion 설치를 실행하지 않았다. 자체 watcher·auth writer·실행기를 만들지 않았다. 계정별 메타데이터와 진단 원문은 외부로 전송하지 않았으며 main auth/config 변경을 수행하지 않았다.

설치, 원본 초기화, 빈 프로필 두 개와 doctor 관찰까지 완료했다. 실제 로그인·계정 교체, Desktop/CLI 연속성, 지정 대화의 자동 재개는 모두 별도 미검증 관문으로 남긴다.
