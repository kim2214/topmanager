import 'package:flutter_test/flutter_test.dart';
import 'package:topmanager/main.dart';
import 'package:topmanager/services/cpu_monitor_linux.dart';
import 'package:topmanager/services/network_monitor_linux.dart';
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

    test('SwapTotal/SwapFree로 스왑 사용량을 계산한다', () {
      const content = '''
MemTotal:       16384 kB
MemAvailable:    8192 kB
SwapTotal:       4096 kB
SwapFree:        1024 kB
''';
      final status = SystemMonitorService.parseMeminfo(content);

      expect(status, isNotNull);
      expect(status!.hasSwap, isTrue);
      expect(status.swapTotalBytes, 4096 * 1024);
      // used = (4096 - 1024) kB
      expect(status.swapUsedBytes, (4096 - 1024) * 1024);
    });

    test('스왑 정보가 없으면 hasSwap이 false다', () {
      const content = '''
MemTotal:       16384 kB
MemAvailable:    8192 kB
''';
      final status = SystemMonitorService.parseMeminfo(content);

      expect(status, isNotNull);
      expect(status!.hasSwap, isFalse);
      expect(status.swapTotalBytes, 0);
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

  group('CpuMonitorLinux.parsePerCore', () {
    const content = '''
cpu  100 0 50 800 40 0 10 0
cpu0 50 0 25 400 20 0 5 0
cpu1 50 0 25 400 20 0 5 0
intr 12345
ctxt 67890
''';

    test('cpuN 줄만 코어별로 파싱한다(집계줄 cpu, 기타 줄 제외)', () {
      final cores = CpuMonitorLinux.parsePerCore(content);

      expect(cores.length, 2);
      expect(cores[0].index, 0);
      expect(cores[1].index, 1);
      // idle = idle + iowait = 400 + 20
      expect(cores[0].idle, 420);
      expect(cores[0].total, 50 + 0 + 25 + 400 + 20 + 0 + 5 + 0);
    });

    test('코어 번호 오름차순으로 정렬한다', () {
      const unordered = '''
cpu  0 0 0 0 0
cpu2 1 0 1 1 0
cpu0 1 0 1 1 0
cpu1 1 0 1 1 0
''';
      final cores = CpuMonitorLinux.parsePerCore(unordered);
      expect(cores.map((c) => c.index).toList(), [0, 1, 2]);
    });

    test('코어 줄이 없으면 빈 리스트를 반환한다', () {
      const noCores = 'cpu  100 0 50 800 40\nintr 1\n';
      expect(CpuMonitorLinux.parsePerCore(noCores), isEmpty);
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

  group('NetworkMonitorLinux.parseTotals', () {
    test('lo를 제외하고 모든 인터페이스의 rx/tx를 합산한다', () {
      const content = '''
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 1000  10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0
  eth0: 5000 50 0 0 0 0 0 0 2000 20 0 0 0 0 0 0
 wlan0: 3000 30 0 0 0 0 0 0 1000 10 0 0 0 0 0 0
''';
      final totals = NetworkMonitorLinux.parseTotals(content);

      expect(totals, isNotNull);
      // lo(1000)는 제외, eth0+wlan0 만 합산.
      expect(totals!.rx, 5000 + 3000);
      expect(totals.tx, 2000 + 1000);
    });

    test('유효한 인터페이스가 없으면 null을 반환한다(헤더/lo만)', () {
      const content = '''
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets ...
    lo: 1000 10 0 0 0 0 0 0 1000 10 0 0 0 0 0 0
''';
      expect(NetworkMonitorLinux.parseTotals(content), isNull);
    });
  });

  group('NetworkMonitorLinux.computeRate', () {
    test('delta를 경과 시간으로 나눠 B/s를 계산한다', () {
      // 2초 동안 2048바이트 증가 → 1024 B/s.
      expect(NetworkMonitorLinux.computeRate(1000, 3048, 2.0), 1024);
    });

    test('카운터 리셋(delta 음수)이면 0을 반환한다', () {
      expect(NetworkMonitorLinux.computeRate(5000, 100, 1.0), 0);
    });

    test('경과 시간이 0 이하면 0을 반환한다', () {
      expect(NetworkMonitorLinux.computeRate(0, 1000, 0), 0);
    });
  });

  group('formatRate', () {
    test('단위를 자동 선택한다', () {
      expect(formatRate(0), '0 B/s');
      expect(formatRate(512), '512 B/s');
      expect(formatRate(1024), '1.0 KB/s');
      expect(formatRate(1536), '1.5 KB/s');
      expect(formatRate(1024 * 1024), '1.0 MB/s');
      expect(formatRate(1024 * 1024 * 1024), '1.0 GB/s');
    });
  });
}
