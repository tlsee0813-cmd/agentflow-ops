# Codex 총괄에서 DeepSeek DSH 호출

2026-10-23 기준 Windows에서 공식 `@deepseek-ai/dsh@0.2.1-rc.2` 설치, 버전·도움말·좁은 headless 프로필 부팅을 확인했다. 이후 사용자가 로컬에 API 키를 저장했고 **실제 역할 분류가 completed·exit 0으로 끝나 결과를 회수했다.** [실행 결과](../results/coordinator-harness-2026-10-23/RESULT.md). 계정 자동 전환과 관계없는 경로다.

## 호출

저장소 루트의 로컬 PowerShell에서 실행한다. Node 24 이상과 pnpm이 필요하다.

```powershell
pwsh -NoProfile -File ./scripts/dsh-install.ps1
node scripts/dsh-worker.mjs doctor
node scripts/dsh-worker.mjs run scripts/dsh-example-task.json
```

설치는 `.ops/dsh-runtime`에 격리한다. 저장소의 package.json/lockfile은 바꾸지 않으며 pnpm의 `--ignore-workspace`를 명시한다. 버전은 고정하고 생성된 로컬 `.ops/dsh-runtime/pnpm-lock.yaml`은 다음 설치부터 `--frozen-lockfile`로 재사용한다. 이 잠금 파일은 비공개 로컬 설치 상태이며 다른 머신에 동일한 전이 의존성 트리를 재현하려면 함께 보존해야 한다.

이 프로필은 셸·파일·웹·위임 도구를 비활성화하므로 설치 때 네이티브 등 lifecycle scripts를 공식 `--ignore-scripts` 옵션으로 생략한다. 일반 headless 또는 Web 전체 기능 설치를 보증하지 않는다. 실제 좁은 프로필은 이 상태에서 부팅되어 `MISSING_CREDENTIAL`까지 도달했다.

`doctor`는 자격증명 존재 여부만 출력하고 모델 요청을 보내지 않는다. 키가 없으면 `run`은 `authentication_required`, 종료 코드 3을 반환하며 upstream 작업을 시작하지 않는다.

## API 키 로컬 입력

이 노트북에는 사용자 요청으로 `.ops/dsh-home/.env` 빈 입력 파일과 사용자 전용 ACL을 만들었다. 편집기에서 `DEEPSEEK_API_KEY=` 뒤에 키를 넣고 저장할 수 있다. 키 원문을 채팅이나 공유 증거에 포함하지 않는다. 아래 숨김 콘솔 입력은 대안이다.

키를 채팅·명령 인자에 붙여넣지 않는다. 사용자가 별도 대화형 PowerShell 콘솔에서 다음을 실행한다.

```powershell
pwsh -NoProfile -File ./scripts/dsh-auth.ps1
```

`Read-Host -AsSecureString`으로 숨김 입력한다. `.ops/dsh-home/.env`에 저장하며 폴더와 파일의 상속 ACL을 제거하고 현재 Windows 사용자 SID만 접근하도록 설정한다. 파일은 로컬 평문이므로 해당 Windows 사용자 권한을 가진 프로그램은 읽을 수 있다. 저장소의 기존 `.ops/` 제외 규칙에 따라 Git에 포함되지 않는다. 입력 스크립트 자체는 API 요청을 하지 않는다.

위 예제는 기존 AGENTS 규약에서 역할 세 개를 분류하는 작은 실무 검증이며 이 노트북에서 최초 실제 실행을 완료했다. 새 총괄이 같은 연결 시험을 반복할 필요는 없다. 오류가 나면 같은 작업을 무조건 재전송하지 않고 결과와 원본 sessionId를 먼저 확인한다.

공식 headless는 실행 환경 → 실행 cwd의 `.env` → `DSH_HOME/.env` 순으로 키를 찾으며 GUI 저장 로그인은 기본적으로 사용하지 않는다. 이 어댑터는 cwd를 `.ops/dsh-workspace`, `DSH_HOME`을 `.ops/dsh-home`으로 고정하고 GUI·다른 프로필을 건드리지 않는다. 상속된 `DEEPSEEK_API_KEY`도 사용할 수 있다. 빈 환경변수는 `.env` fallback을 가리므로 제거해야 한다.

## 총괄이 전달하는 범위

작업 JSON은 `kind`(`extract`/`classify`/`draft`), `purpose`, `task`, `completionCriteria`가 필수이며 `input`에 필요한 텍스트만 넣는다. 파일을 자동으로 모으지 않는다. 예제는 [dsh-example-task.json](../scripts/dsh-example-task.json)이다. 같은 주제를 이어갈 때만 반환된 `sessionId`를 작업 JSON에 넣어 upstream의 `--session-id` 기능을 쓴다. 다른 주제는 생략한다.

공식 headless의 stdin·`--json`·세션 저장 기능을 사용한다. 별도 작업 큐·서버·watcher·범용 실행 엔진은 없다. [프로필 패치](../scripts/dsh-worker.patch.yml)는 모델을 `deepseek-flash`, thinking off, 출력 상한 2,048 tokens, 재시도 0으로 설정한다. 제목 생성용 추가 모델 요청도 비활성화했다. 입력 상한은 24 KiB, 실행 제한은 120초다. 이 제한은 공급자의 과금 영수증이 아니며 작업별 토큰·비용은 아직 계측하지 않았다.

기본 프로필에 있는 셸·파일·웹·위임 도구와 로컬 스킬·AGENTS 자동 로드를 패치에서 비활성화한다. 좁은 분류 워커에게 저장소 탐색이나 최종 보안·계정·통합 판단을 맡기지 않는다. 총괄이 결과를 검증하고 통합한다.

반환 JSON에는 `status`, `sessionId`, `turnReason`, `text`, `usage:null`, `resultPath`가 있다. 완료는 프로세스 exit 0, 원본 `turn_end.reason.kind=completed`, 비어 있지 않은 최종 답변이 모두 있어야 한다. `final` 이벤트만 있거나 error/aborted인 경우 성공으로 간주하지 않는다. 원본 세션과 정리된 결과는 `.ops/` 아래에 남는다. stderr는 자격증명이 섞일 수 있어 출력·저장하지 않으며 존재 여부만 반환한다. 공개 공유 전 총괄이 결과 본문을 검토한다.

## 실제 확인과 남은 검증

- 공식 master 조회 SHA: `687f282e8625c6b8d11ff58211a90524be2e4317`, npm latest: `0.2.1-rc.2` (`next`는 rc.3이며 사용하지 않음).
- Windows 고정 버전 설치 명령 최종 exit 0, 원본 `--version` 및 `headless --help` exit 0.
- 원본 headless + 이 패치의 실제 부팅: `session-3dbe7df1-e929-4cf4-a277-1c4aab2d56e4` 생성, session/turn/step 진행 후 `MISSING_CREDENTIAL`, 빈 final. 모델 응답 성공으로 세지 않는다.
- `node --test tests/dsh-worker.test.mjs`: 3개 통과. 실패/불완전 turn 성공 오판, 비밀 진단 유출 방지, 인증 존재 여부와 빈 환경변수 우선순위, 좁은 입력 제한을 검사했다. 실제 모델 시험과 구분한다.
- 첫 pnpm 시도는 빌드 미승인 상태로 exit 1이었다. 좁은 프로필의 불필요한 lifecycle scripts를 생략한 설치를 실행해 exit 0을 확인했다.
- 읽기용 upstream 전체 checkout은 Windows 긴 경로 fixture에서 일부 실패했다. 필요한 코드 경로만 복원해서 확인했으며 npm 배포물의 설치·실행과 구분한다.
- 사용자 로컬 API 키 입력 후 `session-bba6e7a5-0e44-40e1-a025-b3a506c08131`에서 실제 역할 분류 completed·exit 0, 비어 있지 않은 답변 회수까지 확인했다. 작업별 사용량은 미제공이며 절감률을 추정하지 않았다.

근거: [공식 저장소](https://github.com/deepseek-ai/deepseek-harness), [고정 SHA headless 계약](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/bundle/headless/README.md), [기본 구성](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/bundle/base/cordis.patch.yml), [공급자 설정](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/llm/llm-deepseek/src/config.ts).
