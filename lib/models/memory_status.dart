class MemoryStatus {
  final int totalBytes;
  final int usedBytes;

  MemoryStatus({required this.totalBytes, required this.usedBytes});

  // C++에서 보낸 Map 데이터를 객체로 변환
  factory MemoryStatus.fromMap(Map<dynamic, dynamic> map) {
    return MemoryStatus(
      totalBytes: map['total_bytes'] as int? ?? 0,
      usedBytes: map['used_bytes'] as int? ?? 0,
    );
  }

  // UI에서 사용하기 쉽게 GB 단위 변환 헬퍼 함수
  double get usedGB => usedBytes / (1024 * 1024 * 1024);
  double get totalGB => totalBytes / (1024 * 1024 * 1024);
  double get usagePercentage => (usedBytes / totalBytes) * 100;
}