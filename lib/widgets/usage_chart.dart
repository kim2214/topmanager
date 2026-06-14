import 'package:flutter/material.dart';

/// 사용률 히스토리(0~100%)를 시간축 라인 그래프로 그리는 위젯.
///
/// 외부 차트 패키지 없이 CustomPainter로 직접 그린다. 최신 값이 오른쪽 끝에
/// 오고, 데이터가 쌓이면 작업관리자처럼 왼쪽으로 흐른다.
class UsageChart extends StatelessWidget {
  const UsageChart({
    super.key,
    required this.history,
    required this.color,
    this.capacity = 60,
    this.height = 80,
  });

  /// 0~100 범위의 사용률 값들. 앞이 오래된 값, 뒤가 최신 값.
  final List<double> history;

  /// 라인/채움 색.
  final Color color;

  /// 가로로 표시할 최대 점 개수(시간 창 크기).
  final int capacity;

  /// 그래프 높이.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _UsageChartPainter(
          history: history,
          color: color,
          capacity: capacity,
        ),
      ),
    );
  }
}

class _UsageChartPainter extends CustomPainter {
  _UsageChartPainter({
    required this.history,
    required this.color,
    required this.capacity,
  });

  final List<double> history;
  final Color color;
  final int capacity;

  @override
  void paint(Canvas canvas, Size size) {
    // 배경 + 가로 격자선(25% 간격)을 먼저 그린다.
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (history.isEmpty) return;

    // x 간격: capacity 기준으로 고정해 최신 값이 오른쪽 끝에 붙도록 한다.
    final step = capacity > 1 ? size.width / (capacity - 1) : size.width;

    // 값(0~100) → 화면 좌표. y는 위가 0이라 뒤집어 준다.
    Offset pointFor(int index) {
      final fromRight = history.length - 1 - index;
      final x = size.width - fromRight * step;
      final y = size.height * (1 - history[index].clamp(0, 100) / 100);
      return Offset(x, y);
    }

    final linePath = Path();
    for (int i = 0; i < history.length; i++) {
      final p = pointFor(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }

    // 라인 아래를 살짝 채워 면적 그래프로 보이게 한다.
    final firstX = pointFor(0).dx;
    final lastX = pointFor(history.length - 1).dx;
    final fillPath = Path.from(linePath)
      ..lineTo(lastX, size.height)
      ..lineTo(firstX, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()..color = color.withValues(alpha: 0.15),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _UsageChartPainter oldDelegate) {
    // 매 틱마다 history가 갱신되므로 항상 다시 그린다.
    return true;
  }
}
