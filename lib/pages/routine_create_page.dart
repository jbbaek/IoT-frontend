import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// TODO : FastAPI 서버 주소로 변경
const String baseUrl = "http://<BACKEND_IP>:8000";

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
  final List<String> days = ["월", "화", "수", "목", "금", "토", "일"];

  int? routineId; // ← 수정 시 ID 저장

  @override
  void initState() {
    super.initState();

    if (widget.existingRoutine != null) {
      final r = widget.existingRoutine!;
      routineId = r["id"];

      titleController.text = r["name"] ?? "";
      focusController.text = r["focus"] ?? "";
      restController.text = r["rest"] ?? "";

      repeatEveryday = r["repeatEveryday"] ?? false;
      selectedDays = List<String>.from(r["selectedDays"] ?? []);
      routineItems = List<Map<String, dynamic>>.from(r["items"] ?? []);

      if (r["startTime"] != null) {
        startTime = TimeOfDay(
          hour: r["startTime"]["hour"],
          minute: r["startTime"]["minute"],
        );
      }
      if (r["endTime"] != null) {
        endTime = TimeOfDay(
          hour: r["endTime"]["hour"],
          minute: r["endTime"]["minute"],
        );
      }
    }
  }

  void generateRoutine() {
    if (startTime == null || endTime == null) return;
    if (focusController.text.isEmpty || restController.text.isEmpty) return;

    final int focusMin = int.tryParse(focusController.text) ?? 0;
    final int restMin = int.tryParse(restController.text) ?? 0;

    routineItems.clear();

    DateTime now = DateTime.now();
    DateTime start = DateTime(
        now.year, now.month, now.day, startTime!.hour, startTime!.minute);
    DateTime end =
    DateTime(now.year, now.month, now.day, endTime!.hour, endTime!.minute);

    int cycle = 1;
    while (start.isBefore(end)) {
      DateTime focusEnd = start.add(Duration(minutes: focusMin));
      if (focusEnd.isAfter(end)) break;

      routineItems.add({
        "title": "공부 $cycle",
        "time":
        "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}"
      });

      start = focusEnd;
      DateTime restEnd = start.add(Duration(minutes: restMin));
      if (restEnd.isAfter(end)) break;

      routineItems.add({
        "title": "휴식 $cycle",
        "time":
        "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}"
      });

      start = restEnd;
      cycle++;
    }

    setState(() {});
  }

  Future<void> createRoutine(Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl/routines");
    await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );
  }

  Future<void> updateRoutine(int id, Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl/routines/$id");
    await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );
  }

  Future<void> saveRoutine() async {
    final routineBody = {
      "name": titleController.text,
      "focus": focusController.text,
      "rest": restController.text,
      "startTime": startTime != null
          ? {"hour": startTime!.hour, "minute": startTime!.minute}
          : null,
      "endTime": endTime != null
          ? {"hour": endTime!.hour, "minute": endTime!.minute}
          : null,
      "repeatEveryday": repeatEveryday,
      "selectedDays": selectedDays,
      "items": routineItems,
      "active": false,
    };

    if (routineId == null) {
      await createRoutine(routineBody);
    } else {
      await updateRoutine(routineId!, routineBody);
    }

    if (mounted) Navigator.pop(context, true); // ✅ true 반환
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          routineId == null ? "루틴 생성" : "루틴 수정",
          style: const TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFEAF3FF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "🧠 나만의 집중 루틴을 만들어보세요.",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 제목 입력
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: "루틴 제목",
                filled: true,
                fillColor: Colors.white,
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),

            const SizedBox(height: 20),

            // 집중/휴식
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 공부 시간 설정
            OutlinedButton.icon(
              onPressed: () async {
                await pickTime(true);
                await pickTime(false);
              },
              icon: const Icon(Icons.access_time, color: Colors.blueAccent),
              label: Text(
                startTime == null || endTime == null
                    ? "공부 시간 00:00 ~ 00:00"
                    : "공부 시간 ${startTime!.format(context)} ~ ${endTime!.format(context)}",
                style: const TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: generateRoutine,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "⏱ 루틴 생성하기",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),

            const SizedBox(height: 30),

            if (routineItems.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("📋 생성된 스케줄",
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.black12),
                      itemBuilder: (context, index) {
                        final item = routineItems[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor:
                            Colors.blueAccent.withValues(alpha: 0.15),
                            radius: 16,
                            child: Icon(
                              item["title"].contains("공부")
                                  ? Icons.school
                                  : Icons.coffee,
                              size: 18,
                              color: Colors.blueAccent,
                            ),
                          ),
                          title: Text(item["title"]),
                          trailing: Text(
                            item["time"],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

            // 반복 설정
            Row(
              children: [
                const Text("반복 설정"),
                const Spacer(),
                Checkbox(
                  value: repeatEveryday,
                  onChanged: (val) {
                    setState(() {
                      repeatEveryday = val ?? false;
                      selectedDays =
                      repeatEveryday ? List<String>.from(days) : [];
                    });
                  },
                ),
                const Text("매일"),
              ],
            ),

            Wrap(
              spacing: 6,
              children: days.map((day) {
                final selected = selectedDays.contains(day);
                return ChoiceChip(
                  label: Text(day),
                  selected: selected,
                  selectedColor: Colors.blue.withValues(alpha: 0.3),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedDays.add(day);
                        if (selectedDays.length == 7) {
                          repeatEveryday = true;
                        }
                      } else {
                        selectedDays.remove(day);
                        if (!selectedDays.contains(day)) {
                          repeatEveryday = false;
                        }
                      }
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "💾 저장하기",
                style: TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> pickTime(bool isStart) async {
    final result = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
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
}
