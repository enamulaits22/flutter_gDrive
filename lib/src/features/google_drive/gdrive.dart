import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gdrive_test/src/features/audio_recording/audio_record_page.dart';
import 'package:gdrive_test/src/features/google_drive/download_page.dart';
import 'package:gdrive_test/src/services/gdrive_service.dart';

class GoogleDriveTest extends StatefulWidget {
  const GoogleDriveTest({super.key});

  @override
  State<GoogleDriveTest> createState() => _GoogleDriveTest();
}

class _GoogleDriveTest extends State<GoogleDriveTest> {
  bool _loginStatus = false;
  String selectedFilePath = '';
  String selectedFileName = '';
  File selectedFile = File('');

  @override
  void initState() {
    _loginStatus = GoogleDriveService.googleSignIn.currentUser != null;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Google Drive Test"),
        ),
        body: Column(
          children: [
            Text("Sign in status: ${_loginStatus ? "In" : "Out"}"),
            ElevatedButton(
              onPressed: () async {
                bool status = await GoogleDriveService.instance.signInWithGoogle();
                setState(() {
                  _loginStatus = status;
                });
              },
              child: const Text("Sing in"),
            ),
            ElevatedButton(
              onPressed: () async {
                bool status = await GoogleDriveService.instance.signOut();
                setState(() {
                  _loginStatus = status;
                });
              },
              child: const Text("Sing out"),
            ),
            const Divider(),
            ElevatedButton(
              onPressed: () {
                GoogleDriveService.instance.uploadToHidden(
                  context,
                  selectedFile,
                  selectedFileName,
                );
              },
              child: const Text("Upload to app folder (hidden)"),
            ),
            ElevatedButton(
              onPressed: () {
                GoogleDriveService.instance.uploadToNormal(
                  context,
                  selectedFile,
                  selectedFileName,
                );
              },
              child: const Text("Upload to normal folder"),
            ),
            ElevatedButton(
              onPressed: _showList,
              child: const Text("Show the data list"),
            ),
            ElevatedButton(
              onPressed: _openFilePicker,
              child: const Text("Pick File"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DownloadPage()),
                );
              },
              child: const Text("Downloads"),
            ),
            const Divider(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AudioRecordPage()),
                );
              },
              child: const Text("Record Audio"),
            ),
          ],
        ),
      ),
    );
  }

  //:::::::::::::::::::::::::::::::::::: PICK FILES ::::::::::::::::::::::::::::::::::::
  Future<void> _openFilePicker() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      selectedFile = file;
      selectedFilePath = file.path;
      selectedFileName = result.files.last.name;
      log('$selectedFilePath::::$selectedFileName');
    } else {
      // User canceled the picker
    }
  }

  Future<void> _showList() async {
    final fileList = await GoogleDriveService.instance.fetchFilesFromGoogleDrive(
      context,
      false,
    );

    final alert = AlertDialog(
      title: const Text("Item List"),
      content: SingleChildScrollView(
        child: ListBody(
          children: fileList!
              .map((fileInfo) => InkWell(
                    onTap: () async {
                      GoogleDriveService.instance.downloadFromGoogleDrive(context, fileInfo);
                    },
                    child: Text(fileInfo.name ?? "no-name"),
                  ))
              .toList(),
        ),
      ),
    );

    return showDialog(
      context: context,
      builder: (BuildContext context) => alert,
    );
  }
}
