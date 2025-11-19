import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/report_page.dart';
import 'pages/routine_page.dart';
import 'pages/routine_create_page.dart'; // ✅ 추가

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
    const accent = Color(0xFFDDF1FF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: accent,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
      ),
      // ✅ /routine_create 라우트 등록
      routes: {
        '/routine_create': (context) => const RoutineCreatePage(),
      },
      home: Scaffold(
        // ⛔ 상단바 없음
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: accent,
          unselectedItemColor: Colors.grey,
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
