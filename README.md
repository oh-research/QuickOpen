# QuickOpen

<p align="center">
  <img src="quickopen_icon.svg" width="128" alt="QuickOpen icon">
</p>

> Finder에서 파일/폴더를 원하는 앱으로 즉시 여는 macOS 유틸리티

Finder에서 선택한 파일을 특정 앱으로 열거나, 현재 Finder 위치에서 앱을 실행하려면 여러 단계를 거쳐야 합니다. QuickOpen은 키보드 단축키, 마우스 클릭, 트랙패드 제스처를 트리거로 등록해 한 번의 동작으로 원하는 앱을 실행합니다.

## 특징

- **키보드 단축키** — 글로벌 핫키로 선택한 파일을 원하는 앱에서 열기
- **마우스 클릭** — Modifier + 클릭(싱글/더블/우클릭)으로 트리거
- **트랙패드 제스처** — Modifier + Force Click / Two Finger Tap 지원
- **두 가지 액션** — 선택한 파일 열기(Open File) / 현재 위치에서 앱 실행(Open at Location)
- **파일 확장자 필터** — 특정 확장자만 매칭하도록 제한 가능
- **다중 매핑** — 트리거-앱 조합을 여러 개 등록하여 자유롭게 구성
- **일괄 ON/OFF** — 메뉴바의 Enable 토글로 모든 트리거를 한 번에 일시 정지
- **메뉴바 앱** — Dock 아이콘 없이 메뉴바에서만 동작
- **로그인 시 자동 실행** 지원
- 외부 의존성 없음 (순수 Swift + AppKit + SwiftUI)

## 설치

### Homebrew (추천)

```bash
brew tap oh-research/tap
brew install --cask quickopen
```

### 수동 설치

1. [Releases](https://github.com/oh-research/QuickOpen/releases)에서 `.dmg` 다운로드
2. `QuickOpen.app`을 `/Applications`로 드래그
3. 최초 실행 전 Gatekeeper 우회:
   ```bash
   xattr -cr /Applications/QuickOpen.app
   ```
4. 앱을 실행하면 **How to Use** 창이 자동으로 열려 사용법과 권한 설정을 안내합니다

## 메뉴

메뉴바 아이콘을 클릭하면 다음 항목이 표시됩니다:

- **Enable** — 모든 트리거를 일괄 ON/OFF (체크마크로 현재 상태 표시)
- **Settings...** — 매핑 추가/편집 및 일반 설정 창 (⌘,)
- **How to Use...** — 사용법 + 권한 설정 창
- **About QuickOpen** — 버전·개발자·GitHub 링크 창
- **Quit QuickOpen** — 종료 (⌘Q)

메뉴바 아이콘은 앱 상태에 따라 바뀝니다:

- **정상** — 두 사각형 겹친 커스텀 아이콘 (QuickOpen 정체성)
- **권한 필요** — `⊘` 모양 느낌표 원. Accessibility 또는 Automation 권한을 부여하면 정상 아이콘으로 자동 복귀

## 사용법

### 매핑 설정

1. 메뉴바 아이콘 > **Settings...** 를 엽니다
2. **Triggers** 탭에서 **+** 버튼으로 새 매핑을 추가합니다
3. 트리거 유형(키보드/마우스/트랙패드), 대상 앱, 액션 유형을 설정합니다

### 트리거 예시

| 트리거 | 액션 |
|--------|------|
| `⌃⌥ + Double Click` | Finder에서 선택한 파일을 VS Code로 열기 |
| `⌘⇧V` | 선택한 파일을 VS Code로 열기 |
| `⌃⌥ + Force Click` | 현재 Finder 위치에서 터미널 실행 |

### 액션 유형

- **Open File** — Finder에서 선택한 파일을 지정 앱으로 엽니다
- **Open at Location** — 현재 Finder 윈도우의 디렉토리에서 앱을 실행합니다

## 권한

QuickOpen은 두 가지 macOS 권한이 필요합니다:

- **손쉬운 사용(Accessibility)** — 글로벌 키보드 단축키, 마우스 클릭, 트랙패드 제스처 감지에 필요
- **자동화(Automation)** — Finder와 통신하여 선택된 파일 및 현재 디렉토리 정보를 가져오는 데 필요

첫 실행 시 **How to Use** 창에서 권한 설정을 안내합니다. "Grant Access" 버튼을
클릭하면 시스템 설정의 해당 권한 페이지가 바로 열립니다.

## 설정

메뉴바 아이콘 > **Settings...** 에서 변경할 수 있습니다 (⌘,):

- **Triggers 탭** — 트리거-앱 매핑 추가/수정/삭제, 파일 확장자 필터
- **General 탭** — 로그인 시 자동 실행 토글

## 소스에서 빌드

macOS 14+ 및 Xcode가 필요합니다.

```bash
git clone https://github.com/oh-research/QuickOpen.git
cd QuickOpen
xcodebuild -scheme QuickOpen -configuration Debug build
```

## 요구 사항

- macOS 14.0 (Sonoma) 이상

## 삭제

### Homebrew

```bash
brew uninstall --cask quickopen
```

### 수동 삭제

```bash
rm -rf /Applications/QuickOpen.app
```

## 기술 스택

- **Swift + AppKit** — 이벤트 감지, 앱 실행
- **SwiftUI** — 설정 UI, 온보딩
- **CGEventTap** — 마우스/modifier 이벤트 수신
- **NSEvent pressure monitor** — Force Touch 감지
- **AppleScript (NSAppleScript)** — Finder 선택 항목 및 디렉토리 조회
- **Xcode** — 프로젝트 빌드

## 라이선스

MIT License
