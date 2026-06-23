# topmanager

Flutter 데스크톱으로 만든 **시스템 리소스 모니터**입니다. CPU(전체 + 코어별)와
RAM 사용률을 1초마다 갱신하며, 작업 관리자처럼 오른쪽에서 왼쪽으로 흐르는
실시간 그래프로 보여줍니다.

## 주요 기능

- **CPU 사용률** — 전체 평균(0~100%)과 **코어별** 사용률
- **RAM 사용량** — 사용 중 / 전체 (GB)
- **실시간 그래프** — 최근 60초 히스토리를 면적 그래프로 표시 (외부 차트 패키지 없이 `CustomPainter`로 직접 그림)

## 지원 플랫폼

| 플랫폼 | RAM | CPU 전체 | CPU 코어별 | 수집 방식 |
|--------|:---:|:-------:|:---------:|-----------|
| **Linux** | ✅ | ✅ | ✅ | `/proc/meminfo`, `/proc/stat` 직접 읽기 |
| **Windows** | ✅ | ✅ | ❌ | RAM은 MethodChannel(C++ `GlobalMemoryStatusEx`), CPU는 FFI(`kernel32.dll` `GetSystemTimes`) |
| macOS | — | — | — | 미지원 (실행 시 안내 메시지 표시) |

## 아키텍처

```
[UI] main.dart
  └─ ListenableBuilder
       │
[ViewModel] SystemMonitorNotifier (ChangeNotifier)
  ├─ Timer.periodic(1초)
  ├─ SystemMonitorService  ── RAM ── (Win) MethodChannel → C++  /  (Linux) /proc/meminfo
  └─ CpuMonitor            ── CPU ── (Win) FFI GetSystemTimes   /  (Linux) /proc/stat
       │
[Widget] UsageChart / _PerCoreGrid  ← cpuHistory / ramHistory / perCoreUsage
```

CPU 수집기는 `CpuMonitor` 인터페이스 뒤에 OS별 구현(`CpuMonitorFfi`, `CpuMonitorLinux`)을
숨기고 팩토리로 주입합니다. 사용률은 한 시점 값이 아니라 **두 샘플 사이의 변화량(delta)**
으로 계산합니다.

## 실행 방법

### Linux (Debian/Ubuntu)

데스크톱 빌드 툴체인이 필요합니다:

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev mesa-utils
```

설치 후 실행:

```bash
flutter pub get
flutter run -d linux
```

### Windows

```bash
flutter pub get
flutter run -d windows
```

## 개발

```bash
flutter analyze   # 정적 분석
flutter test      # 단위 + 위젯 테스트
```

`/proc` 파싱과 CPU delta 계산 로직은 파일 I/O와 분리된 순수 함수
(`parseMeminfo`, `parseCpuLine`, `parsePerCore`, `computeUsage`)로 작성되어
OS 없이도 단위 테스트할 수 있습니다.

### CI

`master` push와 PR마다 GitHub Actions가 `flutter analyze`와 `flutter test`를
자동 실행합니다 (`.github/workflows/ci.yml`).

## 환경

- Flutter 3.32.0 / Dart SDK ^3.7.2
