import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/memory_status.dart';

class SystemMonitorService {
  // C++ 측과 일치시킨 고유 채널명 (Windows 네이티브 핸들러용)
  static const _channel = MethodChannel('com.example.monitor/resource');

  Future<MemoryStatus> getMemoryStatus() async {
    // Linux는 네이티브 채널 대신 /proc/meminfo를 직접 읽는다.
    if (Platform.isLinux) {
      return _getLinuxMemoryStatus();
    }
    return _getChannelMemoryStatus();
  }

  // Windows: 네이티브(C++) MethodChannel 핸들러에서 GlobalMemoryStatusEx 결과를 받는다.
  Future<MemoryStatus> _getChannelMemoryStatus() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getMemoryStatus');

      if (result != null) {
        return MemoryStatus.fromMap(result);
      }
      throw PlatformException(code: 'EMPTY_DATA', message: 'No data received');
    } on PlatformException catch (e) {
      // 에러 로깅 후 상위 레이어로 던짐
      debugPrint("네이티브 통신 실패: ${e.message}");
      rethrow;
    }
  }

  // Linux: /proc/meminfo를 읽어 사용량을 구한다.
  Future<MemoryStatus> _getLinuxMemoryStatus() async {
    final content = await File('/proc/meminfo').readAsString();
    final status = parseMeminfo(content);
    if (status == null) {
      throw const FormatException('/proc/meminfo 파싱 실패');
    }
    return status;
  }

  /// /proc/meminfo 내용을 [MemoryStatus]로 파싱한다(파일 I/O 없는 순수 함수라
  /// 단위 테스트하기 좋다). 파싱에 실패하면 null.
  ///
  /// Windows의 ullTotalPhys / ullAvailPhys와 같은 의미가 되도록 MemAvailable을
  /// "가용 메모리"로 보고 used = total - available 로 계산한다.
  /// MemAvailable은 커널 3.14+ 에만 있으므로, 없으면
  /// MemFree + Buffers + Cached 로 근사 폴백한다.
  @visibleForTesting
  static MemoryStatus? parseMeminfo(String content) {
    final total = _readMeminfoKb(content, 'MemTotal');
    if (total == null) return null;

    var available = _readMeminfoKb(content, 'MemAvailable');
    if (available == null) {
      final free = _readMeminfoKb(content, 'MemFree');
      final buffers = _readMeminfoKb(content, 'Buffers');
      final cached = _readMeminfoKb(content, 'Cached');
      if (free == null || buffers == null || cached == null) return null;
      available = free + buffers + cached;
    }

    // /proc/meminfo는 kB(=1024바이트) 단위라 바이트로 환산.
    final totalBytes = total * 1024;
    final usedBytes = (total - available) * 1024;
    return MemoryStatus(totalBytes: totalBytes, usedBytes: usedBytes);
  }

  // "MemTotal:    16384000 kB" 형태에서 숫자(kB)만 뽑아낸다.
  static int? _readMeminfoKb(String content, String key) {
    final match = RegExp(
      '^$key:\\s+(\\d+)',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
