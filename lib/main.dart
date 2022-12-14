import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gdrive_test/src/features/google_drive/gdrive.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Drive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
      ),
      home: const GoogleDriveTest(),
    );
  }
}