import 'dart:io';

import 'package:flutter/foundation.dart';

import 'network_monitor.dart';

/// /proc/net/dev를 읽어 전체 네트워크 송수신 속도를 계산하는 Linux 구현.
///
/// /proc/net/dev는 인터페이스별 누적 바이트를 담는다(수신 bytes가 콜론 뒤 첫
/// 필드, 송신 bytes가 9번째 필드). 루프백(lo)은 실제 네트워크가 아니므로 제외하고
/// 나머지를 합산한다. 누적값이라 두 샘플의 차이를 경과 시간으로 나눠 B/s를 구한다.
class NetworkMonitorLinux implements NetworkMonitor {
  // 직전 샘플의 누적 바이트. 첫 호출 전에는 null.
  int? _prevRx;
  int? _prevTx;

  // 샘플 간 경과 시간 측정용. 타이머 주기가 정확히 1초가 아닐 수 있어 직접 잰다.
  final Stopwatch _stopwatch = Stopwatch();

  @override
  NetworkUsage sample() {
    final content = _read();
    if (content == null) return const NetworkUsage(available: false);

    final totals = parseTotals(content);
    if (totals == null) return const NetworkUsage(available: false);

    // 첫 샘플: 기준점/타이머만 세팅하고 0(속도는 변화량이 있어야 나온다).
    if (_prevRx == null || _prevTx == null) {
      _prevRx = totals.rx;
      _prevTx = totals.tx;
      _stopwatch
        ..reset()
        ..start();
      return const NetworkUsage(available: true);
    }

    final elapsed = _stopwatch.elapsedMicroseconds / 1e6; // 초
    _stopwatch
      ..reset()
      ..start();

    final rxRate = computeRate(_prevRx!, totals.rx, elapsed);
    final txRate = computeRate(_prevTx!, totals.tx, elapsed);
    _prevRx = totals.rx;
    _prevTx = totals.tx;

    return NetworkUsage(
      available: true,
      rxBytesPerSec: rxRate,
      txBytesPerSec: txRate,
    );
  }

  /// /proc/net/dev 내용에서 lo를 제외한 전체 수신/송신 누적 바이트를 합산한다
  /// (파일 I/O 없는 순수 함수). 유효한 인터페이스가 하나도 없으면 null.
  @visibleForTesting
  static ({int rx, int tx})? parseTotals(String content) {
    var rx = 0;
    var tx = 0;
    var found = false;

    for (final line in content.split('\n')) {
      // 데이터 줄만 "iface: ..." 형태로 콜론을 가진다(헤더 2줄은 제외됨).
      final colon = line.indexOf(':');
      if (colon == -1) continue;

      final name = line.substring(0, colon).trim();
      if (name.isEmpty || name == 'lo') continue; // 루프백 제외

      final fields = line
          .substring(colon + 1)
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      // 수신 8개 + 송신 8개 = 16개 필드.
      if (fields.length < 16) continue;

      final r = int.tryParse(fields[0]); // 수신 bytes
      final t = int.tryParse(fields[8]); // 송신 bytes
      if (r == null || t == null) continue;

      rx += r;
      tx += t;
      found = true;
    }

    return found ? (rx: rx, tx: tx) : null;
  }

  /// 누적 바이트 두 샘플과 경과 시간으로 초당 속도(B/s)를 계산한다(순수 함수).
  ///
  /// 인터페이스가 내려갔다 올라오면 카운터가 리셋되어 delta가 음수가 될 수 있는데,
  /// 그 경우 0을 돌려준다.
  @visibleForTesting
  static double computeRate(int prev, int current, double elapsedSeconds) {
    if (elapsedSeconds <= 0) return 0;
    final delta = current - prev;
    if (delta < 0) return 0;
    return delta / elapsedSeconds;
  }

  // /proc/net/dev를 읽는다. 읽기에 실패하면 null.
  String? _read() {
    try {
      return File('/proc/net/dev').readAsStringSync();
    } catch (_) {
      return null;
    }
  }
}
