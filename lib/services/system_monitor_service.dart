import 'package:flutter/services.dart';
import '../models/memory_status.dart';

class SystemMonitorService {
  // C++ 측과 일치시킨 고유 채널명
  static const _channel = MethodChannel('com.example.monitor/resource');

  Future<MemoryStatus> getMemoryStatus() async {
    try {
      final Map<dynamic, dynamic>? result =
      await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemoryStatus');

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
}