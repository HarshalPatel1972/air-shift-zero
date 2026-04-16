import 'package:flutter/material.dart';
import 'theme/colors.dart';
import 'theme/typography.dart';

class AirShiftApp extends StatelessWidget {
  const AirShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Shift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AirShiftColors.bgBase,
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: AirShiftTypography.body,
          headlineMedium: AirShiftTypography.emphasis,
          labelSmall: AirShiftTypography.label,
        ),
      ),
      home: const FoundationScreen(),
    );
  }
}

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.airplanemode_active,
              color: AirShiftColors.bluePrimary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Air Shift',
              style: AirShiftTypography.emphasis.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 8),
            const Text(
              'Foundation Ready',
              style: AirShiftTypography.label,
            ),
          ],
        ),
      ),
    );
  }
}
