import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gdrive_test/src/services/auth_client.dart';
import 'package:gdrive_test/src/widgets/show_dialog.dart';
import 'package:gdrive_test/src/utils/utils.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';

class GoogleDriveService {
  GoogleDriveService._();
  static GoogleDriveService instance = GoogleDriveService._();

  static final googleSignIn = GoogleSignIn.standard(scopes: [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ]);

  //:::::::::::::::::::::::::::::::::::: GOOGLE SIGN IN ::::::::::::::::::::::::::::::::::::
  Future<bool> signInWithGoogle() async {
    bool loginStatus = false;
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
        loginStatus = true;
        return loginStatus;
      }
    } catch (e) {
      log(e.toString());
    }
    return loginStatus;
  }

  //:::::::::::::::::::::::::::::::::::: GOOGLE SIGN OUT ::::::::::::::::::::::::::::::::::::
  Future<bool> signOut() async {
    await FirebaseAuth.instance.signOut();
    await googleSignIn.signOut();
    log("Sign out");
    return false;
  }

  //:::::::::::::::::::::::::::::::::::: GOOGLE DRIVE API ::::::::::::::::::::::::::::::::::::
  Future<drive.DriveApi?> getDriveApi(BuildContext context) async {
    final googleUser = await googleSignIn.signIn();
    final headers = await googleUser?.authHeaders;
    log('::::::::::::${headers.toString()}');
    if (headers == null) {
      // ignore: use_build_context_synchronously
      showMessage(context, "Sign-in first", "Error");
      return null;
    }

    final client = GoogleAuthClient(headers);
    final driveApi = drive.DriveApi(client);
    return driveApi;
  }

  //:::::::::::::::::::::::::::::::::::: UPLOAD FILE TO HIDDEN FOLDER ::::::::::::::::::::::::::::::::::::
  Future<void> uploadToHidden(BuildContext context, File selectedFile, String selectedFileName) async {
    try {
      final driveApi = await getDriveApi(context);
      if (driveApi == null) {
        return;
      }
      // Not allow a user to do something else
      // ignore: use_build_context_synchronously
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
  Future<String?> getFolderId(drive.DriveApi driveApi, BuildContext context) async {
    const mimeType = "application/vnd.google-apps.folder";
    String folderName = "audacity-gdrive-test";

    try {
      final found = await driveApi.files.list(
        q: "mimeType = '$mimeType' and name = '$folderName'",
        $fields: "files(id, name)",
      );
      final files = found.files;
      if (files == null) {
        // ignore: use_build_context_synchronously
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
  Future<void> uploadToNormal(BuildContext context, File selectedFile, String selectedFileName) async {
    try {
      final driveApi = await getDriveApi(context);
      if (driveApi == null) {
        return;
      }
      // ignore: use_build_context_synchronously
      showLoadingIndicator(context);

      // ignore: use_build_context_synchronously
      final folderId = await getFolderId(driveApi, context);
      log(folderId.toString());
      if (folderId == null) {
        // ignore: use_build_context_synchronously
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
      final response =
          await driveApi.files.create(driveFile, uploadMedia: media);
      log("response: $response");

      // simulate a slow process
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      // Remove a dialog
      Navigator.pop(context);
    }
  }

  //:::::::::::::::::::::::::::::::::::: DOWNLOAS FROM GOOGLE DRIVE ::::::::::::::::::::::::::::::::::::
  Future<void> downloadFromGoogleDrive (BuildContext context, drive.File driveFile) async {
    final driveApi = await getDriveApi(context);
    if (driveApi == null) {
      return;
    }
    try {
      // ignore: use_build_context_synchronously
      showLoadingIndicator(context);
      drive.Media? response = await driveApi.files.get(
        driveFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media?;
      // var file = File(res.toString());
      // log(file.path);
      final customPath = await Utils.createOrGetFolderPath('gDrive');
      final String fileName = '$customPath/${driveFile.name}';
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
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }

  //:::::::::::::::::::::::::::::::::::: SHOW LIST FROM GDRIVE ::::::::::::::::::::::::::::::::::::
  Future<List<drive.File>?> fetchFilesFromGoogleDrive(BuildContext context, bool showFilesFromHiddenFolder) async {
    final driveApi = await GoogleDriveService.instance.getDriveApi(context);
    if (driveApi == null) {
      return null;
    }

    final fileList = await driveApi.files.list(
      // spaces: 'appDataFolder', //get files from hidden google drive folder
      // spaces: 'drive', //get files from normal google drive folder
      spaces: showFilesFromHiddenFolder ? 'appDataFolder' : 'drive', 
      $fields: 'files(id, name, modifiedTime)',
    );
    
    final files = fileList.files;
    if (files == null) {
      // ignore: use_build_context_synchronously
      showMessage(context, "Data not found", "");
    }
    return files;
  }
}