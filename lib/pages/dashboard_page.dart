import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const String baseUrl = "http://172.16.255.102:8000";

// ===== BLE UUID (ESP32와 반드시 동일해야 함) =====
const String SERVICE_UUID = "12345678-1234-1234-1234-1234567890ab";
const String SENSOR_UUID  = "12345678-1234-1234-1234-1234567890ac"; // Notify (ESP32 -> App)
const String LED_UUID     = "12345678-1234-1234-1234-1234567890ad"; // Write  (App -> ESP32)

// ===== BLE 스캔에서 찾을 ESP32 이름 키워드(광고 이름) =====
const List<String> DEVICE_NAME_HINTS = ["ESP32", "desk", "DESK", "iot", "IOT"];

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

  // ===== BLE 상태 =====
  BluetoothDevice? _device;
  BluetoothCharacteristic? _sensorChar; // Notify
  BluetoothCharacteristic? _ledChar;    // Write
  StreamSubscription<List<int>>? _sensorSub;

  bool _bleConnecting = false;
  bool _bleConnected = false;
  String _bleStatusText = "미연결";

  // BLE가 들어오면 서버 폴링보다 우선해서 UI 업데이트하도록 플래그(선택)
  bool _hasBleSensorFeed = false;

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
      // BLE로 실시간 받는 중이면 서버 폴링을 “선택적으로” 줄이고 싶으면 아래 if 사용
      // if (_hasBleSensorFeed) return;
      _loadEnvironmentFromApi(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sensorSub?.cancel();
    _safeDisconnectBle();
    super.dispose();
  }

  // =========================================================
  // 1) 서버에서 최신 값 가져오기
  // =========================================================
  Future<double?> _fetchLastMetric(String metric) async {
    try {
      final url = Uri.parse(
        "$baseUrl/v1/metrics?device_id=desk-01&metric=$metric&limit=1",
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> series = data["series"] ?? [];
        if (series.isNotEmpty) {
          // 서버가 최신이 last인지 first인지에 따라 바뀔 수 있음
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

  Future<void> _sendLedStateToServer() async {
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

  // =========================================================
  // 2) BLE 연결/수신/송신
  // =========================================================

  // 스캔 결과 중 ESP32 후보 찾기
  bool _isTargetDevice(ScanResult r) {
    final name = (r.device.platformName).trim();
    if (name.isEmpty) return false;
    for (final hint in DEVICE_NAME_HINTS) {
      if (name.contains(hint)) return true;
    }
    return false;
  }

  Future<void> _connectBle() async {
    if (_bleConnecting) return;

    setState(() {
      _bleConnecting = true;
      _bleStatusText = "스캔 중...";
    });

    try {
      // BLE 지원 여부
      final supported = await FlutterBluePlus.isSupported;
      if (!supported) {
        setState(() {
          _bleStatusText = "BLE 미지원 기기";
          _bleConnecting = false;
        });
        return;
      }

      // 스캔 시작(6초)
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

      // 스캔 결과 한번 받기
      final results = await FlutterBluePlus.scanResults.first;
      BluetoothDevice? found;
      for (final r in results) {
        if (_isTargetDevice(r)) {
          found = r.device;
          break;
        }
      }

      await FlutterBluePlus.stopScan();

      if (found == null) {
        setState(() {
          _bleStatusText = "ESP32 못 찾음(이름 확인)";
          _bleConnecting = false;
        });
        return;
      }

      _device = found;
      setState(() {
        _bleStatusText = "연결 중: ${_device!.platformName}";
      });

      // 이미 연결되어 있으면 예외 발생할 수 있어서 try
      try {
        await _device!.connect(timeout: const Duration(seconds: 10));
      } catch (_) {}

      setState(() {
        _bleConnected = true;
        _bleStatusText = "연결됨: ${_device!.platformName}";
      });

      await _discoverAndBindChars();
    } catch (e) {
      setState(() {
        _bleStatusText = "연결 실패: $e";
      });
    } finally {
      if (mounted) {
        setState(() => _bleConnecting = false);
      }
    }
  }

  Future<void> _discoverAndBindChars() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();

    BluetoothCharacteristic? sensor;
    BluetoothCharacteristic? led;

    for (final s in services) {
      if (s.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
        for (final c in s.characteristics) {
          final u = c.uuid.toString().toLowerCase();
          if (u == SENSOR_UUID.toLowerCase()) sensor = c;
          if (u == LED_UUID.toLowerCase()) led = c;
        }
      }
    }

    if (sensor == null || led == null) {
      setState(() {
        _bleStatusText = "UUID 못 찾음(ESP32 UUID 확인)";
      });
      return;
    }

    _sensorChar = sensor;
    _ledChar = led;

    await _subscribeSensorNotify();
  }

  Future<void> _subscribeSensorNotify() async {
    if (_sensorChar == null) return;

    // Notify enable
    await _sensorChar!.setNotifyValue(true);

    _sensorSub?.cancel();
    _sensorSub = _sensorChar!.onValueReceived.listen((bytes) {
      try {
        final text = utf8.decode(bytes);
        final m = json.decode(text);

        final t = (m["temperature"] as num?)?.toDouble();
        final h = (m["humidity"] as num?)?.toDouble();
        final b = (m["brightness"] as num?)?.toDouble();
        final n = (m["noise"] as num?)?.toDouble();

        if (!mounted) return;
        setState(() {
          _hasBleSensorFeed = true;
          if (t != null) temperature = t;
          if (h != null) humidity = h;
          if (b != null) brightness = b;
          if (n != null) noise = n;
        });
      } catch (e) {
        debugPrint("BLE 센서 파싱 실패: $e");
      }
    });

    setState(() {
      _bleStatusText = "센서 수신 중(Notify)";
    });
  }

  Future<void> _sendLedToEsp32() async {
    if (_ledChar == null) return;

    final payload = {
      "on": ledOn,
      "brightness": ledBrightness,
      "argb": selectedColor.value, // int
    };

    final bytes = utf8.encode(json.encode(payload));
    try {
      await _ledChar!.write(bytes, withoutResponse: true);
    } catch (e) {
      debugPrint("BLE LED write 실패: $e");
    }
  }

  Future<void> _safeDisconnectBle() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
  }

  // LED 변경 시: BLE 먼저 → 서버 기록
  Future<void> _applyLedChange() async {
    await _sendLedToEsp32();
    await _sendLedStateToServer();
  }

  // =========================================================
  // UI
  // =========================================================

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
            // ===== BLE 연결 카드 =====
            _buildBleCard(),

            const SizedBox(height: 16),

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

  Widget _buildBleCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ESP32 블루투스",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _bleConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                  color: _bleConnected ? Colors.teal : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _bleStatusText,
                    style: TextStyle(
                      color: _bleConnected ? Colors.teal : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _bleConnecting ? null : _connectBle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_bleConnecting ? "연결 중..." : "연결하기",
                        style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      _sensorSub?.cancel();
                      await _safeDisconnectBle();
                      if (!mounted) return;
                      setState(() {
                        _bleConnected = false;
                        _device = null;
                        _sensorChar = null;
                        _ledChar = null;
                        _bleStatusText = "미연결";
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("해제"),
                  ),
                ),
              ],
            ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
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
                  onTap: () async {
                    setState(() => selectedColor = color);
                    await _applyLedChange();
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
                      onChanged: (value) async {
                        setState(() => ledOn = value);
                        await _applyLedChange();
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
                  ? (value) async {
                setState(() => ledBrightness = value);
                await _applyLedChange();
              }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
