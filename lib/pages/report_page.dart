import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(), // ✅ 스크롤 부드럽게
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("사용자 리포트", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _sectionTitle("일간 학습 패턴"),
          IgnorePointer(child: _dailyChart()), // ✅ 차트 스크롤 방해 방지

          const SizedBox(height: 30),
          _sectionTitle("주간 학습 패턴"),
          IgnorePointer(child: _weeklyChart()),

          const SizedBox(height: 30),
          _sectionTitle("방해 요인 통계"),
          IgnorePointer(child: _disturbanceChart()),

          const SizedBox(height: 30),
          _sectionTitle("AI 인사이트"),
          _aiInsightCard(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }

  Widget _dailyChart() {
    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(show: false),
        barGroups: List.generate(7, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(toY: (i + 2) * 1.5, color: Colors.teal),
            ],
          );
        }),
      )),
    );
  }

  Widget _weeklyChart() {
    return SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 2),
              FlSpot(1, 3.5),
              FlSpot(2, 4),
              FlSpot(3, 3),
              FlSpot(4, 5),
              FlSpot(5, 4.8),
              FlSpot(6, 6),
            ],
            isCurved: true,
            color: Colors.teal,
            barWidth: 3,
            belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.2)),
          )
        ],
      )),
    );
  }

  Widget _disturbanceChart() {
    return SizedBox(
      height: 200,
      child: PieChart(PieChartData(
        sections: [
          PieChartSectionData(value: 40, color: Colors.redAccent, title: '소음'),
          PieChartSectionData(value: 25, color: Colors.amber, title: '조도'),
          PieChartSectionData(value: 20, color: Colors.green, title: '휴대폰'),
          PieChartSectionData(value: 15, color: Colors.blue, title: '기타'),
        ],
      )),
    );
  }

  Widget _aiInsightCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("오늘의 분석 결과", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text("집중 시간은 평균보다 높으며, 소음이 감소한 환경에서 집중력이 향상되었습니다."),
            SizedBox(height: 4),
            Text("내일은 일정한 조도를 유지하면 학습 효율이 더 높아질 것으로 예상됩니다."),
          ],
        ),
      ),
    );
  }
}
