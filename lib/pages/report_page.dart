import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "http://172.16.255.102:8000";

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<double> dailyFocus = [2, 3, 4, 3.5, 4.2, 5, 4.8];   // ✅ 기본 더미
  List<double> weeklyFocus = [2, 3.5, 4, 3, 5, 4.8, 6];    // ✅ 기본 더미
  List<double> disturbanceValues = [40, 25, 20, 15];       // ✅ 기본 더미

  bool loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadReportData();

    // ✅ 주기적 갱신: 서버만 켜지면 자동으로 최신 반영
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadReportData(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchMetricSeries(String metric, int limit) async {
    try {
      final url = Uri.parse("$baseUrl/v1/metrics?device_id=desk-01&metric=$metric&limit=$limit");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> series = (data["series"] ?? []) as List<dynamic>;
        return series.map<Map<String, dynamic>>((e) {
          return {"ts": e["ts"], "value": (e["value"] as num).toDouble()};
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  double _avg(List<Map<String, dynamic>> series) {
    if (series.isEmpty) return 0;
    double sum = 0;
    for (final e in series) {
      sum += (e["value"] as double);
    }
    return sum / series.length;
  }

  Future<void> _loadReportData({bool silent = false}) async {
    if (!silent) setState(() => loading = true);

    // 백엔드에서 metric 이름은 네가 서버에서 실제로 쓰는 값과 맞춰야 함
    final dailySeries = await _fetchMetricSeries("focus_daily", 7);
    final weeklySeries = await _fetchMetricSeries("focus_weekly", 7);

    final noiseSeries = await _fetchMetricSeries("noise", 30);
    final lightSeries = await _fetchMetricSeries("brightness", 30);
    final phoneSeries = await _fetchMetricSeries("phone_usage", 30);
    final etcSeries = await _fetchMetricSeries("etc_disturbance", 30);

    // ✅ 서버 데이터가 “있을 때만” 덮어쓰기 (없으면 기존 더미 유지)
    if (dailySeries.isNotEmpty) {
      dailyFocus = dailySeries.map((e) => e["value"] as double).toList();
    }
    if (weeklySeries.isNotEmpty) {
      weeklyFocus = weeklySeries.map((e) => e["value"] as double).toList();
    }

    final avgNoise = _avg(noiseSeries);
    final avgLight = _avg(lightSeries);
    final avgPhone = _avg(phoneSeries);
    final avgEtc = _avg(etcSeries);

    final newDist = [avgNoise, avgLight, avgPhone, avgEtc];
    if (!newDist.every((v) => v == 0)) {
      disturbanceValues = newDist;
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () => _loadReportData(silent: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                onPressed: () => _loadReportData(silent: false),
                icon: const Icon(Icons.refresh),
                label: const Text("다시 불러오기"),
              ),
            ),
          ],
        ),
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
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          barGroups: List.generate(dailyFocus.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [BarChartRodData(toY: dailyFocus[i], color: Colors.teal)],
            );
          }),
        ),
      ),
    );
  }

  Widget _weeklyChart() {
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
              belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disturbanceChart() {
    final labels = ["소음", "조도", "휴대폰", "기타"];
    final colors = [Colors.redAccent, Colors.amber, Colors.green, Colors.blue];

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: List.generate(4, (i) {
            final value = disturbanceValues[i];
            return PieChartSectionData(
              value: value <= 0 ? 1 : value,
              color: colors[i],
              title: labels[i],
              titleStyle: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
