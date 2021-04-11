import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pedometer/pedometer.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:beacons_plugin/beacons_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');
final IOSInitializationSettings initializationSettingsIOS =
    IOSInitializationSettings();
final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
        'ShoeAlertChannel', 'ShoeAlert', 'Sends Notifications for ShoeAlert');
final NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);
const TAG = "ShoeAlert";
const LOG_LOCATION = "ShoeAlert";
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Stream<PedestrianStatus> pedestrianStatusStream;
  String shoeProximity = "";
  String distance = "";

  Timer timer;
  bool timerRunning = false;
  Duration s = Duration(seconds: 1);
  double timerLength = 30;

  startTimeout(double seconds) {
    var duration = s * seconds;
    timerRunning = !timerRunning;
    return new Timer.periodic(duration, handleTimeout);
  }

  void handleTimeout(Timer t) async {
    FlutterLogs.logToFile(
        logFileName: LOG_LOCATION,
        overwrite: false,
        logMessage: "user was walking without the shoe",
        appendTimeStamp: true);
    await flutterLocalNotificationsPlugin.show(
        0, 'Alert!', 'Wear Your Shoes!', platformChannelSpecifics);
  }

  final StreamController<String> beaconEventsController =
      StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    setUpLogs();
  }

  @override
  void dispose() {
    beaconEventsController.close();
    super.dispose();
  }

  void onPedestrianStatusChanged(PedestrianStatus event) async {
    FlutterLogs.logToFile(
        logFileName: LOG_LOCATION,
        overwrite: false,
        logMessage: "pedestrian status: ${event.status}",
        appendTimeStamp: true);
    if (event.status == "walking" &&
        shoeProximity != "Immediate" &&
        shoeProximity != "Near" &&
        !timerRunning) {
      timer = startTimeout(timerLength);
      FlutterLogs.logToFile(
          logFileName: LOG_LOCATION,
          overwrite: false,
          logMessage: "timer started because user is far away and walking",
          appendTimeStamp: true);
    } else if (event.status == "stopped" && timerRunning) {
      timerRunning = !timerRunning;
      timer.cancel();
      FlutterLogs.logToFile(
          logFileName: LOG_LOCATION,
          overwrite: false,
          logMessage:
              "timer canceled because user has stopped walking while timer is running",
          appendTimeStamp: true);
    }
  }

  void onPedestrianStatusError(error) {
    print(error);
  }

  void initPlatformState() async {
    if (Platform.isAndroid) {
      await BeaconsPlugin.setDisclosureDialogMessage(
          title: "Need Location Permission",
          message: "This app collects location data to work with beacons.");
      if (await Permission.activityRecognition.request().isGranted) {
        pedestrianStatusStream = Pedometer.pedestrianStatusStream;
        pedestrianStatusStream
            .listen(onPedestrianStatusChanged)
            .onError(onPedestrianStatusError);
      }
    } else {
      pedestrianStatusStream = Pedometer.pedestrianStatusStream;
      pedestrianStatusStream
          .listen(onPedestrianStatusChanged)
          .onError(onPedestrianStatusError);
    }

    BeaconsPlugin.listenToBeacons(beaconEventsController);

    await BeaconsPlugin.addRegion(
        "ShoeAlert", "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0");

    beaconEventsController.stream.listen(
        (data) {
          if (data.isNotEmpty) {
            var jsonData = jsonDecode(data);
            if (jsonData["uuid"].toString().toUpperCase() ==
                "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0") {
              distance = jsonData["distance"].toString();
              var proximity = jsonData["proximity"];
              if (timerRunning) {
                if (proximity == "Immediate" || proximity == "Near") {
                  timerRunning = !timerRunning;
                  timer.cancel();
                  FlutterLogs.logToFile(
                      logFileName: LOG_LOCATION,
                      overwrite: false,
                      logMessage:
                          "timer canceled because user is close to shoe",
                      appendTimeStamp: true);
                }
              }
              setState(() {
                shoeProximity = proximity;
              });
            }
          }
        },
        onDone: () {},
        onError: (error) {
          print(error);
        });

    await BeaconsPlugin.runInBackground(true);
    await BeaconsPlugin.startMonitoring;
    if (Platform.isAndroid) {
      BeaconsPlugin.channel.setMethodCallHandler((call) async {
        if (call.method == 'scannerReady') {
          await BeaconsPlugin.startMonitoring;
        }
      });
    } else if (Platform.isIOS) {
      await BeaconsPlugin.startMonitoring;
    }

    if (!mounted) return;
  }

  void setUpLogs() async {
    await FlutterLogs.initLogs(
        logLevelsEnabled: [
          LogLevel.INFO,
          LogLevel.WARNING,
          LogLevel.ERROR,
          LogLevel.SEVERE
        ],
        timeStampFormat: TimeStampFormat.TIME_FORMAT_READABLE,
        directoryStructure: DirectoryStructure.FOR_DATE,
        logTypesEnabled: [LOG_LOCATION],
        logFileExtension: LogFileExtension.TXT,
        logsWriteDirectoryName: "ShoeAlertLogs",
        logsExportDirectoryName: "ShoeAlertLogs/Exported",
        debugFileOperations: true,
        isDebuggable: true);
    Timer.periodic(Duration(seconds: 10), (t) {
      FlutterLogs.logToFile(
          logFileName: LOG_LOCATION,
          overwrite: false,
          logMessage: "beacon distance: $distance",
          appendTimeStamp: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ShoeAlert'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text("Timer Length"),
              Slider(
                value: timerLength,
                min: 30,
                max: 90,
                divisions: 2,
                label: timerLength.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    timerLength = value;
                  });
                },
              ),
              shoeProximity.isEmpty ? Text("Beacon Not Found") : SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
