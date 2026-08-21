import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/muse_theme.dart';

class MuseApp extends ConsumerWidget {
  const MuseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Muse',
      debugShowCheckedModeBanner: false,
      theme: MuseTheme.light,
      routerConfig: router,
    );
  }
}