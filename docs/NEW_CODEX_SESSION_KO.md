# Codex 앱의 새 총괄 세션

이 하네스는 Codex 앱 총괄이 읽는 개인 스킬과 기존 Ops 실행 도구의 조합이다. 워커들을 별도 총괄로 만들거나 상주 서버를 추가하지 않는다.

## 이 노트북에서

1. Codex 앱에서 실제 작업할 프로젝트(예: AgentFlow Studio)를 선택해 새 로컬 세션을 연다. Ops 도구를 개선할 때만 agentflow-ops 폴더를 선택한다.
2. 아래 시작 문장을 보낸다. 개인 스킬은 현재 Ops runtime 경로를 기억하므로 제품 폴더에 스크립트·브라우저 프로필을 복사할 필요가 없다.

> $agentflow-coordinator 를 사용해 이 프로젝트의 총괄을 맡아줘. 현재 GitHub 상태와 미완료 작업부터 확인하고, 목표·범위를 잡아 Pro 조사, Claude 구현, 준비된 검증 채널, DeepSeek 추출 작업을 필요한 만큼 배정해줘. 결과는 네가 판단하고 통합해. 계정 운영은 현재 운영 문서와 대상 thread 설정을 확인하고 임의로 변경하지 마. 기존 외부 로그인은 유지해. 이번에 할 일: [원하는 결과].

스킬이 목록에서 보이지 않으면 같은 노트북의 `.codex/skills/agentflow-coordinator/SKILL.md`를 읽으라고 명시한다. 앱 버전에 따른 스킬 목록 갱신까지 실제 새 앱 세션에서 확인한 것은 아니다. 기존 세션의 대화 전체를 붙여 넣을 필요는 없다.

## 설치/갱신

기존 Ops runtime checkout에서 `node scripts/install-coordinator-skill.mjs`를 한 번 실행한다. `$CODEX_HOME/skills` 또는 기본 사용자 `.codex/skills`의 이 스킬만 설치한다. 같은 runtime의 재설치는 가능하며 다른 설치의 스킬을 덮어쓰지 않는다. runtime.json에는 로컬 경로·Node 실행 경로만 저장하고 자격증명은 넣지 않는다.

Pro는 로그인된 기존 runtime의 전용 Chrome 프로필을 그대로 쓴다. Claude·화면 조작은 새 총괄 세션에 브라우저 도구가 제공되어야 한다. GitHub 도구도 새 세션에서 접근 가능해야 한다. 스킬 설치가 플러그인 권한이나 로그인을 자동으로 생성하지는 않는다. 해당 도구가 없을 때만 필요한 연결을 알린다.

진행 중 작업과 기존 세션은 [COORDINATOR_STATE](COORDINATOR_STATE.md), 실제 채널 준비 상태는 [STATUS](STATUS.md), 상세 분배 기준은 [HARNESS_RUNBOOK](HARNESS_RUNBOOK_KO.md)에 있다. 모두 한꺼번에 읽지 않는다.
