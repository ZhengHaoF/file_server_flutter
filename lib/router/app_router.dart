import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../pages/audio_player_page.dart';
import '../pages/text_viewer_page.dart';
import '../pages/video_player_page.dart';
import '../pages/settings_page.dart';
import '../pages/download_manager_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: '/downloads',
          builder: (context, state) => const DownloadManagerPage(),
        ),
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
          path: '/text-view',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return TextViewerPage(
              url: extra['url'] ?? '',
              fileName: extra['fileName'] ?? '',
            );
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
          pageBuilder: (context, state) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/browse',
          pageBuilder: (context, state) {
            final path = state.extra as String? ?? '';
            return CustomTransitionPage(
              key: state.pageKey,
              child: HomePage(path: path),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                  child: child,
                );
              },
            );
          },
        ),
      ],
    ),
  ],
);
