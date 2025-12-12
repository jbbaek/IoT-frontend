import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "http://172.16.255.102:8000";

class RoutineCreatePage extends StatefulWidget {
  final Map<String, dynamic>? existingRoutine;
  const RoutineCreatePage({super.key, this.existingRoutine});

  @override
  State<RoutineCreatePage> createState() => _RoutineCreatePageState();
}

class _RoutineCreatePageState extends State<RoutineCreatePage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController focusController = TextEditingController();
  final TextEditingController restController = TextEditingController();

  List<Map<String, dynamic>> routineItems = [];
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  bool repeatEveryday = false;
  List<String> selectedDays = [];
  int? routineId;

  final List<Map<String, String>> dayOptions = const [
    {"code": "MON", "label": "월"},
    {"code": "TUE", "label": "화"},
    {"code": "WED", "label": "수"},
    {"code": "THU", "label": "목"},
    {"code": "FRI", "label": "금"},
    {"code": "SAT", "label": "토"},
    {"code": "SUN", "label": "일"},
  ];

  final Map<String, int> dayCodeToInt = const {
    "MON": 1,
    "TUE": 2,
    "WED": 3,
    "THU": 4,
    "FRI": 5,
    "SAT": 6,
    "SUN": 7,
  };

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  List<String> _normalizeSelectedDays(dynamic raw) {
    // 서버가 ["MON","TUE"] or [1,2] 등 섞여도 MON~SUN으로 정리
    final list = (raw is List) ? raw : <dynamic>[];
    final out = <String>{};

    const intToCode = {
      1: "MON",
      2: "TUE",
      3: "WED",
      4: "THU",
      5: "FRI",
      6: "SAT",
      7: "SUN",
    };

    for (final d in list) {
      if (d is String) {
        final upper = d.toUpperCase().trim();
        if (dayCodeToInt.containsKey(upper)) out.add(upper);
        final asInt = int.tryParse(upper);
        if (asInt != null && intToCode.containsKey(asInt)) out.add(intToCode[asInt]!);
      } else if (d is int) {
        if (intToCode.containsKey(d)) out.add(intToCode[d]!);
      }
    }

    const order = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    final result = out.toList()
      ..sort((a, b) => order.indexOf(a) - order.indexOf(b));
    return result;
  }

  Map<String, dynamic>? _toTimeObj(dynamic v) {
    // {hour, minute} 형태만 통과
    if (v is Map) {
      final m = Map<String, dynamic>.from(v);
      final h = _toInt(m["hour"]);
      final min = _toInt(m["minute"]);
      if (h != null && min != null) return {"hour": h, "minute": min};
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    final r = widget.existingRoutine;
    if (r == null) return;

    routineId = _toInt(r["id"]);
    titleController.text = (r["title"] ?? r["name"] ?? "").toString();
    focusController.text = (r["focus"] ?? 0).toString();
    restController.text = (r["rest"] ?? 0).toString();

    repeatEveryday = (r["repeatEveryday"] ?? false) == true;
    selectedDays = _normalizeSelectedDays(r["selectedDays"] ?? r["selected_days"]);

    final rawItems = (r["items"] as List?) ?? [];
    routineItems = rawItems.map<Map<String, dynamic>>((it) {
      final m = Map<String, dynamic>.from(it as Map);
      return {
        "name": (m["name"] ?? m["title"] ?? "").toString(),
        "duration": _toInt(m["duration"]) ?? 0,
        "time": (m["time"] ?? "").toString(), // extra allow
      };
    }).toList();

    final st = _toTimeObj(r["startTime"]);
    final et = _toTimeObj(r["endTime"]);
    if (st != null) startTime = TimeOfDay(hour: st["hour"], minute: st["minute"]);
    if (et != null) endTime = TimeOfDay(hour: et["hour"], minute: et["minute"]);
  }

  void generateRoutine() {
    if (startTime == null || endTime == null) return;

    final focusMin = int.tryParse(focusController.text) ?? 0;
    final restMin = int.tryParse(restController.text) ?? 0;
    if (focusMin <= 0 || restMin <= 0) return;

    routineItems.clear();

    final now = DateTime.now();
    DateTime cursor = DateTime(now.year, now.month, now.day, startTime!.hour, startTime!.minute);
    final end = DateTime(now.year, now.month, now.day, endTime!.hour, endTime!.minute);

    int cycle = 1;
    while (cursor.isBefore(end)) {
      final focusEnd = cursor.add(Duration(minutes: focusMin));
      if (focusEnd.isAfter(end)) break;

      routineItems.add({
        "name": "공부 $cycle",
        "duration": focusMin,
        "time": "${cursor.hour.toString().padLeft(2, '0')}:${cursor.minute.toString().padLeft(2, '0')}",
      });

      cursor = focusEnd;

      final restEnd = cursor.add(Duration(minutes: restMin));
      if (restEnd.isAfter(end)) break;

      routineItems.add({
        "name": "휴식 $cycle",
        "duration": restMin,
        "time": "${cursor.hour.toString().padLeft(2, '0')}:${cursor.minute.toString().padLeft(2, '0')}",
      });

      cursor = restEnd;
      cycle++;
    }

    setState(() {});
  }

  Future<void> _createRoutine(Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl/routines");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );

    if (res.statusCode != 201) {
      throw Exception("POST ${res.statusCode}: ${res.body}");
    }
  }

  Future<void> _updateRoutine(int id, Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl/routines/$id");
    final res = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );

    if (res.statusCode != 200) {
      throw Exception("PUT ${res.statusCode}: ${res.body}");
    }
  }

  Future<void> saveRoutine() async {
    final title = titleController.text.trim();
    final focusMin = int.tryParse(focusController.text) ?? 0;
    final restMin = int.tryParse(restController.text) ?? 0;

    // ✅ 문자열 요일 (명세서용)
    final daysCode = repeatEveryday
        ? dayOptions.map((d) => d["code"]!).toList()
        : selectedDays.map((e) => e.toUpperCase()).toList();

    // ✅ int 요일 (서버가 지금 요구하는 형태)
    final daysInt = daysCode.map((c) => dayCodeToInt[c] ?? 1).toList();

    // ✅ 서버(구버전) 통과용 + 명세서 필드도 같이 실어서 전송
    final body = <String, dynamic>{
      // ---- 구버전(서버가 지금 요구) ----
      "name": title,                 // ✅ required
      "selectedDays": daysInt,       // ✅ required 타입(int list)
      "items": routineItems.map((it) => {
        "title": it["name"],         // ✅ required (서버는 items.title 요구)
        "duration": it["duration"],
        "time": it["time"],          // extra
        // 호환용으로 name도 같이(서버가 무시해도 OK)
        "name": it["name"],
      }).toList(),

      // ---- 명세서 호환(추가 필드) ----
      "title": title,
      "focus": focusMin,
      "rest": restMin,
      "startTime": startTime != null
          ? {"hour": startTime!.hour, "minute": startTime!.minute}
          : null,
      "endTime": endTime != null
          ? {"hour": endTime!.hour, "minute": endTime!.minute}
          : null,
      "repeatEveryday": repeatEveryday,
      "selectedDayCodes": daysCode,  // ✅ 문자열 요일은 다른 키로 보관(서버 검증 피함)
      "active": false,
    };

    try {
      if (routineId == null) {
        await _createRoutine(body);
      } else {
        await _updateRoutine(routineId!, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    }
  }

  Future<void> pickTime(bool isStart) async {
    final result = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (endTime ?? const TimeOfDay(hour: 9, minute: 0)),
    );
    if (result != null) {
      setState(() {
        if (isStart) {
          startTime = result;
        } else {
          endTime = result;
        }
      });
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    focusController.dispose();
    restController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(routineId == null ? "루틴 생성" : "루틴 수정",
            style: const TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFEAF3FF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("🧠 나만의 집중 루틴을 만들어보세요.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),

            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: "루틴 제목",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: focusController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: "집중시간(분)",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: restController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: "쉬는시간(분)",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: () async {
                await pickTime(true);
                await pickTime(false);
              },
              icon: const Icon(Icons.access_time, color: Colors.blueAccent),
              label: Text(
                (startTime == null || endTime == null)
                    ? "공부 시간 00:00 ~ 00:00"
                    : "공부 시간 ${startTime!.format(context)} ~ ${endTime!.format(context)}",
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                FocusScope.of(context).unfocus(); // ✅ 키보드 내림 + 입력값 확정
                generateRoutine();               // ✅ 루틴 생성
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("⏱ 루틴 생성하기",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 30),

            if (routineItems.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📋 생성된 스케줄",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: routineItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                      itemBuilder: (context, index) {
                        final item = routineItems[index];
                        return ListTile(
                          dense: true,
                          title: Text((item["name"] ?? "").toString()),
                          subtitle: Text("${item["duration"] ?? 0}분"),
                          trailing: Text((item["time"] ?? "").toString(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            Row(
              children: [
                const Text("반복 설정"),
                const Spacer(),
                Checkbox(
                  value: repeatEveryday,
                  onChanged: (val) {
                    setState(() {
                      repeatEveryday = val ?? false;
                      selectedDays = repeatEveryday ? dayOptions.map((d) => d["code"]!).toList() : [];
                    });
                  },
                ),
                const Text("매일"),
              ],
            ),

            Wrap(
              spacing: 6,
              children: dayOptions.map((day) {
                final code = day["code"]!;
                final label = day["label"]!;
                final selected = selectedDays.contains(code);

                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor: Colors.blue.withOpacity(0.3),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        if (!selectedDays.contains(code)) selectedDays.add(code);
                      } else {
                        selectedDays.remove(code);
                      }
                      repeatEveryday = (selectedDays.length == dayOptions.length);
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.blueAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text("💾 저장하기",
                  style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
