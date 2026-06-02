import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../pages/audio_player_page.dart';
import '../pages/video_player_page.dart';
import '../pages/settings_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/audio-play',
          builder: (context, state) {
            final url = state.uri.queryParameters['url'] ?? '';
            return AudioPlayerPage(url: url);
          },
        ),
        GoRoute(
          path: '/video-play',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return VideoPlayerPage(
              url: extra['url'] ?? '',
              videoList: (extra['videoList'] as List<dynamic>?)?.cast() ?? [],
              currentIndex: extra['currentIndex'] ?? 0,
            );
          },
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/browse',
          builder: (context, state) {
            final path = state.extra as String? ?? '';
            return HomePage(path: path);
          },
        ),
      ],
    ),
  ],
);
