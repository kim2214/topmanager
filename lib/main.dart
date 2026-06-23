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
                  // === 코어별 CPU (지원 플랫폼에서만 표시) ===
                  if (_notifier.perCoreUsage.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      "코어별 사용률",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _PerCoreGrid(usages: _notifier.perCoreUsage),
                  ],
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
                  // === 스왑 (존재할 때만 표시) ===
                  if (status.hasSwap) ...[
                    const Divider(height: 48),
                    const Icon(
                      Icons.swap_horiz,
                      size: 64,
                      color: Colors.purpleAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "스왑 사용량",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "${status.swapUsedGB.toStringAsFixed(2)} GB / ${status.swapTotalGB.toStringAsFixed(2)} GB",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: status.swapUsagePercentage / 100,
                      minHeight: 12,
                      backgroundColor: Colors.grey[800],
                      color: status.swapUsagePercentage > 80
                          ? Colors.red
                          : Colors.purpleAccent,
                    ),
                  ],
                  // === 네트워크 속도 (지원 플랫폼에서만 표시) ===
                  if (_notifier.networkUsage.available) ...[
                    const Divider(height: 48),
                    const Icon(Icons.lan, size: 64, color: Colors.tealAccent),
                    const SizedBox(height: 24),
                    Text(
                      "네트워크 속도",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NetRate(
                          icon: Icons.south,
                          label: "수신",
                          bytesPerSec: _notifier.networkUsage.rxBytesPerSec,
                          color: Colors.tealAccent,
                        ),
                        _NetRate(
                          icon: Icons.north,
                          label: "송신",
                          bytesPerSec: _notifier.networkUsage.txBytesPerSec,
                          color: Colors.amberAccent,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 코어별 CPU 사용률을 작은 막대 그리드로 보여주는 위젯.
///
/// 인덱스가 코어 번호(C0, C1, ...)이며, 화면 폭에 맞춰 자동 줄바꿈된다.
class _PerCoreGrid extends StatelessWidget {
  const _PerCoreGrid({required this.usages});

  /// 코어별 사용률(0~100). 인덱스 = 코어 번호.
  final List<double> usages;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        for (int i = 0; i < usages.length; i++)
          SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("C$i", style: const TextStyle(color: Colors.grey)),
                    Text("${usages[i].toStringAsFixed(0)} %"),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: usages[i] / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey[800],
                  color: usages[i] > 80 ? Colors.red : Colors.orange,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 네트워크 송신/수신 속도 하나를 아이콘 + 라벨 + 속도로 보여주는 위젯.
class _NetRate extends StatelessWidget {
  const _NetRate({
    required this.icon,
    required this.label,
    required this.bytesPerSec,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double bytesPerSec;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          formatRate(bytesPerSec),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

/// 초당 바이트(B/s)를 사람이 읽기 쉬운 단위(B/s, KB/s, MB/s, GB/s)로 변환한다.
String formatRate(double bytesPerSec) {
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  var value = bytesPerSec;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  // B/s는 소수점이 의미 없으니 정수로, 그 외는 소수 첫째 자리까지.
  final text = unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return "$text ${units[unit]}";
}
