import 'package:flutter/material.dart';

Future<void> showMessage(BuildContext context, String msg, String title) async {
  final alert = AlertDialog(
    title: Text(title),
    content: Text(msg),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text("OK"),
      ),
    ],
  );
  await showDialog(
    context: context,
    builder: (BuildContext context) => alert,
  );
}

Future<void> showLoadingIndicator(BuildContext context) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    transitionDuration: const Duration(seconds: 2),
    barrierColor: Colors.black.withOpacity(0.5),
    pageBuilder: (context, animation, secondaryAnimation) => const Center(
      child: CircularProgressIndicator(),
    ),
  );
}
