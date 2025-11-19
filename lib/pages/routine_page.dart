import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// TODO: 백엔드에서 받은 IP로 변경해야 함!!
const String baseUrl = "http://<BACKEND_IP>:8000";

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  List<Map<String, dynamic>> routines = [];
  double volume = 5;
  bool isEditing = false;

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
        setState(() {
          routines = List<Map<String, dynamic>>.from(json.decode(res.body));
        });
      } else {
        debugPrint("GET 실패: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("GET 오류: $e");
    }
  }

  Future<void> updateRoutine(int id, Map<String, dynamic> updatedData) async {
    try {
      final url = Uri.parse("$baseUrl/routines/$id");
      final res = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(updatedData),
      );

      if (res.statusCode == 200) {
        loadRoutines();
      } else {
        debugPrint("PUT 실패: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("PUT 오류: $e");
    }
  }

  Future<void> deleteRoutine(int index) async {
    final id = routines[index]["id"];

    try {
      final url = Uri.parse("$baseUrl/routines/$id");
      final res = await http.delete(url);

      if (res.statusCode == 200) {
        setState(() => routines.removeAt(index));
      } else {
        debugPrint("DELETE 실패: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("DELETE 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ❗ 여기서는 Scaffold 쓰지 않고, 메인 Scaffold의 body 안에 들어가는 위젯만 만든다.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 제목
            const Text(
              "루틴 관리",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 루틴 만들기 카드
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "나만의 루틴으로 여러 서비스를 한 번에 실행해 보세요.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      // 👉 새 루틴 생성 화면으로 이동
                      final result =
                      await Navigator.pushNamed(context, '/routine_create');

                      // RoutineCreatePage에서 Navigator.pop(context, true)로 돌아오면
                      if (mounted && result == true) {
                        await loadRoutines();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "루틴 만들기",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 헤더 + 편집 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "나의 루틴 목록",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => isEditing = !isEditing);
                  },
                  child: Text(
                    isEditing ? "완료" : "편집",
                    style: const TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),

            const Divider(),

            // 루틴 목록
            Expanded(
              child: ListView.separated(
                itemCount: routines.length,
                separatorBuilder: (context, idx) =>
                const Divider(color: Colors.black12),
                itemBuilder: (context, index) {
                  final routine = routines[index];

                  return ListTile(
                    title: Text(routine["name"] ?? "이름 없음"),
                    subtitle: Text(
                      "집중 ${routine["focus"]}분 / 휴식 ${routine["rest"]}분",
                    ),
                    trailing: isEditing
                        ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 수정 버튼
                        IconButton(
                          icon: const Icon(Icons.edit,
                              color: Colors.blueAccent),
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                              context,
                              '/routine_create',
                              arguments: routine,
                            );

                            if (mounted && result == true) {
                              await loadRoutines();
                            }
                          },
                        ),

                        // 삭제 버튼
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.redAccent),
                          onPressed: () => deleteRoutine(index),
                        ),
                      ],
                    )
                        : Switch(
                      value: routine["active"] ?? false,
                      onChanged: (val) async {
                        final updated = {...routine, "active": val};
                        await updateRoutine(routine["id"], updated);
                      },
                      activeColor: Colors.blueAccent,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // 볼륨 조절
            Column(
              children: [
                const Text("루틴 볼륨 조절", style: TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        setState(() {
                          if (volume > 0) volume--;
                        });
                      },
                    ),
                    const Icon(Icons.volume_up, color: Colors.blueAccent),
                    Slider(
                      value: volume,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      activeColor: Colors.blueAccent,
                      onChanged: (value) {
                        setState(() => volume = value);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        setState(() {
                          if (volume < 10) volume++;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
