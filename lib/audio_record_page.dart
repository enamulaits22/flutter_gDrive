import 'dart:developer';
import 'dart:ui' as ui show Gradient;

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:gdrive_test/utils.dart';
import 'package:intl/intl.dart';

class AudioRecordPage extends StatefulWidget {
  const AudioRecordPage({super.key});

  @override
  State<AudioRecordPage> createState() => _AudioRecordPageState();
}

class _AudioRecordPageState extends State<AudioRecordPage> {
  late final RecorderController recorderController;
  late final PlayerController playerController;
  bool isPlaying = false;

  void _initializeRecorderController() {
    recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100
      ..bitRate = 48000;
  }

  void _initializeAudioController() {
    playerController = PlayerController();
  }

  Future<void> _startRecording() async {
    final String path = await Utils.createFolderPath('audioRecord');
    final timestamp = DateFormat("yyyy-MM-dd-hhmmss").format(DateTime.now());
    final String recordedFilePath = '$path/$timestamp.aac';
    await recorderController.record(recordedFilePath);
  }

  Future<void> _stopRecording() async {
    final path = await recorderController.stop();
    log(path.toString());
    playerController.preparePlayer(path!);
  }

  void _playandPause() async {
    if (playerController.playerState == PlayerState.playing) {
      await playerController.pausePlayer();
      setState(() {
        isPlaying = false;
      });
    } else {
      await playerController.startPlayer(finishMode: FinishMode.loop);
      setState(() {
        isPlaying = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeRecorderController();
    _initializeAudioController();
  }

  @override
  void dispose() {
    super.dispose();
    recorderController.dispose();
    playerController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Record'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AudioWaveforms(
              enableGesture: true,
              size: Size(MediaQuery.of(context).size.width, 120),
              recorderController: recorderController,
              waveStyle: WaveStyle(
                gradient: ui.Gradient.linear(
                  const Offset(70, 50),
                  Offset(MediaQuery.of(context).size.width, 0),
                  [Colors.red, Colors.green],
                ),
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: const Color(0xFF1E1B26),
              ),
              padding: const EdgeInsets.only(left: 18),
              margin: const EdgeInsets.symmetric(horizontal: 15),
            ),
            IconButton(
              icon: const Icon(Icons.mic),
              tooltip: 'Start recording',
              onPressed: _startRecording,
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Stop recording',
              onPressed: _stopRecording,
            ),
            const Divider(),
            AudioFileWaveforms(
              backgroundColor: Colors.blue,
              size: Size(MediaQuery.of(context).size.width, 70),
              playerController: playerController,
              density: 1.5,
              playerWaveStyle: const PlayerWaveStyle(
                scaleFactor: 0.8,
                fixedWaveColor: Colors.white30,
                liveWaveColor: Colors.white,
                waveCap: StrokeCap.butt,
              ),
            ),
            IconButton(
              icon: isPlaying ? const Icon(Icons.pause) : const Icon(Icons.play_arrow),
              tooltip: 'Stop recording',
              onPressed: _playandPause,
            ),
          ],
        ),
      ),
    );
  }
}
