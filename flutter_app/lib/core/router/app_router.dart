import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/trip/presentation/responsive_shell.dart';
import '../../features/trip/presentation/trip_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ResponsiveShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TripListScreen(),
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
