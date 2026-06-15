import 'package:flutter_test/flutter_test.dart';
import 'package:topmanager/services/cpu_monitor_linux.dart';
import 'package:topmanager/services/system_monitor_service.dart';

void main() {
  group('SystemMonitorService.parseMeminfo', () {
    test('MemTotal/MemAvailable로 used = total - available를 계산한다', () {
      const content = '''
MemTotal:       16384 kB
MemFree:         4096 kB
MemAvailable:    8192 kB
Buffers:         1024 kB
Cached:          2048 kB
''';
      final status = SystemMonitorService.parseMeminfo(content);

      expect(status, isNotNull);
      expect(status!.totalBytes, 16384 * 1024);
      // used = (16384 - 8192) kB
      expect(status.usedBytes, (16384 - 8192) * 1024);
    });

    test('MemAvailable이 없으면 MemFree+Buffers+Cached로 폴백한다', () {
      // 커널 3.14 미만 시뮬레이션: MemAvailable 라인 없음.
      const content = '''
MemTotal:       16384 kB
MemFree:         4096 kB
Buffers:         1024 kB
Cached:          2048 kB
''';
      final status = SystemMonitorService.parseMeminfo(content);

      expect(status, isNotNull);
      final available = 4096 + 1024 + 2048;
      expect(status!.usedBytes, (16384 - available) * 1024);
    });

    test('MemTotal이 없으면 null을 반환한다', () {
      const content = 'MemFree: 4096 kB\n';
      expect(SystemMonitorService.parseMeminfo(content), isNull);
    });

    test('폴백에 필요한 필드가 빠지면 null을 반환한다', () {
      // MemAvailable도 없고 Cached도 없음.
      const content = '''
MemTotal:       16384 kB
MemFree:         4096 kB
Buffers:         1024 kB
''';
      expect(SystemMonitorService.parseMeminfo(content), isNull);
    });
  });

  group('CpuMonitorLinux.parseCpuLine', () {
    test('idle = idle+iowait, total = 모든 필드 합으로 파싱한다', () {
      // user nice system idle iowait irq softirq steal
      const content = 'cpu  100 0 50 800 40 0 10 0\ncpu0 ...\n';
      final sample = CpuMonitorLinux.parseCpuLine(content);

      expect(sample, isNotNull);
      expect(sample!.idle, 800 + 40);
      expect(sample.total, 100 + 0 + 50 + 800 + 40 + 0 + 10 + 0);
    });

    test('필드가 5개 미만이면 null을 반환한다', () {
      const content = 'cpu  100 0 50\n';
      expect(CpuMonitorLinux.parseCpuLine(content), isNull);
    });

    test('숫자가 아닌 값이 섞이면 null을 반환한다', () {
      const content = 'cpu  100 0 50 abc 40\n';
      expect(CpuMonitorLinux.parseCpuLine(content), isNull);
    });
  });

  group('CpuMonitorLinux.computeUsage', () {
    test('busy 비율을 0~100%로 계산한다', () {
      // 전체 100 증가 중 idle 25 증가 → 75% 사용.
      final usage = CpuMonitorLinux.computeUsage(
        prevTotal: 1000,
        prevIdle: 800,
        total: 1100,
        idle: 825,
      );
      expect(usage, closeTo(75.0, 0.001));
    });

    test('totalDelta가 0 이하면 0을 반환한다', () {
      final usage = CpuMonitorLinux.computeUsage(
        prevTotal: 1000,
        prevIdle: 800,
        total: 1000,
        idle: 800,
      );
      expect(usage, 0);
    });

    test('완전 idle이면 0%, 완전 busy면 100%', () {
      expect(
        CpuMonitorLinux.computeUsage(
          prevTotal: 0,
          prevIdle: 0,
          total: 100,
          idle: 100,
        ),
        0,
      );
      expect(
        CpuMonitorLinux.computeUsage(
          prevTotal: 0,
          prevIdle: 0,
          total: 100,
          idle: 0,
        ),
        100,
      );
    });
  });
}
