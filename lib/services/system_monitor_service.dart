import 'dart:io';

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
      print("네이티브 통신 실패: ${e.message}");
      rethrow;
    }
  }

  // Linux: /proc/meminfo의 MemTotal / MemAvailable로 사용량을 구한다.
  // Windows의 ullTotalPhys / ullAvailPhys와 같은 의미가 되도록 MemAvailable을
  // "가용 메모리"로 보고 used = total - available 로 계산한다.
  Future<MemoryStatus> _getLinuxMemoryStatus() async {
    final content = await File('/proc/meminfo').readAsString();

    final total = _readMeminfoKb(content, 'MemTotal');
    final available = _readMeminfoKb(content, 'MemAvailable');
    if (total == null || available == null) {
      throw const FormatException('/proc/meminfo 파싱 실패');
    }

    // /proc/meminfo는 kB(=1024바이트) 단위라 바이트로 환산.
    final totalBytes = total * 1024;
    final usedBytes = (total - available) * 1024;
    return MemoryStatus(totalBytes: totalBytes, usedBytes: usedBytes);
  }

  // "MemTotal:    16384000 kB" 형태에서 숫자(kB)만 뽑아낸다.
  int? _readMeminfoKb(String content, String key) {
    final match = RegExp(
      '^$key:\\s+(\\d+)',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
