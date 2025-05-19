// lib/main.dart

import 'package:flutter/material.dart';
import 'ros_service.dart';
import 'map_view.dart';

// ▶︎ List of the 80 COCO class names (YOLO IDs 0–79)
const List<String> cocoClasses = [
  'person',
  'bicycle',
  'car',
  'motorbike',
  'aeroplane',
  'bus',
  'train',
  'truck',
  'boat',
  'traffic light',
  'fire hydrant',
  'stop sign',
  'parking meter',
  'bench',
  'bird',
  'cat',
  'dog',
  'horse',
  'sheep',
  'cow',
  'elephant',
  'bear',
  'zebra',
  'giraffe',
  'backpack',
  'umbrella',
  'handbag',
  'tie',
  'suitcase',
  'frisbee',
  'skis',
  'snowboard',
  'sports ball',
  'kite',
  'baseball bat',
  'baseball glove',
  'skateboard',
  'surfboard',
  'tennis racket',
  'bottle',
  'wine glass',
  'cup',
  'fork',
  'knife',
  'spoon',
  'bowl',
  'banana',
  'apple',
  'sandwich',
  'orange',
  'broccoli',
  'carrot',
  'hot dog',
  'pizza',
  'donut',
  'cake',
  'chair',
  'sofa',
  'pottedplant',
  'bed',
  'diningtable',
  'toilet',
  'tvmonitor',
  'laptop',
  'mouse',
  'remote',
  'keyboard',
  'cell phone',
  'microwave',
  'oven',
  'toaster',
  'sink',
  'refrigerator',
  'book',
  'clock',
  'vase',
  'scissors',
  'teddy bear',
  'hair drier',
  'toothbrush',
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Connect to rosbridge
  RosService().connect('ws://192.168.0.6:9090');
  runApp(const RosSearchApp());
}

class RosSearchApp extends StatelessWidget {
  const RosSearchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS2 YOLO Search',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? _selectedId;

  void _publishTarget() {
    if (_selectedId == null) return;
    // Publish selected class ID to ROS2
    RosService().publish('/search_target_id', {'data': _selectedId});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Searching for: [$_selectedId] – ${cocoClasses[_selectedId!]}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Object to Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'YOLO class ID'),
              items: List.generate(
                cocoClasses.length,
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text('$i – ${cocoClasses[i]}'),
                ),
              ),
              value: _selectedId,
              onChanged: (id) => setState(() => _selectedId = id),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Start Search'),
              onPressed: _publishTarget,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: MapView(), // your tap‐and‐drag map widget
          ),
        ],
      ),
    );
  }
}
