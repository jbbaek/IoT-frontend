import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/report_page.dart';
import 'pages/routine_page.dart';
import 'pages/routine_create_page.dart';

void main() {
  runApp(const IotApp());
}

class IotApp extends StatefulWidget {
  const IotApp({super.key});

  @override
  State<IotApp> createState() => _IotAppState();
}

class _IotAppState extends State<IotApp> {
  int _selectedIndex = 0;

  // 하단바 탭 3개에 대응하는 페이지
  final List<Widget> _pages = const [
    DashboardPage(),
    ReportPage(),
    RoutinePage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFDDF1FF);         // 배경색(연한 하늘색)
    const selected = Colors.teal;         // ✅ 선택 색(진하게)
    const unselected = Colors.grey;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: bg,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: bg,
          brightness: Brightness.light,
        ),
      ),

      // ✅ /routine_create 라우트 등록 (수정/생성 공통 사용)
      routes: {
        '/routine_create': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
          return RoutineCreatePage(existingRoutine: args);
        },
      },

      home: Scaffold(
        body: _pages[_selectedIndex],

        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: selected,
          unselectedItemColor: unselected,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '대시보드',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: '리포트',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              label: '공부 시간',
            ),
          ],
        ),
      ),
    );
  }
}
