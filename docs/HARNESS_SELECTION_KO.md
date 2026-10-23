# 하네스 선택: 작업 분배부터 개선

2026-10-23 소스 조사와 통합 판단. 최신 main 확인은 설치·실사용 검증과 다르다. 사용자는 계정 테스트보다 하네스 개선을 우선했고 현재 Pro를 의도적으로 선택했다.

## 채택한 조합

기존 Codex 총괄 + Oracle의 비동기 세션 + 저장소 AGENTS.md와 작업별 짧은 지시/결과를 기본으로 쓴다. 총괄이 모든 조사·구현을 반복하는 부담을 먼저 줄인다. 새 조정 서버·대화 저장소·전송 큐는 추가하지 않는다.

| 후보 | 확인한 소스와 적합성 | 선택 |
|---|---|---|
| js-jony-k/codex-harness | 0.3.0, SHA 0e6c758698186ee52b6589d984f7a545cb96f2b3, LICENSE는 Apache-2.0. 기본 lean, 최대 worker/depth/retry/summary 제한, 관련 문서만 읽는 구조. model_routing은 지침이며 실제 모델 전환 기능이 아님 | 좁은 위임·짧은 결과·필요한 검증 원칙 채택. 전체 plugin/factory는 아직 설치하지 않음 |
| Superpowers | 작업별 문맥 전달과 구현 검증 규율. 다단계 리뷰를 매 작업에 적용하면 호출이 증가할 수 있음 | 작업 경계/증거 중심 전달을 선택적으로 참고. 전체 workflow 적용 안 함 |
| Oracle | 이미 설치된 0.22.0의 native session/wait/harvest. 긴 웹 Pro 응답을 별도 새 요청 없이 회수하는 데 적합 | 왕복 우선 경로 유지. 실제 연결 시험은 별도 관문 |
| chatgpt-browser-channel | 전송 영수증과 불확실한 전송 처리, 모델 증거 구분 | 설계 참고. Linux/비공개 인터페이스 의존성을 이유로 Windows 기본 경로 교체 보류 |
| BrowserChatBridge | 실제 탭의 ChatGPT/Gemini 어댑터와 MCP | 별도 대안. Claude/Cloud까지 지원한다고 확대하지 않음 |
| RTK | 출력 압축 및 Codex hook 코드. 최신 develop SHA 8554743d9f7e5159b69b39a0bb334c42382f4215. README는 Apache-only OSS판과 BUSL 포함판을 구분함 | 보조 후보. 현재 PowerShell exec에 hook이 적용되는지 미확인, 전역 hook 미설치 |
| Austin1serb/agents-md | SHA dcfb2aa20a325ead0f4f3d8ff20370dabdb17691. 좁은 검색과 출력 제한 중심. repo license 파일 미발견 | 일반 원칙만 참고해 새 문장 작성. 파일 복제·시스템 프롬프트 교체 안 함. 개인의 50% 절감 주장은 미채택 |

RTK가 줄이는 것은 주로 명령 출력이며 총 사용 한도와 같지 않다. 최신 개발 브랜치가 더 안전한 배포판이라는 결론도 내리지 않는다. 소스와 공개 README의 실제 지원 범위를 함께 읽고 해당 환경에서 검증해야 한다.

## 우리 환경에 맞춘 차이

Codex 보조 담당을 늘리는 것만으로는 같은 계정 사용량을 외부로 분산하지 못한다. 이미 가진 웹 Pro·Claude 환경으로 독립 작업을 보내는 것이 핵심이다. Cloud도 어떤 계정을 쓰는지에 따라 한도를 공유할 수 있다. 연결이 막힌 채널은 작동한다고 적지 않고 사용 가능한 경로로 진행한다.

내장 보조 모델은 사용자 지정 gpt-6.1-sol high가 기본, gpt-6-astra high는 중요한 설계와 판단에 한정한다. 메인 모델은 사용자의 선택을 그대로 둔다. 직접 보조 호출 시 필요한 경우 새 문맥에 좁은 지시를 주며, 전체 총괄 기록을 각 worker에게 복제하지 않는다.

도입 효과는 다음 실제 제품 작업의 결과·재시도·소요 시간·제공되는 usage로 판단한다. 설치 개수, 문서 길이, 여러 AI가 동의한 수를 성과로 삼지 않는다.

## 확인한 원문

- [Codex Harness routing](https://github.com/js-jony-k/codex-harness/blob/0e6c758698186ee52b6589d984f7a545cb96f2b3/plugins/codex-harness/skills/codex-harness/references/routing.md), [budget template](https://github.com/js-jony-k/codex-harness/blob/0e6c758698186ee52b6589d984f7a545cb96f2b3/plugins/codex-harness/skills/codex-harness/assets/project-template/harness.json), [LICENSE](https://github.com/js-jony-k/codex-harness/blob/0e6c758698186ee52b6589d984f7a545cb96f2b3/LICENSE).
- [RTK README](https://github.com/rtk-ai/rtk/blob/8554743d9f7e5159b69b39a0bb334c42382f4215/README.md), [Codex hook installer](https://github.com/rtk-ai/rtk/blob/8554743d9f7e5159b69b39a0bb334c42382f4215/src/hooks/init/codex.rs).
- [AGENTS patterns](https://github.com/Austin1serb/agents-md/blob/dcfb2aa20a325ead0f4f3d8ff20370dabdb17691/AGENTS.md).
- [조정 계층 조사](HARNESS_COORDINATION_RESEARCH.md), [브라우저 왕복 조사](HARNESS_CHANNEL_RESEARCH.md): 각 source SHA·라이선스·채택과 보류 이유.
