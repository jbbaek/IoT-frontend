import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "http://172.16.255.102:8000";

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String userState = "공부 중";
  String ledState = "집중모드 조명 활성화 중";

  // ✅ 기본 더미 (데이터 없을 때)
  double temperature = 24.3;
  double humidity = 50.1;
  double brightness = 310;
  double noise = 38.7;

  bool ledOn = true;
  double ledBrightness = 0.7;
  Color selectedColor = Colors.amber;

  Timer? _timer;

  final List<Color> ledColors = [
    Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.teal,
    Colors.blue, Colors.purple, Colors.pink, Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _loadEnvironmentFromApi();

    // ✅ 서버만 켜지면 계속 최신값 반영
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadEnvironmentFromApi(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<double?> _fetchLastMetric(String metric) async {
    try {
      final url = Uri.parse("$baseUrl/v1/metrics?device_id=desk-01&metric=$metric&limit=1");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> series = data["series"] ?? [];
        if (series.isNotEmpty) {
          final last = series.last;
          return (last["value"] as num).toDouble();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _loadEnvironmentFromApi({bool silent = false}) async {
    final t = await _fetchLastMetric("temperature");
    final h = await _fetchLastMetric("humidity");
    final b = await _fetchLastMetric("brightness");
    final n = await _fetchLastMetric("noise");

    if (!mounted) return;
    setState(() {
      // ✅ 서버 값이 있을 때만 업데이트 (없으면 더미 유지)
      if (t != null) temperature = t;
      if (h != null) humidity = h;
      if (b != null) brightness = b;
      if (n != null) noise = n;
    });
  }

  Future<void> _sendLedState() async {
    final url = Uri.parse("$baseUrl/v1/ingest/sensor-batch");
    final body = [
      {"device_id": "desk-01", "metric": "led_on", "value": ledOn ? 1.0 : 0.0, "unit": "bool"},
      {"device_id": "desk-01", "metric": "led_brightness", "value": ledBrightness, "unit": "ratio"},
      {"device_id": "desk-01", "metric": "led_color", "value": selectedColor.value.toDouble(), "unit": "argb"},
    ];

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );
      if (res.statusCode != 200) {
        debugPrint("POST sensor-batch 실패: ${res.statusCode} / ${res.body}");
      }
    } catch (e) {
      debugPrint("POST sensor-batch 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadEnvironmentFromApi(silent: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("현재 환경",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
            const Text("현재 사용자 상태",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildStatusCard(),

            const SizedBox(height: 30),
            const Text("LED 현재 상태",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildLedControlCard(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCard(IconData icon, String title, String value) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

  Widget _buildLedControlCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: selectedColor, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ledOn ? ledState : "조명 꺼짐",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text("LED 색상 선택", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ledColors.map((color) {
                final isSelected = selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => selectedColor = color);
                    _sendLedState();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 25),
            const Text("밝기 조절", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text("LED 전원", style: TextStyle(fontSize: 15)),
                    Switch(
                      value: ledOn,
                      activeColor: Colors.teal,
                      onChanged: (value) {
                        setState(() => ledOn = value);
                        _sendLedState();
                      },
                    ),
                  ],
                ),
                Text("${(ledBrightness * 100).toInt()}%", style: const TextStyle(fontSize: 15)),
              ],
            ),

            Slider(
              value: ledBrightness,
              min: 0,
              max: 1,
              divisions: 10,
              activeColor: Colors.teal,
              inactiveColor: Colors.grey.shade300,
              onChanged: ledOn
                  ? (value) {
                setState(() => ledBrightness = value);
                _sendLedState();
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
