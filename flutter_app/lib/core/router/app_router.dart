import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/trip/presentation/responsive_shell.dart';
import '../../features/trip/presentation/trip_list_screen.dart';
import '../theme/kakao_theme.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ResponsiveShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/chat/:tripId',
          builder: (context, state) {
            final tripId = state.pathParameters['tripId']!;
            return ChatScreen(tripId: tripId);
          },
        ),
      ],
    ),
  ],
);

/// Shows TripListScreen on mobile, empty state on desktop
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;
    if (isWide) {
      return Scaffold(
        backgroundColor: KakaoTheme.background,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flight_takeoff, size: 64, color: KakaoTheme.myBubble),
                const SizedBox(height: 16),
                const Text(
                  '여행을 선택하거나',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KakaoTheme.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  '새로운 여행을 시작하세요!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KakaoTheme.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  '왼쪽 목록에서 여행을 선택하거나\n+ 버튼으로 새 여행을 만들어보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: KakaoTheme.secondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const TripListScreen();
  }
}
