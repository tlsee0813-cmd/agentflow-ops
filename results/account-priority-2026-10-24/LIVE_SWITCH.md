# 실제 계정 전환과 동일 대화 재개

2026-10-24 KST. 시험 ID `AF-LIVE-SWITCH-20261024-206dff6c`. 사용자 요청으로 현재 Pro에서 첫 번째 Business 사용자로 원본 Codex Switch 전환을 한 번 실행했다. 한도 소진을 꾸민 시험이 아니라 명시적인 실제 전환 시험이다.

## 확인한 결과

- 전송 전 별도 claim을 저장했고 기존 불확실 요청을 재전송하지 않았다.
- 새 원본 receipt의 ID·시각·목표 계정이 이번 claim과 일치했다. canonical 계정도 목표 Business 사용자와 일치했다.
- `AccountApplied=true`, `phase=Finished`, `chats=1`, `resumed=1`, `unconfirmed=0`, `failed=0`, 오류 없음, PendingSwitch 없음.
- 같은 root UUID가 active로 돌아왔고 재개된 총괄이 실제 셸·GitHub·브라우저 도구 호출을 실행했다. 단순 Continue 접수만으로 성공 처리하지 않았다.
- 전환 전후 모델/도구 설정 해시, Git HEAD, 지정한 Ops 채널 설정·실행 파일 해시가 일치했다. Git 작업 트리도 깨끗했다.
- GitHub connector로 main `b2d7dbc7909962691a1fc9dd9927732d511c78f3` 조회 성공.
- Oracle의 기존 `st-233533-34c50d-pro` 완료 기록 조회 성공. 새 Pro 질문은 보내지 않았다.
- Claude 기존 작업 URL을 다시 열어 로그인 유지와 기존 최종 답변 회수를 확인했다. 전환 후 최초 IAB 목록은 빈 상태였으므로 탭 자체가 보존됐다는 주장은 하지 않는다.
- DSH doctor에서 설치 버전·비공개 키 존재를 확인했다. 이번에는 추가 모델 요청을 하지 않았다.

## 별도로 남는 검증

이 결과는 **계정 전환 → 앱 재시작 → 같은 대화의 자동 재개** 성공이다. 자연 한도 소진 감지, 두 Business 연속 소진, Plus 크레딧 대체, 실제 Business 회복 후 복귀까지 실계정으로 반복했다고 확대하지 않는다.

별도 stdio app-server의 저장 이력 조회는 진행 중인 Desktop owner의 상태와 달랐다. monitor에는 active만 있고 최신 턴 ID·상태가 없었다. Work 방식 자체의 미지원으로 단정한 이전 설명은 정정한다. 지원된 owner history hydration 1회도 실패해 재시도하지 않았다. 감시 활성화의 최신 상태는 `docs/STATUS.md`를 따른다.

개인 계정 Key·인증·원본 vault·개인 경로가 포함된 claim과 원본 receipt는 GitHub에 올리지 않는다. 공개 결과는 위 대조 항목만 남긴다.

## 이후 실제 한도 사건

같은 날 첫 번째 Business의 5시간 사용량 100%와 ordinary usage 불가를 원본 캐시에서 확인했다. 사용자가 두 번째 Business로 수동 전환했고, 현재 계정 일치와 PendingSwitch 없음도 확인했다. 당시 자동 감시는 꺼져 있었으므로 이 사건을 자동 전환 성공으로 세지 않는다. 자동 감시의 호환 수정 및 활성화는 별도 결과로 기록한다.
## 감시 활성화

2026-10-24 00:41 KST에 live owner 호환을 수정한 실행기를 활성화했다. `CheckOnly`에서 secondary/current exhaustion 대기를 확인한 뒤 명시 기동했다. `enabled=true`, 예약 작업 `Running`, 시작 트리거 0개, 현재 UUID 일치, 관찰 계정 secondary 일치, 실제 턴 ID 존재, ambiguous=false, transition 없음, 비공개 설정 ACL 보호를 확인했다.

합성 실행기·snapshot 검사 58개와 정책 검사 26개를 작성자와 독립 검토자가 통과했다. 독립 검토 범위에서 미해결 P1/P2 없음. 실제 live snapshot은 canonical 최신 턴을 active/inProgress로 관찰했고 약 5.1 MiB·1초였다. 30초 주기의 로컬 IPC 읽기이며 대화 원문을 모델이나 디스크에 넣지 않는다. 실제 한도 사건 이후 자동 전환·재개까지 성공했다는 최종 표시는 해당 사건의 receipt 확인 뒤에만 한다.