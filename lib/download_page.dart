import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  List<FileSystemEntity> fileList = [];
  @override
  void initState() {
    getDownloadedFileList();
    super.initState();
  }

  getDownloadedFileList() async {
    final directory = (await getApplicationDocumentsDirectory()).path;
    final gDrivePath = '$directory/gDrive';
    final dir = Directory(gDrivePath);
    var entities = await dir.list().toList();
    log('Total Files: ${entities.length.toString()}');
    setState(() {
      fileList = entities;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: fileList.length,
        itemBuilder: (context, index) {
          var fileInfo = fileList[index];
          log(fileInfo.path);
          String fileName = fileInfo.path.split('/').last;
          return Column(
            children: [
              Text(fileName),
              const Divider(),
            ],
          );
        },
      ),
    );
  }
}
