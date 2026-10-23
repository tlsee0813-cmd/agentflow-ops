# QuotaCrew 원본 CLI 준비

2026-10-23 · **이후 실제 로그인에서 같은 Business workspace의 사용자 구분 문제를 확인해 보류했다. [최신 결과](../results/quotacrew-business-identity-2026-10-23/RESULT.md)를 먼저 읽는다.** 아래는 초기 준비 기록이다.

 설치·원본 초기화·로그인 대기용 빈 프로필 두 개·doctor 관찰을 완료했다. 로그인·전환·자동 감시는 실행하지 않았다. 현재 판정은 [STATUS](STATUS.md)를 따른다.

## 고정한 원본

- upstream: erkanpulat/codex-quotacrew
- release: v0.3.0
- source: 9667dd561b6507e4ec0ea09fc9f1055e1f242f84
- 도구 위치: %LOCALAPPDATA%/AgentFlowOps/tools/QuotaCrew-0.3.0
- Python 3.12.14 venv에 기본 패키지만 설치. GUI extra·PySide6 미설치.

소스 archive SHA-256과 실제 검사는 [준비 결과](../results/quotacrew-preparation-2026-10-23/RESULT.md)에 기록한다. 사용자 경로·자격증명은 공유하지 않는다.

## 기존 CLI 호출

한국어 Windows 코드페이지에서 도움말의 Unicode 출력 오류가 있었으므로 Python의 원래 UTF-8 모드를 사용한다. 별도 wrapper를 만들지 않는다.

~~~powershell
& "$env:LOCALAPPDATA\AgentFlowOps\tools\QuotaCrew-0.3.0\venv\Scripts\python.exe" -X utf8 -m codex_account_manager.cli.main --help
~~~

venv의 codex-accounts.exe와 cx.exe도 원본 entrypoint다. 기본 설치에 GUI가 없다는 뜻이며, 존재하지 않는 --no-gui 옵션을 사용하지 않는다.

## 정상 계정 등록 경로

원본 profile add로 agentflow-primary와 agentflow-secondary를 준비했다. 둘 다 auth/binding이 없다. 다음 정상 등록 단계는 원본 profile login이며, 아직 실행하지 않았다. 실제 로그인은 사용자가 정상 인증 화면에서 완료한다. 채팅·GitHub로 비밀번호나 토큰을 받지 않는다.

원본 서비스는 UUID별 프로필 폴더에 설정을 만들고, 그 폴더를 프로세스 CODEX_HOME으로 지정해 codex login을 실행한다. Windows profile_session은 프로필 auth를 DPAPI로 보관한다. 공유 main auth 적용은 별도 switch transaction이다.

현재 main auth를 가져오는 CLI 명령은 확인되지 않았다. bind는 이미 프로필 안에 존재하는 auth를 연결하므로 import-current의 대체로 사용하지 않는다. 원본 서비스를 우회해 파일을 복사하거나 계정 DB를 편집하지 않는다.

## 실제 전환 전에 남은 것

- 두 계정의 정상 등록과 quota/identity 확인.
- 현재 총괄과 분리된 독립 실행. packaged Codex Desktop 자식에서 자기 전환을 시도하면 거부하는 경로가 있다. 실제 이 세션의 exec 계보는 pwsh → codex → OpenAI.Codex 패키지의 ChatGPT.exe로 관찰했다. 단순히 같은 셸에서 background 실행하는 것으로 독립 실행이 되지 않는다.
- Windows Desktop 종료·재시작과 실제 같은 대화 재개 확인. 기존 세션 기억은 유지된다는 사용자 전제로 하되 성공 관찰을 대체하지 않는다.
- GUI 기반 자동 감시와 CLI 수동 전환을 구분. 현재 기본 CLI만 설치한 상태에 자동 watcher가 켜졌다고 기록하지 않는다.
- [비교표](COMPARISON_KO.md)로 계정 적용·작업 재개·모델/도구·GitHub·브라우저 작업을 각각 확인.

도구 관리자를 두 개 동시에 활성화하지 않는다. Switchy 1.0.39는 중지·보류 상태다.

## 설치 재현

Python 3.11 이상 3.14 미만에서 전용 venv를 만든 뒤 고정 source ZIP을 기본 패키지로 설치한다. 이 노트북은 이미 설치했으므로 재실행할 필요가 없다.

~~~powershell
python -m venv .venv-quotacrew
& .\.venv-quotacrew\Scripts\python.exe -m pip install 'https://github.com/erkanpulat/codex-quotacrew/archive/9667dd561b6507e4ec0ea09fc9f1055e1f242f84.zip'
& .\.venv-quotacrew\Scripts\python.exe -m pip check
~~~

upstream 소스 commit은 고정했다. 하위 Python 의존성 전체를 고정한 공용 lock은 아직 없으므로 다른 날 설치 결과까지 완전히 같다고 표현하지 않는다. 현재 설치의 패키지 목록은 도구 로컬에 보관한다.
원본 doctor는 경로·DB·history 존재와 두 빈 프로필의 auth/binding 부재를 확인했다. 빈 프로필 두 개는 FAIL로 표시된다. doctor exit 0을 모든 검사 합격으로 해석하지 않는다. 원본 CLI 공통 초기화는 도구의 DB·폴더·로그를 쓰므로 read-only 실행이었다고 기록하지 않는다.