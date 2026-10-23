# 현재 상태

**2026-10-23 · 초기 OSS 조립과 연결 준비. 실제 계정 교체·전체 왕복 합격 전.**

## 완료한 것

- 제공된 6개 저장소와 추가 후보의 실제 소스·릴리스·라이선스 검토.
- QuotaCrew v0.3.0의 자동화 기능, codex-switch의 정상 종료 경로를 확인. QuotaCrew의 강제 종료·인증 저장소 설정 변경도 확인했으므로 계정 도구는 확정 전 비교 상태.
- 로컬 조립 폴더에 Oracle 0.22.0, mcporter 0.16.0, Chrome DevTools MCP 1.12.0 설치. 전역 설치·계정 변경은 수행하지 않음.
- Oracle의 모델 비연결 입력 렌더 exit 0.
- mcporter에서 Oracle MCP 도구 5개 조회 성공.
- 실제 consult dry run 성공: browser engine, gpt-6-pro, Pro effort, 기존 Chrome 연결, manualLogin=false, cookie copy 꺼짐, archive=never, 첨부 입력 확인.
- 현재 Codex CLI 0.163.0-alpha.11.2에서 Cloud 도움말과 실제 목록 조회 exit 0. root 필드는 tasks/cursor, 관찰한 목록은 비어 있음.
- 이 저장소에 AI 운영 지침·버전 고정·재사용 설정·기존 작업 비교표 정리.

## 미확인·제한

- QuotaCrew는 소스·배포 확인 단계. 설치·계정 등록·전환·재개 미실행. Windows 패키지 Codex 강제 종료, 인증 저장소 file 변경, 여러 한도 중단 대화 재개 가능성을 확인. Desktop/IDE 자동 재개는 실험적.
- Oracle live 질문·최종 답변 회수는 실행하지 않음. 기본 127.0.0.1:9222에는 classic DevTools 응답이 없었으나, 다른 포트·메타데이터 발견까지 실패했다고 판정하지 않음.
- Chrome DevTools MCP의 mcporter 경유 도구 조회는 기존 Chrome 소유권/정규 구성 정책에서 거절됨. 재시도하거나 제한을 끄지 않음. 실제 화면 연결 성공으로 기록하지 않음.
- 기존 브라우저 도구는 계속 사용. 추가 Chrome MCP 설정은 native MCP host용 참고 예시이며 기본 mcporter 설정에는 넣지 않음.
- Claude Code 실행 파일을 이 로컬 PATH와 일반 설치 위치에서 찾지 못함. 기존 다른 Claude 사용 환경은 유지.
- Cloud 새 작업 제출·완료·결과 회수는 미실행.
- DSH는 설치·실행하지 않음.

## 바로 다음 관문

**계정 도구의 실제 전환 품질을 먼저 비교하고, 이 노트북의 같은 총괄이 계정을 바꿔 이어갈 수 있는지 확인한다.** 이후 기존 Pro·Claude·Cloud·화면·GitHub 작업 비교를 마친다. 자체 계정 전환기·작업 큐·커스텀 실행기를 선행 개발하지 않는다.

설치 가능한 최신 버전과 이 노트북의 실제 성공 여부를 계속 구분해서 갱신한다. 연구 문서마다 현재 상태를 반복하지 않고 이 파일에 모은다.

계정 후보의 현재 우선 비교 순서와 종료·설정 변경 차이는 [ACCOUNT_DECISION_KO](ACCOUNT_DECISION_KO.md)를 따른다. CLI 허용 조건에서 Switchy의 열린 세션 routing을 먼저 비교하되 실제 전환 합격 전에는 자동 활성화하지 않는다.

