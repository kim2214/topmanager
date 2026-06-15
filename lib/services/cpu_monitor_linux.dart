import 'dart:io';

import 'cpu_monitor.dart';

/// /proc/stat을 읽어 전체 CPU 사용률을 계산하는 Linux 구현.
///
/// /proc/stat의 첫 줄("cpu ...")은 부팅 이후 누적된 CPU 시간을 USER_HZ 단위로
/// 담고 있다(필드: user nice system idle iowait irq softirq steal guest
/// guest_nice). Windows의 GetSystemTimes와 마찬가지로 한 시점 값이 아니라
/// 두 샘플 사이의 변화량으로 사용률을 구한다.
class CpuMonitorLinux implements CpuMonitor {
  // 직전 샘플. 첫 호출 전에는 null.
  int? _prevTotal;
  int? _prevIdle;

  @override
  double getCpuUsage() {
    final line = _readCpuLine();
    if (line == null) return 0;

    // "cpu" 라벨을 떼고 숫자만 추출.
    final parts =
        line
            .split(RegExp(r'\s+'))
            .skip(1)
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList();
    if (parts.length < 5) return 0;

    // idle = idle(3) + iowait(4). 나머지를 모두 더한 값이 전체 시간.
    final idle = parts[3] + parts[4];
    final total = parts.reduce((a, b) => a + b);

    // 첫 샘플: 기준점만 저장하고 0 반환.
    if (_prevTotal == null) {
      _prevTotal = total;
      _prevIdle = idle;
      return 0;
    }

    final totalDelta = total - _prevTotal!;
    final idleDelta = idle - _prevIdle!;

    _prevTotal = total;
    _prevIdle = idle;

    if (totalDelta <= 0) return 0;
    final busy = totalDelta - idleDelta;
    return (busy / totalDelta * 100).clamp(0, 100).toDouble();
  }

  // /proc/stat의 첫 줄(전체 CPU 누적치)을 읽는다. 읽기에 실패하면 null.
  String? _readCpuLine() {
    try {
      final content = File('/proc/stat').readAsStringSync();
      final newline = content.indexOf('\n');
      return newline == -1 ? content : content.substring(0, newline);
    } catch (_) {
      return null;
    }
  }
}
