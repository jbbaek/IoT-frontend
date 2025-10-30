import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userState = "공부 중"; // 공부 중 / 휴식 중 / 부재 중
  String ledState = "집중모드 조명 활성화 중";
  double temperature = 24.3;
  double humidity = 50.1;
  double brightness = 310;
  double noise = 38.7;

  List<FlSpot> tempData = [];
  List<FlSpot> humData = [];

  @override
  void initState() {
    super.initState();
    tempData = _generateRandomData();
    humData = _generateRandomData();
  }

  List<FlSpot> _generateRandomData() {
    return List.generate(10, (i) => FlSpot(i.toDouble(), Random().nextDouble() * 100));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("현재 환경", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSensorCard(Icons.thermostat, "온도", "${temperature.toStringAsFixed(1)} °C"),
              _buildSensorCard(Icons.water_drop, "습도", "${humidity.toStringAsFixed(1)} %"),
              _buildSensorCard(Icons.light_mode, "조도", "${brightness.toStringAsFixed(0)} lx"),
              _buildSensorCard(Icons.volume_up, "소음", "${noise.toStringAsFixed(1)} dB"),
            ],
          ),

          const SizedBox(height: 30),
          const Text("현재 사용자 상태", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildStatusCard(),

          const SizedBox(height: 30),
          const Text("LED 현재 상태", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ledState,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
          const Text("실시간 변화", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: tempData,
                  isCurved: true,
                  color: Colors.orange,
                  barWidth: 3,
                ),
                LineChartBarData(
                  spots: humData,
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(IconData icon, String title, String value) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: Colors.teal, size: 36),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    IconData icon;
    Color color;

    switch (userState) {
      case "공부 중":
        icon = Icons.menu_book;
        color = Colors.green;
        break;
      case "휴식 중":
        icon = Icons.spa;
        color = Colors.orange;
        break;
      default:
        icon = Icons.airline_seat_individual_suite;
        color = Colors.grey;
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 12),
            Text(userState, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
