import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MdrMarketApp extends ConsumerWidget {
  const MdrMarketApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MDR Market',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
