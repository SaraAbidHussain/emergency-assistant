import 'package:flutter/material.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'models/user_model.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Request notification permission and print the device token for testing.
  await FirebaseMessaging.instance.requestPermission();
  final token = await FirebaseMessaging.instance.getToken();
  print('=== FCM DEVICE TOKEN ===');
  print(token);
  print('========================');

  await registerDeviceToken(); 

  runApp(const EmergencyAssistantApp());
}

Future<void> registerDeviceT
oken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      print('Could not get FCM token, skipping registration.');
      return;
    }
    final response = await http.post(
      Uri.parse('http://172.16.20.162:8000/contacts/user-123/add'), // 👈 apna IP daalo
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contact_id': 'phone-1',
        'device_token': token,
      }),
    );
    if (response.statusCode == 200) {
      print('Device token registered successfully.');
    } else {
      print('Token registration failed: ${response.statusCode}');
    }
  } catch (e) {
    print('Token registration error (ignored): $e');
  }
}

class EmergencyAssistantApp extends StatelessWidget {
  const EmergencyAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const LoginScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  final UserModel currentUser;
  const RootScreen({super.key, required this.currentUser});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(currentUser: widget.currentUser),
      const ContactsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Contacts'),
        ],
      ),
    );
  }
}
