import 'dart:io';

import 'cpu_monitor_ffi.dart';
import 'cpu_monitor_linux.dart';

/// 플랫폼별 CPU 사용률 수집기의 공통 인터페이스.
///
/// Windows는 kernel32.dll의 GetSystemTimes를 FFI로 호출하고(Win32 전용),
/// Linux는 /proc/stat을 읽는다. UI/ViewModel은 이 인터페이스만 알면 되며,
/// 어떤 OS인지는 [CpuMonitor] 팩토리가 알아서 골라준다.
abstract class CpuMonitor {
  /// 전체 CPU 사용률(0~100%)을 반환한다.
  ///
  /// 사용률은 한 시점 값이 아니라 두 샘플 사이의 변화량이라, 첫 호출은
  /// 기준점만 저장하고 0을 돌려준다. 주기적으로(예: 1초) 호출해야 한다.
  double getCpuUsage();

  /// 현재 OS에 맞는 구현을 생성한다.
  factory CpuMonitor() {
    if (Platform.isWindows) return CpuMonitorFfi();
    if (Platform.isLinux) return CpuMonitorLinux();
    throw UnsupportedError(
      'CPU 모니터링을 지원하지 않는 플랫폼입니다: ${Platform.operatingSystem}',
    );
  }
}
