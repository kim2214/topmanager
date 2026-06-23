import 'dart:io';

import 'network_monitor_linux.dart';

/// 한 번의 네트워크 측정 결과. 초당 수신/송신 바이트(B/s)를 담는다.
///
/// [available]은 현재 플랫폼에서 네트워크 속도를 측정할 수 있는지 여부다.
/// 미지원(예: Windows)이면 false이고 속도는 0이다.
class NetworkUsage {
  final double rxBytesPerSec;
  final double txBytesPerSec;
  final bool available;

  const NetworkUsage({
    this.rxBytesPerSec = 0,
    this.txBytesPerSec = 0,
    this.available = false,
  });
}

/// 플랫폼별 네트워크 속도 수집기의 공통 인터페이스.
///
/// 속도는 한 시점 값이 아니라 두 샘플 사이의 누적 바이트 변화량을 경과 시간으로
/// 나눠 구한다. 주기적으로(예: 1초) 호출해야 한다.
abstract class NetworkMonitor {
  NetworkUsage sample();

  /// 현재 OS에 맞는 구현을 생성한다. CPU/RAM과 달리 미지원 플랫폼에서도
  /// 예외를 던지지 않고 "측정 불가"를 돌려주는 구현을 준다(다른 지표는 계속 동작).
  factory NetworkMonitor() {
    if (Platform.isLinux) return NetworkMonitorLinux();
    return const _UnsupportedNetworkMonitor();
  }
}

/// 네트워크 속도를 측정할 수 없는 플랫폼용 no-op 구현.
class _UnsupportedNetworkMonitor implements NetworkMonitor {
  const _UnsupportedNetworkMonitor();

  @override
  NetworkUsage sample() => const NetworkUsage(available: false);
}
