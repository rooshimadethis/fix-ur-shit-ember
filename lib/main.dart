import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/ember_service.dart';
import 'theme/app_theme.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EmberService()),
      ],
      child: MaterialApp(
        title: 'Fix Ur Shit Ember',
        theme: AppTheme.darkTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
