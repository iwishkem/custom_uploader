import 'dart:io';

import 'package:custom_uploader/services/file_upload.dart';
import 'package:custom_uploader/utils/show_message.dart';
import 'package:custom_uploader/views/uploaders.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive/hive.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/database.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  Box<Share> shareBox = Hive.box<Share>("custom_upload");

  String _fileName = "";

  int _progressPercentValue = 0;

  bool _hasBeenPressed = false;


  void _setUploadProgress(int sentBytes, int totalBytes) {
    double progressValue = UploadProgress.remap(sentBytes.toDouble(), 0, totalBytes.toDouble(), 0, 1);

    progressValue = double.parse(progressValue.toStringAsFixed(2));

    if (progressValue != _progressPercentValue) {
      setState(() {
        progressValue = progressValue;
        _progressPercentValue = (progressValue * 100.0).toInt();
      });
    }
  }

  void _setState(String name) {
    if (name == "") {
      setState(() {
        _fileName = name;
        _hasBeenPressed = false;
      });
    } else {
      setState(() {
        _fileName = name;
        _hasBeenPressed = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _setUploadProgress(0, 0);
    if (shareBox.isNotEmpty) {
      if (!_hasBeenPressed) {
        // For sharing files coming from outside the app while the app is open
        ReceiveSharingIntent.getMediaStream().listen((
            List<SharedMediaFile> value) {
          setState(() async {
            if (value.isNotEmpty) {
              File file = File(value.first.path);
              FileService.fileUploadMultiPart(
                  file: file,
                  onUploadProgress: _setUploadProgress,
                  context: context, onSetState: _setState);
            }
          });
        }, onError: (err) {
          print("getIntentDataStream error: $err");
        });

        // For sharing files coming from outside the app while the app is closed
        ReceiveSharingIntent.getInitialMedia().then((
            List<SharedMediaFile> value) {
            print(value);
            if (value.isNotEmpty) {
              File file = File(value.first.path);
              FileService.fileUploadMultiPart(
                  file: file,
                  onUploadProgress: _setUploadProgress,
                  context: context, onSetState: _setState);
            }
        });
      }
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) => showAlert(context, "No Custom Uploaders", "Before you can begin uploading files, you need an uploader of your choice created and selected, then try again."));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton(itemBuilder: (context) {
            return [
              const PopupMenuItem<int>(
                value: 0,
                child: Text("View On Github"),
              ),
            ];
          },
            onSelected: (value) {
              if (value == 0) {
                launchUrl(Uri.parse("https://github.com/SrS2225a/custom_uploader"));
              }
            },)
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularPercentIndicator(
              radius: 120.0,
              percent:_progressPercentValue/100,
              center: ElevatedButton(onPressed: () async {
                if (shareBox.isNotEmpty) {
                  // if we are already uploading a file, don't allow the user to upload another one until the first one is done
                  if (!_hasBeenPressed) {
                    print("allow pick");
                    final filePicker = await FilePicker.platform.pickFiles(allowMultiple: false);
                    if (filePicker == null) {
                      const SnackBar(content: Text("No file has been selected. Select one then try again!"));
                      return;
                    }
                    File file = File(filePicker.files.first.path!);
                    await FileService.fileUploadMultiPart(
                        file: file, onUploadProgress: _setUploadProgress, context: context, onSetState: _setState);

                  }
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("No Custom Uploaders"),
                        content: Text("Before you can begin uploading files, you need an uploader of your choice created an selected, then try again."),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("OK"),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          )
                      ]
                      );
                    },
                  );
                }

              }, style: ElevatedButton.styleFrom(
                backgroundColor: _hasBeenPressed ? Colors.blue.withOpacity(0.38) : Colors.blue,
              ), child: _hasBeenPressed ? const Text("Uploading...") : const Text("Choose File")),
              progressColor: Colors.green[400],
            ),
            Text(_fileName)
          ],
      )

      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // show a list of custom uploaders
          Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const Uploader(title: "Custom Uploader"))
          );
        },
        tooltip: 'Custom Uploaders',
        child: const Icon(Icons.settings),
      ),
    );
  }
}

class UploadProgress {
  static double remap(double value, double originalMinValue, double originalMaxValue,
      double translatedMinValue, double translatedMaxValue) {
    if (originalMaxValue - originalMinValue == 0) return 0;

    return (value - originalMinValue) /
        (originalMaxValue - originalMinValue) *
        (translatedMaxValue - translatedMinValue) +
        translatedMinValue;
  }
}
