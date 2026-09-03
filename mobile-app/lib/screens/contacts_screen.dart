import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Text(
          'Trusted contacts will appear here',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
    );
  }
}
