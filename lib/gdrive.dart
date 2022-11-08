import 'dart:developer';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gdrive_test/auth_client.dart';
import 'package:gdrive_test/download_page.dart';
import 'package:gdrive_test/show_dialog.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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

  final googleSignIn = GoogleSignIn.standard(scopes: [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ]);

  @override
  void initState() {
    _loginStatus = googleSignIn.currentUser != null;
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
              onPressed: _signIn,
              child: const Text("Sing in"),
            ),
            ElevatedButton(
              onPressed: _signOut,
              child: const Text("Sing out"),
            ),
            const Divider(),
            ElevatedButton(
              onPressed: _uploadToHidden,
              child: const Text("Upload to app folder (hidden)"),
            ),
            ElevatedButton(
              onPressed: _uploadToNormal,
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadPage()));
              },
              child: const Text("Downloads"),
            ),
          ],
        ),
      ),
    );
  }

  //:::::::::::::::::::::::::::::::::::: GOOGLE SIGN IN ::::::::::::::::::::::::::::::::::::
  Future<void> _signIn() async {
    final googleUser = await googleSignIn.signIn();
    try {
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final UserCredential loginUser = await FirebaseAuth.instance.signInWithCredential(credential);

        assert(loginUser.user?.uid == FirebaseAuth.instance.currentUser?.uid);
        log("Sign in");
        setState(() {
          _loginStatus = true;
        });
      }
    } catch (e) {
      log(e.toString());
    }
  }

  //:::::::::::::::::::::::::::::::::::: GOOGLE SIGN OUT ::::::::::::::::::::::::::::::::::::
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    setState(() {
      _loginStatus = false;
    });
    log("Sign out");
  }

  //:::::::::::::::::::::::::::::::::::: GOOGLE DRIVE API ::::::::::::::::::::::::::::::::::::

  Future<drive.DriveApi?> _getDriveApi() async {
    final googleUser = await googleSignIn.signIn();
    final headers = await googleUser?.authHeaders;
    log('::::::::::::${headers.toString()}');
    if (headers == null) {
      if (!mounted) return null;
      showMessage(context, "Sign-in first", "Error");
      return null;
    }

    final client = GoogleAuthClient(headers);
    final driveApi = drive.DriveApi(client);
    return driveApi;
  }

  //:::::::::::::::::::::::::::::::::::: UPLOAD FILE TO HIDDEN FOLDER ::::::::::::::::::::::::::::::::::::
    
  Future<void> _uploadToHidden() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return;
      }
      // Not allow a user to do something else
      if(!mounted) return;
      showLoadingIndicator(context);
      //Prepare selected file for upload
      var media = drive.Media(selectedFile.openRead(), selectedFile.lengthSync());

      // Set up File info
      var driveFile = drive.File();
      final timestamp = DateFormat("yyyy-MM-dd-hhmmss").format(DateTime.now());
      driveFile.name = "$timestamp-$selectedFileName";
      driveFile.modifiedTime = DateTime.now().toUtc();
      driveFile.parents = ["appDataFolder"];

      // Upload
      final response = await driveApi.files.create(driveFile, uploadMedia: media);
      log("response: $response");

      // simulate a slow process
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      // Remove a dialog
      Navigator.pop(context);
    }
  }

  //:::::::::::::::::::::::::::::::::::: CREATE FOLDER AND GET ID ::::::::::::::::::::::::::::::::::::

  Future<String?> _getFolderId(drive.DriveApi driveApi) async {
    const mimeType = "application/vnd.google-apps.folder";
    String folderName = "audacity-gdrive-test";

    try {
      final found = await driveApi.files.list(
        q: "mimeType = '$mimeType' and name = '$folderName'",
        $fields: "files(id, name)",
      );
      final files = found.files;
      if (files == null) {
        if (!mounted) return null;
        await showMessage(context, "Sign-in first", "Error");
        return null;
      }

      if (files.isNotEmpty) {
        return files.first.id;
      }

      // Create a folder
      var folder = drive.File();
      folder.name = folderName;
      folder.mimeType = mimeType;
      final folderCreation = await driveApi.files.create(folder);
      log("Folder ID: ${folderCreation.id}");

      return folderCreation.id;
    } catch (e) {
      log(e.toString());
      // I/flutter ( 6132): DetailedApiRequestError(
      //status: 403,
      //message: The granted scopes do not give access to all of the requested spaces.)
      return null;
    }
  }

  //:::::::::::::::::::::::::::::::::::: UPLOAD FILE TO NORMAL FOLDER ::::::::::::::::::::::::::::::::::::

  Future<void> _uploadToNormal() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return;
      }
      // Not allow a user to do something else
      if(!mounted) return;
      showLoadingIndicator(context);

      final folderId = await _getFolderId(driveApi);
      log(folderId.toString());
      if (folderId == null) {
        if (!mounted) return;
        await showMessage(context, "Failure", "Error");
        return;
      }

      //Prepare selected file for upload
      var media = drive.Media(selectedFile.openRead(), selectedFile.lengthSync());

      // Set up File info
      var driveFile = drive.File();
      final timestamp = DateFormat("yyyy-MM-dd-hhmmss").format(DateTime.now());
      driveFile.name = "$timestamp-$selectedFileName";
      driveFile.modifiedTime = DateTime.now().toUtc();
      driveFile.parents = [folderId];

      // Upload
      final response = await driveApi.files.create(driveFile, uploadMedia: media);
      log("response: $response");

      // simulate a slow process
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      // Remove a dialog
      Navigator.pop(context);
    }
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

  //:::::::::::::::::::::::::::::::::::: SHOW LIST FROM GDRIVE ::::::::::::::::::::::::::::::::::::

  Future<void> _showList() async {
    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      return;
    }

    final fileList = await driveApi.files.list(
      // spaces: 'appDataFolder',
      spaces: 'drive', //get files from google drive folder
      $fields: 'files(id, name, modifiedTime)',
    );
    final files = fileList.files;
    if (files == null) {
      if (!mounted) return;
      return showMessage(context, "Data not found", "");
    }

    final alert = AlertDialog(
      title: const Text("Item List"),
      content: SingleChildScrollView(
        child: ListBody(
          children: files
              .map((e) => InkWell(
                    onTap: () async {
                      try {
                        if (!mounted) return;
                        showLoadingIndicator(context);
                        drive.Media? response = await driveApi.files.get(
                          e.id!,
                          downloadOptions: drive.DownloadOptions.fullMedia,
                        ) as drive.Media?;
                        // var file = File(res.toString());
                        // log(file.path);
                        final String path = (await getApplicationDocumentsDirectory()).path;
                        final customPath = (await Directory('$path/gDrive').create()).path;
                        final String fileName = '$customPath/${e.name}';
                        File file = File(fileName);
                        List<int> dataStore = [];
                        response!.stream.listen((data) {
                          log("DataReceived: ${data.length}");
                          dataStore.insertAll(dataStore.length, data);
                        }, onDone: () {
                          log("Task Done");
                          file.writeAsBytes(dataStore);
                          // OpenFile.open(file.path);
                          log("File saved at ${file.path}");
                        }, onError: (error) {
                          log("Some Error");
                        });
                        // simulate a slow process
                        await Future.delayed(const Duration(seconds: 2));
                      } finally {
                        // Remove a dialog
                        Navigator.pop(context);
                      }
                    },
                    child: Text(e.name ?? "no-name"),
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
