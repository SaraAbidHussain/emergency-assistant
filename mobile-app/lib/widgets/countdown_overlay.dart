import 'package:flutter/material.dart';

class CountdownOverlay extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onCancel;

  const CountdownOverlay({super.key, required this.secondsLeft, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$secondsLeft',
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}