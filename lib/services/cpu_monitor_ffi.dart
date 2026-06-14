import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Win32 FILETIME 구조체.
///
/// 64비트 값을 32비트 두 개(low/high)로 나눠 담는다. CPU 시간은 100ns 단위
/// 누적값이라 곧바로 64비트를 넘기므로 합칠 때 주의가 필요하다.
final class _FileTime extends Struct {
  @Uint32()
  external int dwLowDateTime;

  @Uint32()
  external int dwHighDateTime;
}

/// GetSystemTimes의 네이티브 시그니처.
///
/// ```c
/// BOOL GetSystemTimes(LPFILETIME lpIdleTime,
///                     LPFILETIME lpKernelTime,
///                     LPFILETIME lpUserTime);
/// ```
typedef _GetSystemTimesNative =
    Int32 Function(
      Pointer<_FileTime> idle,
      Pointer<_FileTime> kernel,
      Pointer<_FileTime> user,
    );
typedef _GetSystemTimesDart =
    int Function(
      Pointer<_FileTime> idle,
      Pointer<_FileTime> kernel,
      Pointer<_FileTime> user,
    );

/// dart:ffi로 kernel32.dll의 GetSystemTimes를 직접 호출해 전체 CPU 사용률을
/// 계산한다. 네이티브(C++) 코드를 따로 작성하지 않고 OS API를 바로 부른다.
///
/// 사용률은 "한 시점의 값"이 아니라 두 샘플 사이의 변화량으로 구해야 한다.
/// 그래서 직전 샘플을 보관해 두고, 이번 호출과의 차이로 계산한다.
class CpuMonitorFfi {
  CpuMonitorFfi()
    : _getSystemTimes = DynamicLibrary.open(
        'kernel32.dll',
      ).lookupFunction<_GetSystemTimesNative, _GetSystemTimesDart>(
        'GetSystemTimes',
      );

  final _GetSystemTimesDart _getSystemTimes;

  // 직전 샘플 (100ns 단위 누적값). 첫 호출 전에는 null.
  int? _prevIdle;
  int? _prevKernel;
  int? _prevUser;

  /// 전체 CPU 사용률(0~100%)을 반환한다.
  ///
  /// 첫 호출은 비교할 이전 샘플이 없어 0을 돌려주고 기준점만 저장한다.
  /// 1초 간격으로 주기 호출하면 그 구간의 평균 사용률이 나온다.
  double getCpuUsage() {
    final idle = calloc<_FileTime>();
    final kernel = calloc<_FileTime>();
    final user = calloc<_FileTime>();
    try {
      if (_getSystemTimes(idle, kernel, user) == 0) {
        throw Exception('GetSystemTimes 호출 실패');
      }

      final idleTime = _toInt64(idle.ref);
      final kernelTime = _toInt64(kernel.ref);
      final userTime = _toInt64(user.ref);

      // 첫 샘플: 기준점만 저장하고 0 반환.
      if (_prevIdle == null) {
        _prevIdle = idleTime;
        _prevKernel = kernelTime;
        _prevUser = userTime;
        return 0;
      }

      final idleDelta = idleTime - _prevIdle!;
      final kernelDelta = kernelTime - _prevKernel!;
      final userDelta = userTime - _prevUser!;

      _prevIdle = idleTime;
      _prevKernel = kernelTime;
      _prevUser = userTime;

      // kernelTime은 idle 시간을 이미 포함한다. 따라서
      // 전체 시간 = kernel + user, 사용한 시간 = 전체 - idle.
      final total = kernelDelta + userDelta;
      if (total == 0) return 0;
      final busy = total - idleDelta;
      return (busy / total * 100).clamp(0, 100).toDouble();
    } finally {
      // 네이티브 메모리는 GC 대상이 아니므로 반드시 직접 해제한다.
      calloc.free(idle);
      calloc.free(kernel);
      calloc.free(user);
    }
  }

  // FILETIME(low/high)을 64비트 정수로 합친다. dwLowDateTime은 부호 없는
  // 32비트라 0~2^32-1 양수이고, Dart의 int는 네이티브에서 64비트이므로 안전.
  int _toInt64(_FileTime ft) => (ft.dwHighDateTime << 32) | ft.dwLowDateTime;
}
