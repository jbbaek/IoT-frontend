import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/report_page.dart';

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

  final List<Widget> _pages = [
    const DashboardPage(),
    const ReportPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFDDF1FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFDDF1FF),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {},
            ),
          ],
        ),
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.teal,
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
