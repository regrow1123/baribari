import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/kakao_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '바리바리',
      theme: KakaoTheme.themeData,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
