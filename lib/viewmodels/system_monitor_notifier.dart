import 'dart:async';
import 'package:flutter/material.dart';
import '../models/memory_status.dart';
import '../services/system_monitor_service.dart';
import '../services/cpu_monitor_ffi.dart';

class SystemMonitorNotifier extends ChangeNotifier {
  final _service = SystemMonitorService();
  final _cpuMonitor = CpuMonitorFfi();
  Timer? _timer;

  MemoryStatus? currentStatus;
  double cpuUsage = 0; // FFI로 가져온 전체 CPU 사용률(0~100)
  bool isLoading = false;
  String? errorMessage;

  void startMonitoring() {
    _timer?.cancel();
    isLoading = true;
    notifyListeners(); // UI에 로딩 시작을 알림

    // 1초마다 네이티브(C++)에 데이터 요청
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        currentStatus = await _service.getMemoryStatus();
        cpuUsage = _cpuMonitor.getCpuUsage(); // FFI 호출 (동기)
        isLoading = false;
        errorMessage = null;
        notifyListeners(); // 데이터가 갱신되었으니 화면을 다시 그리라고 알림
      } catch (e) {
        errorMessage = "데이터를 불러오지 못했습니다.";
        isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 메모리 누수 방지
    super.dispose();
  }
}
