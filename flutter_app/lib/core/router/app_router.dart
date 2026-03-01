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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✈️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                '여행을 선택하거나\n새로운 여행을 시작하세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: KakaoTheme.primary.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const TripListScreen();
  }
}
