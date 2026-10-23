# 초기 조립 결과 · 2026-10-23

## 목적

계정 교체와 기존 작업 유지에 도움이 되는 기존 OSS를 골라 AI가 사용하는 CLI/MCP 설정으로 연결한다. 별도 실행기·watcher·세션 저장소를 개발하지 않는다.

## 실제 관찰

| 항목 | 결과 | 의미 |
| --- | --- | --- |
| Oracle 0.22.0 설치 | 성공 | 프로젝트 로컬 의존성, 전역 설치 아님 |
| mcporter 0.16.0 설치 | 성공 | 자체 MCP client 대신 기존 CLI 사용 |
| Chrome DevTools MCP 1.12.0 설치 | 성공 | 도구 설치와 실제 Chrome 연결은 별도 |
| Oracle browser 입력 렌더 | exit 0 | 모델에 전송하지 않는 입력 조립 |
| Oracle MCP schema | 5 tools | consult, chatgpt_image, project_sources, sessions, wait |
| Oracle consult dry run | status=dry-run | browser engine, gpt-6-pro, thinking=pro, manualLogin=false, attach-existing, archive=never |
| 기존 Chrome 기본 포트 조회 | classic 응답 없음 | 127.0.0.1:9222 한 곳의 관찰, 다른 발견 경로 미판정 |
| mcporter 경유 Chrome 정의 | 거절 | 정규 기존 Chrome 소유권 정책. 재시도·정책 해제 안 함 |
| Codex Cloud 목록 조회 | exit 0, tasks/cursor | 관찰한 목록 0개, 제출·완료·결과 회수 미검증 |

Node v24.22.1, Codex CLI 0.163.0-alpha.11.2, pnpm 11.25.0 환경에서 확인했다. 원본 로그의 로컬 사용자 경로·계정 상태는 공개 결과에 복사하지 않았다.

## 판단

Oracle와 mcporter는 기존 기능으로 입력 준비와 도구 호출까지 연결됐다. 실제 Pro 질문·최종 답변 회수까지 성공했다고 판정하지 않는다. Chrome 연결은 현재 CUA 경로를 유지한다.

계정 도구는 기능 수보다 실제 교체 품질을 우선한다. QuotaCrew 자동화, codex-switch 정상 종료, Switchy 열린 세션 routing을 비교하며 실제 로컬 전환 전까지 자동 활성화하지 않는다. 자격증명을 직접 열람·출력하거나 로그인 상태를 변경하지 않았다.

## 다음 확인

계정 도구로 같은 총괄의 실제 교체·재개를 먼저 확인하고, 기존 Pro·Claude·Cloud·화면·GitHub 흐름을 docs/COMPARISON_KO.md와 대조한다. 제품 소스 변경이나 배포를 이 준비 완료와 혼동하지 않는다.
