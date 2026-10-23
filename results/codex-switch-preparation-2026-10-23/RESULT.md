# Codex Switch Windows portable 준비

2026-10-23. Gaebabi의 원본 Windows portable 배포본 전체를 사용자 로컬의 전용 도구 폴더에 배치했다. 이 기록은 파일 준비와 정적 무결성 확인이며, 앱 실행·계정 등록·전환의 성공 기록이 아니다.

## 배포본과 소스

| 항목 | 확인값 |
| --- | --- |
| 원본 | [Gaebabi/codex-switch](https://github.com/Gaebabi/codex-switch) |
| 배포 버전 | [v1.41.1](https://github.com/Gaebabi/codex-switch/releases/tag/v1.41.1) |
| release tag의 commit | `bfd96517e08d9e697c201ae7dc11588e12763c51` |
| 배포 manifest의 실제 build source | `98af9e4687d26bcc14198d8adc71922f0ca46d89` |
| 별도로 검토한 main | `2779bfc135e4b3a2c9b7ab1141938c0605ac8e2c` |
| main과 release 차이 | main이 한 commit 앞섬. Windows 실행 버전 표시 변경이며 해당 소스로 다시 빌드하지 않음 |
| 라이선스 | MIT |
| 설치 방식 | 원본 ZIP 전체 압축 해제 후 전용 `CodexSwitch-1.41.1` 폴더에 배치 |
| 원본 portable 파일 수 | 493개; 별도로 만든 로컬 설치 영수증은 이 수에 포함하지 않음 |

실제 EXE와 DLL의 ProductVersion은 `1.41.1+98af9e4687d26bcc14198d8adc71922f0ca46d89`다. release tag, 배포 manifest의 build source, 검토한 main을 같은 SHA로 표현하지 않는다. [원본 VERIFICATION.json](https://github.com/Gaebabi/codex-switch/releases/download/v1.41.1/VERIFICATION.json)과 대조했다.

## 실제 무결성 확인

| 파일 | bytes | SHA-256 |
| --- | ---: | --- |
| `CodexSwitch-v1.41.1-win-x64.zip` | 75,776,014 | `4484e440d53964bfa34f1bb0b3b9fd9a6a2901a6025cb684c21927b519184da1` |
| `CodexSwitch.exe` | 193,024 | `7d6ec6782c968c23380979dc5a50bc687d63c4a5fa255e0e5556b12a50c21059` |
| `CodexSwitch.dll` | 526,848 | `aea08e075ab404ca281985f39ac293b3cbca082fb8f63f813c1f80ec4f4d21e0` |
| `CodexSwitch.Application.dll` | 143,360 | `a8b50f87cffaf7e18b27656f012f469a92b05b35526e5ff8b6b06561be50793b` |
| `CodexSwitch.Core.dll` | 421,888 | `a5094dd749fc533581257eaeea854f69c20ae59a480056032624523086f4d9c3` |
| `CodexSwitch.PlatformSecurity.dll` | 56,832 | `c51ef9eaae7e7723af03c297e120f4f901f67559977b7c6166c658cb30d516a1` |

ZIP의 크기와 SHA-256은 GitHub release asset의 digest 및 원본 [체크섬 목록](https://github.com/Gaebabi/codex-switch/releases/download/v1.41.1/SHA256SUMS.txt)과 일치했다. EXE 해시는 앞선 release ZIP의 메모리 조회 값과 실제 배치된 파일에서 다시 확인했다. DLL 해시는 배치 후 관찰값이다. 위 EXE와 네 DLL의 FileVersion은 모두 `1.41.1.0`, Authenticode 상태는 모두 `NotSigned`였다. 체크섬 일치는 배포 바이트의 무결성 확인이며 서명된 게시자 신원 검증으로 확대하지 않는다.

배포본의 `CodexSwitch.runtimeconfig.json`에서 `net10.0`과 포함된 `Microsoft.NETCore.App 10.0.13`, `Microsoft.WindowsDesktop.App 10.0.13`을 확인했다. 전역 .NET 설치를 하지 않았다. 설치 폴더의 로컬 `INSTALL_RECEIPT.json`에도 버전·소스·해시·파일 메타데이터를 보관했다.

## 수행 범위와 미실행

수행한 작업은 원본 ZIP 다운로드, 크기·해시 확인, 전체 portable 압축 해제·배치, 파일 버전·해시·서명 상태와 runtime 설정 읽기다. 경로를 옮기기 전 원본과 대상이 지정한 도구 준비 범위 안에 있는지 확인했다. 이전에 삭제가 거부된 임시 폴더는 건드리지 않았다.

다음은 이 준비에서 실행하지 않았다.

- EXE 또는 DLL의 실행·로드, GUI, 상위 도움말과 진단 모드
- 현재 로그인 import, 프로필 경로 import, 로그인, quota 조회, 계정 전환
- Codex나 다른 프로세스 종료·재시작, 자동 시작 등록
- main auth/config 파일 조작, 인증 저장소 열람·복호화·복사
- 원본 소스 수정·빌드, 자체 실행기나 adapter 작성

원본 Windows 옵션은 등록용 CLI를 제공하지 않는다. [Program.cs](https://github.com/Gaebabi/codex-switch/blob/bfd96517e08d9e697c201ae7dc11588e12763c51/src/windows/Program.cs)의 옵션을 검토했고, 도움말이라고 가정해 실행하지 않았다. 원본의 현재 로그인 가져오기는 GUI의 새로 고침 우클릭 메뉴이고 추가 로그인은 **+** 경로다. QuotaCrew DPAPI 저장소를 가져오는 원본 지원 경로는 확인하지 못했다. [원본 사용 안내](https://github.com/Gaebabi/codex-switch/blob/bfd96517e08d9e697c201ae7dc11588e12763c51/README.md)

실제 두 사용자 구분, 현재 계정 import, 로그인 재사용, Desktop 내부 identity와 전환 후 작업 연속성은 이 portable 준비와 구분해 후속 검증해야 한다. 이 단계에서 사용자에게 재로그인을 요청하거나 인증 절차를 시작하지 않았다.
