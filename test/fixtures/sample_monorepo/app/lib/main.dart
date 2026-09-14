import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import 'routing/app_router.dart';

void main() {
  runApp(const MonorepoApp());
}

class MonorepoApp extends StatelessWidget {
  const MonorepoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(theme: AppTheme.light, routerConfig: appRouter);
  }
}
