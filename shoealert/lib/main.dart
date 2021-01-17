import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pedometer/pedometer.dart';
import 'package:beacons_plugin/beacons_plugin.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// data to collect - would like to be able to make a histogram
// save walking/not walking data
// data every 10 seconds - range (in numbers) of BLE device (for development)
// save add timer started/stopped/ended data

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
  String shoeProximity = '?';

  Timer timer;
  bool timerRunning = false;
  Duration s = Duration(seconds: 1);
  double timerLength = 30;

  startTimeout(double seconds) {
    var duration = s * seconds;
    timerRunning = !timerRunning;
    return new Timer(duration, handleTimeout);
  }

  void handleTimeout() async {
    print("user was walking without the shoe");
    await flutterLocalNotificationsPlugin.show(
        0, 'Alert!', 'Wear Your Shoes!', platformChannelSpecifics);
  }

  final StreamController<String> beaconEventsController =
      StreamController<String>.broadcast();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    beaconEventsController.close();
    super.dispose();
  }

  void onPedestrianStatusChanged(PedestrianStatus event) async {
    print(event.status);
    if (event.status == "walking" &&
        shoeProximity != "Immediate" &&
        shoeProximity != "Near" &&
        !timerRunning) {
      timer = startTimeout(timerLength);
      print("timer started because user is far away and walking");
    } else if (event.status == "stopped" && timerRunning) {
      timerRunning = !timerRunning;
      timer.cancel();
      print(
          "timer canceled because user has stopped walking while timer is running");
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
              var proximity = jsonData["proximity"];
              if (timerRunning) {
                if (proximity == "Immediate" || proximity == "Near") {
                  timerRunning = !timerRunning;
                  timer.cancel();
                  print("timer canceled because user is close to shoe");
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

    if (!mounted) return;
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
              )
            ],
          ),
        ),
      ),
    );
  }
}
