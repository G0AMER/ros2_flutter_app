import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ros2_flutter_app/ros_service.dart';
import 'map_view.dart';


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
        title: 'ROS2 Robot Visualizer',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const RobotVisualizerScreen(),
      ),
    );
  }
}


