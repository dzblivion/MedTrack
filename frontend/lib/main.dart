import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MedTrackApp());
}

class MedTrackApp extends StatelessWidget {
  const MedTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedTrack',
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: Center(
          child: Text('MedTrack'),
        ),
      ),
    );
  }
}