import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'map_view.dart';
import 'ros_service.dart';
import 'isFound.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RosModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ROS2 Robot Visualizer',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const RobotVisualizerScreen(),
      ),
    );
  }
}


