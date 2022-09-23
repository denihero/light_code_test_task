import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? countryName;
  String? cityName;

  bool _isLoadingVideo = true;
  bool isLoadingText = false;
  bool _isRecordingVideo = false;
  bool isRecordingSound = false;


  late CameraController _cameraController;

  final record = Record();
  late FlutterSoundRecorder _recordingSession;


  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initSound();
  }

  void _initSound() async {
    _recordingSession = FlutterSoundRecorder();
    await _recordingSession.openAudioSession(
        focus: AudioFocus.requestFocusAndStopOthers,
        category: SessionCategory.playAndRecord,
        mode: SessionMode.modeDefault,
        device: AudioDevice.speaker);
    await _recordingSession.setSubscriptionDuration(const Duration(
        milliseconds: 10));
    await Permission.microphone.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }


  _initCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);
    _cameraController = CameraController(front, ResolutionPreset.max);
    await _cameraController.initialize();
    setState(() => _isLoadingVideo = false);
  }

  Future<String?> _startRecording() async {

    if(isRecordingSound) {
      _recordingSession.closeAudioSession();
      setState(() {
        isRecordingSound = false;
      });
      return await _recordingSession.stopRecorder();
    }else{
      Directory? tempDir = await getExternalStorageDirectory();
      print(tempDir);
      String path = '${tempDir?.path}/${DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now())}.aac';
      Directory directory = Directory(tempDir!.path);
      if (!directory.existsSync()) {
        directory.createSync();
      }
      _recordingSession.openAudioSession();
      await _recordingSession.startRecorder(
        toFile: path,
        codec: Codec.aacADTS ,
      );
      setState(() {
        isRecordingSound = true;
      });
      StreamSubscription? recorderSubscription =
      _recordingSession.onProgress?.listen((e) {
        var date = DateTime.fromMillisecondsSinceEpoch(
            e.duration.inMilliseconds,
            isUtc: true);

      });
      recorderSubscription?.cancel();
    }
    return '';

  }

  Future<String> _getCountryName() async {
    LocationPermission permission;
    permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    debugPrint('location: ${position.latitude}');
    final coordinates = await Geocoder2.getDataFromCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
        googleMapApiKey: 'AIzaSyBV6xu9mWsNbQTtxuhdy4ahUkDd5zgE3EU');
    isLoadingText = true;
    setState(() {
      countryName = coordinates.country;
      cityName = coordinates.state;
    });
    return coordinates.country;
  }

  Future<void> _recordVideo() async {
    if (_isRecordingVideo) {
      final file = await _cameraController.stopVideoRecording();
      setState(() => _isRecordingVideo = false);
      await GallerySaver.saveVideo(file.path);
      File(file.path).deleteSync();
    } else {
      await _cameraController.prepareForVideoRecording();
      await _cameraController.startVideoRecording();
      setState(() => _isRecordingVideo = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
           isLoadingText ? Text(
              '${countryName ?? ''},${cityName ?? ''}',
              style: Theme.of(context).textTheme.headline4,
            ):const SizedBox(),
            _isLoadingVideo
                ? const CircularProgressIndicator()
                : CameraPreview(_cameraController)
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _getCountryName();
          _recordVideo();
          _startRecording();
        },
        tooltip: 'Increment',
        child: Icon(
          _isRecordingVideo ? Icons.stop : Icons.circle,
          color: Colors.white,
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
