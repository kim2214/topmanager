// topmanager 위젯 테스트.
//
// 카운터 템플릿이 아니라 실제 앱(시스템 리소스 모니터)에 맞춘 테스트다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:topmanager/main.dart';
import 'package:topmanager/widgets/usage_chart.dart';

void main() {
  testWidgets('시작하면 앱 바 제목과 로딩 인디케이터를 표시한다', (tester) async {
    await tester.pumpWidget(const TopManager());

    // 데이터 수집 전 첫 프레임: 로딩 상태.
    expect(find.text('시스템 리소스 모니터'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 화면을 교체해 MonitorScreen.dispose()로 주기 타이머를 정리한다
    // (정리하지 않으면 "Timer is still pending" 오류가 난다).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('UsageChart는 빈 히스토리에서도 예외 없이 그려진다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UsageChart(history: [], color: Colors.orange),
        ),
      ),
    );

    expect(find.byType(UsageChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('UsageChart는 값이 채워진 히스토리를 그린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UsageChart(
            history: [10, 20, 80, 100, 0],
            color: Colors.blueAccent,
          ),
        ),
      ),
    );

    expect(find.byType(UsageChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
