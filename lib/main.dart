import 'package:flutter/material.dart';
import 'viewmodels/system_monitor_notifier.dart';
import 'widgets/usage_chart.dart';

void main() {
  runApp(const TopManager());
}

class TopManager extends StatelessWidget {
  const TopManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dev Monitor',
      theme: ThemeData.dark(), // 개발자 도구 느낌을 위해 다크 테마 적용
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  // Notifier 인스턴스 생성
  final SystemMonitorNotifier _notifier = SystemMonitorNotifier();

  @override
  void initState() {
    super.initState();
    // 화면이 켜질 때 모니터링 시작
    _notifier.startMonitoring();
  }

  @override
  void dispose() {
    // 화면이 꺼질 때 Notifier도 함께 종료하여 타이머 해제
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('시스템 리소스 모니터')),
      body: Center(
        // ListenableBuilder가 _notifier의 변화를 감지하고 builder 내부만 다시 그림
        child: ListenableBuilder(
          listenable: _notifier,
          builder: (context, child) {
            // 1. 로딩 중이거나 데이터가 없을 때
            if (_notifier.isLoading && _notifier.currentStatus == null) {
              return const CircularProgressIndicator();
            }

            // 2. 에러가 발생했을 때
            if (_notifier.errorMessage != null) {
              return Text(
                _notifier.errorMessage!,
                style: const TextStyle(color: Colors.red),
              );
            }

            // 3. 정상적으로 데이터를 받아왔을 때
            final status = _notifier.currentStatus!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // === CPU (FFI로 수집) ===
                  const Icon(
                    Icons.developer_board,
                    size: 64,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "CPU 사용률",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${_notifier.cpuUsage.toStringAsFixed(1)} %",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _notifier.cpuUsage / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey[800],
                    color: _notifier.cpuUsage > 80 ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  UsageChart(
                    history: _notifier.cpuHistory,
                    color: Colors.orange,
                    capacity: SystemMonitorNotifier.maxHistory,
                  ),
                  const Divider(height: 48),
                  // === RAM (MethodChannel로 수집) ===
                  const Icon(Icons.memory, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 24),
                  Text(
                    "RAM 사용량",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${status.usedGB.toStringAsFixed(2)} GB / ${status.totalGB.toStringAsFixed(2)} GB",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  // 시각적인 프로그레스 바
                  LinearProgressIndicator(
                    value: status.usagePercentage / 100,
                    minHeight: 12,
                    backgroundColor: Colors.grey[800],
                    color:
                        status.usagePercentage > 80 ? Colors.red : Colors.green,
                  ),
                  const SizedBox(height: 16),
                  UsageChart(
                    history: _notifier.ramHistory,
                    color: Colors.blueAccent,
                    capacity: SystemMonitorNotifier.maxHistory,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
