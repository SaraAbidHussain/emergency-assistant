import 'package:flutter/material.dart';

/// Single source of truth for severity level -> color/label mapping.
/// Use this everywhere instead of duplicating switch statements per screen.

Color severityColor(int level) {
  switch (level) {
    case 1:
      return Colors.green.shade600;
    case 2:
      return Colors.amber.shade700;
    case 3:
      return Colors.orange.shade800;
    case 4:
      return Colors.red.shade800;
    default:
      return Colors.grey.shade600;
  }
}

/// Soft background tint for cards (level 1-3 use this; level 4 uses a
/// full dark/red lock screen instead, see EmergencyActiveScreen).
Color severityBackground(int level) {
  switch (level) {
    case 1:
      return Colors.green.shade50;
    case 2:
      return Colors.amber.shade50;
    case 3:
      return Colors.orange.shade50;
    case 4:
      return Colors.red.shade50;
    default:
      return Colors.grey.shade50;
  }
}

String severityLabel(int level) {
  switch (level) {
    case 1:
      return 'Minor';
    case 2:
      return 'Moderate';
    case 3:
      return 'Serious';
    case 4:
      return 'Critical';
    default:
      return 'Unknown';
  }
}