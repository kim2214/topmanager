class MemoryStatus {
  final int totalBytes;
  final int usedBytes;

  // 스왑(페이지 파일). 스왑이 없거나 측정을 지원하지 않으면 0.
  final int swapTotalBytes;
  final int swapUsedBytes;

  MemoryStatus({
    required this.totalBytes,
    required this.usedBytes,
    this.swapTotalBytes = 0,
    this.swapUsedBytes = 0,
  });

  // C++에서 보낸 Map 데이터를 객체로 변환. 스왑 키는 없을 수 있으므로 기본 0.
  factory MemoryStatus.fromMap(Map<dynamic, dynamic> map) {
    return MemoryStatus(
      totalBytes: map['total_bytes'] as int? ?? 0,
      usedBytes: map['used_bytes'] as int? ?? 0,
      swapTotalBytes: map['swap_total_bytes'] as int? ?? 0,
      swapUsedBytes: map['swap_used_bytes'] as int? ?? 0,
    );
  }

  // UI에서 사용하기 쉽게 GB 단위 변환 헬퍼 함수
  double get usedGB => usedBytes / (1024 * 1024 * 1024);
  double get totalGB => totalBytes / (1024 * 1024 * 1024);
  double get usagePercentage => (usedBytes / totalBytes) * 100;

  // 스왑이 존재하는지(0이면 표시할 필요 없음).
  bool get hasSwap => swapTotalBytes > 0;
  double get swapUsedGB => swapUsedBytes / (1024 * 1024 * 1024);
  double get swapTotalGB => swapTotalBytes / (1024 * 1024 * 1024);
  double get swapUsagePercentage =>
      swapTotalBytes == 0 ? 0 : (swapUsedBytes / swapTotalBytes) * 100;
}
