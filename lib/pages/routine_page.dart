import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "http://172.16.255.102:8000";

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  List<Map<String, dynamic>> routines = [];
  double volume = 5;
  bool isEditing = false;

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return <String>[];
  }

  @override
  void initState() {
    super.initState();
    loadRoutines();
  }

  Future<void> loadRoutines() async {
    try {
      final url = Uri.parse("$baseUrl/routines");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final List<dynamic> raw = json.decode(res.body);

        setState(() {
          routines = raw.map<Map<String, dynamic>>((e) {
            final map = Map<String, dynamic>.from(e);
            return {
              "id": _toInt(map["id"]),
              "title": (map["title"] ?? map["name"] ?? "").toString(),
              "focus": _toInt(map["focus"]) ?? 0,
              "rest": _toInt(map["rest"]) ?? 0,
              "startTime": map["startTime"],
              "endTime": map["endTime"],
              "repeatEveryday": (map["repeatEveryday"] ?? false) == true,
              "selectedDays": _toStringList(map["selectedDays"] ?? map["selected_days"]),
              "items": (map["items"] as List? ?? [])
                  .map((it) => Map<String, dynamic>.from(it))
                  .toList(),
              "active": (map["active"] ?? false) == true,
            };
          }).toList();
        });
      } else {
        debugPrint("GET 실패: ${res.statusCode} / ${res.body}");
      }
    } catch (e) {
      debugPrint("GET 오류: $e");
    }
  }

  // ✅ 서버가 부분 수정(명세) 지원하면 {"active":true}만 보내고,
  // ✅ 만약 422로 튕기면 "전체 루틴 바디"로 한번 더 시도(호환)
  Future<void> updateRoutineActive(Map<String, dynamic> routine, bool active) async {
    final id = _toInt(routine["id"]);
    if (id == null) return;

    Future<http.Response> putBody(Map<String, dynamic> body) {
      final url = Uri.parse("$baseUrl/routines/$id");
      return http.put(url, headers: {"Content-Type": "application/json"}, body: json.encode(body));
    }

    // 1차: 부분 수정
    final res1 = await putBody({"active": active});

    if (res1.statusCode == 200) {
      await loadRoutines();
      return;
    }

    // 2차: 전체 바디(명세 + 구버전 호환)
    final title = (routine["title"] ?? "").toString().trim();
    final selected = (routine["selectedDays"] as List? ?? []).map((e) => e.toString().toUpperCase()).toList();

    final codeToInt = const {"MON": 1, "TUE": 2, "WED": 3, "THU": 4, "FRI": 5, "SAT": 6, "SUN": 7};
    final selectedInt = selected.map((c) => codeToInt[c] ?? 1).toList();

    final full = {
      "title": title,
      "name": title,
      "focus": routine["focus"] ?? 0,
      "rest": routine["rest"] ?? 0,
      "startTime": routine["startTime"],
      "endTime": routine["endTime"],
      "repeatEveryday": (routine["repeatEveryday"] ?? false) == true,
      "selectedDays": selected,
      "selected_days": selectedInt,
      "items": (routine["items"] as List? ?? []).map((it) {
        final m = Map<String, dynamic>.from(it);
        return {
          "name": (m["name"] ?? m["title"] ?? "").toString(),
          "duration": m["duration"] ?? 0,
          "time": m["time"],
        };
      }).toList(),
      "active": active,
    };

    final res2 = await putBody(full);

    if (res2.statusCode == 200) {
      await loadRoutines();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("활성화 변경 실패: ${res2.statusCode} / ${res2.body}")),
      );
    }
  }

  Future<void> deleteRoutine(int index) async {
    final id = _toInt(routines[index]["id"]);
    if (id == null) return;

    try {
      final url = Uri.parse("$baseUrl/routines/$id");
      final res = await http.delete(url);

      if (res.statusCode == 204) {
        setState(() => routines.removeAt(index));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("루틴이 삭제되었습니다.")),
        );
      } else {
        debugPrint("DELETE 실패: ${res.statusCode} / ${res.body}");
      }
    } catch (e) {
      debugPrint("DELETE 오류: $e");
    }
  }

  Future<void> confirmDeleteRoutine(int index) async {
    final title = (routines[index]["title"] ?? "이 루틴").toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("루틴 삭제"),
        content: Text("‘$title’을(를) 삭제하시겠습니까?\n삭제하면 복구할 수 없습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("삭제"),
          ),
        ],
      ),
    );

    if (ok == true) await deleteRoutine(index);
  }

  Map<String, dynamic> normalizeForEdit(Map<String, dynamic> r) {
    return {
      "id": _toInt(r["id"]),
      "title": (r["title"] ?? r["name"] ?? "").toString(),
      "focus": _toInt(r["focus"]) ?? 0,
      "rest": _toInt(r["rest"]) ?? 0,
      "startTime": r["startTime"],
      "endTime": r["endTime"],
      "repeatEveryday": (r["repeatEveryday"] ?? false) == true,
      "selectedDays": _toStringList(r["selectedDays"] ?? r["selected_days"]),
      "items": (r["items"] as List? ?? []).map((it) => Map<String, dynamic>.from(it)).toList(),
      "active": (r["active"] ?? false) == true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  const Text("나만의 루틴으로 여러 서비스를 한 번에 실행해 보세요.",
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(context, '/routine_create');
                      if (mounted && result == true) await loadRoutines();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("루틴 만들기", style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("나의 루틴 목록", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton(
                  onPressed: () => setState(() => isEditing = !isEditing),
                  child: Text(isEditing ? "완료" : "편집", style: const TextStyle(color: Colors.black)),
                ),
              ],
            ),
            const Divider(),

            Expanded(
              child: routines.isEmpty
                  ? const Center(child: Text("저장된 루틴이 없습니다."))
                  : ListView.separated(
                itemCount: routines.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.black12),
                itemBuilder: (context, index) {
                  final routine = routines[index];
                  return ListTile(
                    title: Text((routine["title"] ?? "제목 없음").toString()),
                    subtitle: Text("집중 ${routine["focus"]}분 / 휴식 ${routine["rest"]}분"),
                    trailing: isEditing
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () async {
                            final normalized = normalizeForEdit(routine);
                            final result = await Navigator.pushNamed(
                              context,
                              '/routine_create',
                              arguments: normalized,
                            );
                            if (mounted && result == true) await loadRoutines();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => confirmDeleteRoutine(index),
                        ),
                      ],
                    )
                        : Switch(
                      value: (routine["active"] ?? false) == true,
                      onChanged: (val) => updateRoutineActive(routine, val),
                      activeColor: Colors.blueAccent,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))],
              ),
              child: Column(
                children: [
                  const Text("루틴 볼륨 조절", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => setState(() => volume = (volume - 1).clamp(0, 10)),
                      ),
                      const Icon(Icons.volume_up, color: Colors.blueAccent),
                      Expanded(
                        child: Slider(
                          value: volume,
                          min: 0,
                          max: 10,
                          divisions: 10,
                          activeColor: Colors.blueAccent,
                          onChanged: (value) => setState(() => volume = value),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => setState(() => volume = (volume + 1).clamp(0, 10)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
