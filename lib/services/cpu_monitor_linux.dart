import 'dart:io';

import 'package:flutter/foundation.dart';

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
    final content = _readStat();
    if (content == null) return 0;

    final sample = parseCpuLine(content);
    if (sample == null) return 0;

    // 첫 샘플: 기준점만 저장하고 0 반환.
    if (_prevTotal == null) {
      _prevTotal = sample.total;
      _prevIdle = sample.idle;
      return 0;
    }

    final usage = computeUsage(
      prevTotal: _prevTotal!,
      prevIdle: _prevIdle!,
      total: sample.total,
      idle: sample.idle,
    );

    _prevTotal = sample.total;
    _prevIdle = sample.idle;
    return usage;
  }

  /// /proc/stat 내용에서 전체 CPU 누적치를 파싱한다(파일 I/O 없는 순수 함수).
  ///
  /// 첫 줄 "cpu user nice system idle iowait irq softirq ..."에서
  /// idle = idle + iowait, total = 모든 필드 합. 파싱 실패 시 null.
  @visibleForTesting
  static ({int total, int idle})? parseCpuLine(String content) {
    final newline = content.indexOf('\n');
    final line = newline == -1 ? content : content.substring(0, newline);

    final parts = line
        .split(RegExp(r'\s+'))
        .skip(1) // "cpu" 라벨 제거
        .where((s) => s.isNotEmpty)
        .map(int.tryParse)
        .toList();
    if (parts.length < 5 || parts.any((p) => p == null)) return null;

    final values = parts.cast<int>();
    final idle = values[3] + values[4];
    final total = values.reduce((a, b) => a + b);
    return (total: total, idle: idle);
  }

  /// 두 샘플의 변화량으로 사용률(0~100%)을 계산한다(순수 함수).
  @visibleForTesting
  static double computeUsage({
    required int prevTotal,
    required int prevIdle,
    required int total,
    required int idle,
  }) {
    final totalDelta = total - prevTotal;
    final idleDelta = idle - prevIdle;
    if (totalDelta <= 0) return 0;
    final busy = totalDelta - idleDelta;
    return (busy / totalDelta * 100).clamp(0, 100).toDouble();
  }

  // /proc/stat을 읽는다. 읽기에 실패하면 null.
  String? _readStat() {
    try {
      return File('/proc/stat').readAsStringSync();
    } catch (_) {
      return null;
    }
  }
}
