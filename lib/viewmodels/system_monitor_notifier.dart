import 'dart:async';
import 'package:flutter/material.dart';
import '../models/memory_status.dart';
import '../services/system_monitor_service.dart';
import '../services/cpu_monitor.dart';
import '../services/network_monitor.dart';

class SystemMonitorNotifier extends ChangeNotifier {
  final _service = SystemMonitorService();

  // 미지원 플랫폼(예: macOS)에서는 CpuMonitor() 생성 자체가 UnsupportedError를
  // 던지므로, 필드 초기화 대신 startMonitoring()에서 try/catch로 생성한다.
  CpuMonitor? _cpuMonitor;
  // 네트워크 모니터는 미지원 플랫폼에서도 예외를 던지지 않으므로 바로 생성한다.
  final _networkMonitor = NetworkMonitor();
  Timer? _timer;

  MemoryStatus? currentStatus;
  double cpuUsage = 0; // 전체 CPU 사용률(0~100)
  List<double> perCoreUsage = const []; // 코어별 사용률(0~100). 미지원 시 빈 리스트.
  NetworkUsage networkUsage = const NetworkUsage(); // 네트워크 속도. 미지원 시 available=false.
  bool isLoading = false;
  String? errorMessage;

  // 그래프용 사용률 히스토리(0~100 퍼센트). 가장 오래된 값이 앞,
  // 최신 값이 뒤. maxHistory 개수를 넘으면 앞에서부터 버린다.
  static const int maxHistory = 60;
  final List<double> cpuHistory = [];
  final List<double> ramHistory = [];

  // 새 측정값을 히스토리에 넣고 오래된 값은 잘라낸다.
  void _pushHistory(List<double> history, double value) {
    history.add(value);
    if (history.length > maxHistory) {
      history.removeAt(0);
    }
  }

  void startMonitoring() {
    _timer?.cancel();

    // 현재 OS에 맞는 CPU 모니터를 생성. 지원하지 않는 플랫폼이면 여기서 막고
    // 타이머를 시작하지 않아 앱이 죽지 않도록 한다.
    try {
      _cpuMonitor = CpuMonitor();
    } catch (e) {
      isLoading = false;
      errorMessage = "이 플랫폼은 지원하지 않습니다: $e";
      notifyListeners();
      return;
    }

    isLoading = true;
    notifyListeners(); // UI에 로딩 시작을 알림

    // 1초마다 네이티브 또는 OS 파일에서 데이터 요청
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        currentStatus = await _service.getMemoryStatus();
        final cpu = _cpuMonitor!.sample();
        cpuUsage = cpu.total;
        perCoreUsage = cpu.perCore;
        networkUsage = _networkMonitor.sample();
        _pushHistory(cpuHistory, cpuUsage);
        _pushHistory(ramHistory, currentStatus!.usagePercentage);
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
