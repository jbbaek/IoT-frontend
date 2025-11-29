import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// FastAPI 서버 주소
const String baseUrl = "https://hyperexcitable-sclerosal-marleen.ngrok-free.dev";

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  // 일간 / 주간 포커스 값
  List<double> dailyFocus = [];
  List<double> weeklyFocus = [];

  // 방해 요인 (소음 / 조도 / 휴대폰 / 기타)
  List<double> disturbanceValues = [40, 25, 20, 15];

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  /// 공통: 센서 시계열 데이터 조회
  ///
  /// GET /v1/metrics?device_id=desk-01&metric={metric}&limit={limit}
  Future<List<Map<String, dynamic>>> _fetchMetricSeries(
      String metric, int limit) async {
    try {
      final url = Uri.parse(
          "$baseUrl/v1/metrics?device_id=desk-01&metric=$metric&limit=$limit");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> series = data["series"] ?? [];
        return series
            .map<Map<String, dynamic>>(
                (e) => {"ts": e["ts"], "value": (e["value"] as num).toDouble()})
            .toList();
      } else {
        debugPrint("GET /v1/metrics 실패: ${res.statusCode} / ${res.body}");
      }
    } catch (e) {
      debugPrint("GET /v1/metrics 오류: $e");
    }
    return [];
  }

  /// 리포트 화면에 들어갈 데이터 한 번에 로드
  Future<void> _loadReportData() async {
    setState(() => loading = true);

    // ❶ 일간/주간 학습 패턴 (metric 이름은 예시: 백엔드에서 맞게 변경 가능)
    final dailySeries = await _fetchMetricSeries("focus_daily", 7);
    final weeklySeries = await _fetchMetricSeries("focus_weekly", 7);

    // ❷ 방해 요인 (noise / brightness / phone / etc)
    final noiseSeries = await _fetchMetricSeries("noise", 20);
    final lightSeries = await _fetchMetricSeries("brightness", 20);
    final phoneSeries = await _fetchMetricSeries("phone_usage", 20);
    final etcSeries = await _fetchMetricSeries("etc_disturbance", 20);

    List<double> newDaily = [];
    List<double> newWeekly = [];

    if (dailySeries.isNotEmpty) {
      newDaily = dailySeries.map((e) => e["value"] as double).toList();
    }
    if (weeklySeries.isNotEmpty) {
      newWeekly = weeklySeries.map((e) => e["value"] as double).toList();
    }

    // 데이터가 없으면 기존 더미 값 사용
    if (newDaily.isEmpty) {
      newDaily = [2, 3, 4, 3.5, 4.2, 5, 4.8];
    }
    if (newWeekly.isEmpty) {
      newWeekly = [2, 3.5, 4, 3, 5, 4.8, 6];
    }

    // 방해 요인: 각 metric 평균값 → 비율로 사용
    double avgNoise = _avg(noiseSeries);
    double avgLight = _avg(lightSeries);
    double avgPhone = _avg(phoneSeries);
    double avgEtc = _avg(etcSeries);

    List<double> newDist = [avgNoise, avgLight, avgPhone, avgEtc];

    // 전부 0이면 기존 더미값 사용
    if (newDist.every((v) => v == 0)) {
      newDist = [40, 25, 20, 15];
    }

    setState(() {
      dailyFocus = newDaily;
      weeklyFocus = newWeekly;
      disturbanceValues = newDist;
      loading = false;
    });
  }

  double _avg(List<Map<String, dynamic>> series) {
    if (series.isEmpty) return 0;
    double sum = 0;
    for (final e in series) {
      sum += (e["value"] as double);
    }
    return sum / series.length;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("사용자 리포트",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _sectionTitle("일간 학습 패턴"),
          IgnorePointer(child: _dailyChart()),

          const SizedBox(height: 30),
          _sectionTitle("주간 학습 패턴"),
          IgnorePointer(child: _weeklyChart()),

          const SizedBox(height: 30),
          _sectionTitle("방해 요인 통계"),
          IgnorePointer(child: _disturbanceChart()),

          const SizedBox(height: 30),
          _sectionTitle("AI 인사이트"),
          _aiInsightCard(),

          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loadReportData,
              icon: const Icon(Icons.refresh),
              label: const Text("다시 불러오기"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }

  Widget _dailyChart() {
    if (dailyFocus.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("일간 데이터가 없습니다.")),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          barGroups: List.generate(dailyFocus.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dailyFocus[i],
                  color: Colors.teal,
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _weeklyChart() {
    if (weeklyFocus.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("주간 데이터가 없습니다.")),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                weeklyFocus.length,
                    (i) => FlSpot(i.toDouble(), weeklyFocus[i]),
              ),
              isCurved: true,
              color: Colors.teal,
              barWidth: 3,
              belowBarData: BarAreaData(
                show: true,
                color: Colors.teal.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disturbanceChart() {
    final labels = ["소음", "조도", "휴대폰", "기타"];

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: List.generate(4, (i) {
            final value = disturbanceValues[i];
            final colors = [
              Colors.redAccent,
              Colors.amber,
              Colors.green,
              Colors.blue
            ];
            return PieChartSectionData(
              value: value <= 0 ? 1 : value,
              color: colors[i],
              title: labels[i],
              titleStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            );
          }),
        ),
      ),
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
            Text("오늘의 분석 결과",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 8),
            Text("집중 시간은 최근 평균과 비교했을 때 무난한 수준입니다."),
            SizedBox(height: 4),
            Text("소음과 조도가 안정적인 구간에서 집중도가 더 높게 유지되는 경향이 보입니다."),
            SizedBox(height: 4),
            Text("내일은 방해 요인을 줄이고 일정한 조도를 유지하면 학습 효율이 더 높아질 것으로 예상됩니다."),
          ],
        ),
      ),
    );
  }
}
