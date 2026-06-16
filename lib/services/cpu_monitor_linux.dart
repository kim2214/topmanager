import 'dart:io';

import 'package:flutter/foundation.dart';

import 'cpu_monitor.dart';

/// /proc/stat을 읽어 전체 + 코어별 CPU 사용률을 계산하는 Linux 구현.
///
/// /proc/stat의 "cpu" 줄은 전체 합산, "cpu0"/"cpu1"... 줄은 코어별 누적
/// CPU 시간(USER_HZ 단위)이다(필드: user nice system idle iowait irq softirq
/// steal guest guest_nice). Windows의 GetSystemTimes와 마찬가지로 한 시점
/// 값이 아니라 두 샘플 사이의 변화량으로 사용률을 구한다.
class CpuMonitorLinux implements CpuMonitor {
  // 전체(cpu 줄)의 직전 샘플. 첫 호출 전에는 null.
  int? _prevTotal;
  int? _prevIdle;

  // 코어별(cpuN 줄)의 직전 샘플. 키는 코어 번호.
  final Map<int, ({int total, int idle})> _prevCores = {};

  @override
  CpuUsage sample() {
    final content = _readStat();
    if (content == null) return const CpuUsage(total: 0);

    return CpuUsage(
      total: _sampleTotal(content),
      perCore: _samplePerCore(content),
    );
  }

  // 전체 사용률을 계산하고 직전 샘플을 갱신한다.
  double _sampleTotal(String content) {
    final agg = parseCpuLine(content);
    if (agg == null) return 0;

    final prevTotal = _prevTotal;
    final prevIdle = _prevIdle;
    _prevTotal = agg.total;
    _prevIdle = agg.idle;

    // 첫 샘플: 기준점만 저장하고 0 반환.
    if (prevTotal == null || prevIdle == null) return 0;
    return computeUsage(
      prevTotal: prevTotal,
      prevIdle: prevIdle,
      total: agg.total,
      idle: agg.idle,
    );
  }

  // 코어별 사용률을 계산하고 직전 샘플을 갱신한다.
  List<double> _samplePerCore(String content) {
    final cores = parsePerCore(content);
    final result = <double>[];
    for (final core in cores) {
      final prev = _prevCores[core.index];
      _prevCores[core.index] = (total: core.total, idle: core.idle);

      // 처음 보는 코어: 기준점만 저장하고 0.
      if (prev == null) {
        result.add(0);
      } else {
        result.add(
          computeUsage(
            prevTotal: prev.total,
            prevIdle: prev.idle,
            total: core.total,
            idle: core.idle,
          ),
        );
      }
    }
    return result;
  }

  /// /proc/stat 내용에서 전체 CPU 누적치("cpu" 줄)를 파싱한다(순수 함수).
  ///
  /// idle = idle + iowait, total = 모든 필드 합. 파싱 실패 시 null.
  @visibleForTesting
  static ({int total, int idle})? parseCpuLine(String content) {
    final newline = content.indexOf('\n');
    final line = newline == -1 ? content : content.substring(0, newline);
    // 첫 토큰("cpu" 라벨)을 떼고 나머지 숫자만 넘긴다.
    return _toTotalIdle(line.split(RegExp(r'\s+')).skip(1));
  }

  /// /proc/stat 내용에서 코어별 누적치("cpu0", "cpu1"...)를 파싱한다(순수 함수).
  ///
  /// 코어 번호 오름차순으로 정렬해 반환한다. 파싱할 수 없는 코어 줄은 건너뛴다.
  @visibleForTesting
  static List<({int index, int total, int idle})> parsePerCore(String content) {
    final result = <({int index, int total, int idle})>[];
    for (final line in content.split('\n')) {
      // "cpu0 ...", "cpu12 ..." 만. 집계줄("cpu ")이나 다른 항목은 제외.
      final match = RegExp(r'^cpu(\d+)\s+(.*)$').firstMatch(line);
      if (match == null) continue;

      final index = int.parse(match.group(1)!);
      final sample = _toTotalIdle(match.group(2)!.split(RegExp(r'\s+')));
      if (sample == null) continue;
      result.add((index: index, total: sample.total, idle: sample.idle));
    }
    result.sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  // 한 CPU 줄의 숫자 토큰들을 (total, idle)로 환산한다.
  // idle = idle(3) + iowait(4), total = 모든 필드 합. 5개 미만이거나 숫자가
  // 아닌 토큰이 있으면 null.
  static ({int total, int idle})? _toTotalIdle(Iterable<String> tokens) {
    final fields = tokens.where((s) => s.isNotEmpty).map(int.tryParse).toList();
    if (fields.length < 5 || fields.any((f) => f == null)) return null;

    final values = fields.cast<int>();
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
