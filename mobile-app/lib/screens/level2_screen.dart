import 'package:flutter/material.dart';
import 'emergency_active_screen.dart';

class Level2Screen extends StatelessWidget {
  final int initialSeverity;
  final String userId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onUserSafe;

  const Level2Screen({
    super.key,
    required this.initialSeverity,
    required this.userId,
    this.initialData,
    this.onUserSafe,
  });

  @override
  Widget build(BuildContext context) {
    return EmergencyActiveScreen(
      initialSeverity: initialSeverity,
      userId: userId,
      initialData: initialData,
      onUserSafe: onUserSafe,
    );
  }
}