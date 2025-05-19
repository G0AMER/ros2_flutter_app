import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

class RosService {
  static final RosService _instance = RosService._internal();
  factory RosService() => _instance;
  RosService._internal();

  WebSocketChannel? _channel;
  Stream<dynamic>? _broadcastStream;
  final _topicStreams = <String, Stream<Map<String, dynamic>>>{};

  void connect(String url, Function onConnected, Function onError) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _broadcastStream = _channel!.stream.asBroadcastStream();
      onConnected();
    } catch (e) {
      onError(e.toString());
    }
  }

  void reconnect(String url, Function onConnected, Function onError) {
    dispose();
    Future.delayed(const Duration(seconds: 2), () {
      connect(url, onConnected, onError);
    });
  }

  Stream<Map<String, dynamic>> subscribe(String topic, String type) {
    if (_topicStreams.containsKey(topic)) return _topicStreams[topic]!;
    if (_channel == null) throw Exception('WebSocket not connected');
    _channel!.sink.add(
      jsonEncode({'op': 'subscribe', 'topic': topic, 'type': type}),
    );
    final stream = _broadcastStream!
        .map((m) {
      try {
        return jsonDecode(m as String) as Map<String, dynamic>;
      } catch (e) {
        throw Exception('Invalid message format: $e');
      }
    })
        .where((m) => m['topic'] == topic)
        .cast<Map<String, dynamic>>();
    _topicStreams[topic] = stream;
    return stream;
  }

  void publish(String topic, Map<String, dynamic> msg) {
    if (_channel == null) return;
    try {
      _channel!.sink.add(
        jsonEncode({'op': 'publish', 'topic': topic, 'msg': msg}),
      );
    } catch (e) {
      // Handle publish error silently or log it
    }
  }

  void publishInitialPose({
    required double x,
    required double y,
    required double yaw,
  }) {
    final now = DateTime.now();
    final header = {
      'stamp': {
        'sec': now.millisecondsSinceEpoch ~/ 1000,
        'nanosec': (now.millisecondsSinceEpoch % 1000) * 1000000,
      },
      'frame_id': 'map',
    };
    final msg = {
      'header': header,
      'pose': {
        'pose': {
          'position': {'x': x, 'y': y, 'z': 0.0},
          'orientation': {
            'x': 0.0,
            'y': 0.0,
            'z': math.sin(yaw / 2),
            'w': math.cos(yaw / 2),
          },
        },
        'covariance': List<double>.filled(36, 0.0),
      },
    };
    publish('/initialpose', msg);
  }

  void publishGoalPose({
    required double x,
    required double y,
    required double yaw,
  }) {
    final now = DateTime.now();
    final header = {
      'stamp': {
        'sec': now.millisecondsSinceEpoch ~/ 1000,
        'nanosec': (now.millisecondsSinceEpoch % 1000) * 1000000,
      },
      'frame_id': 'map',
    };
    final msg = {
      'header': header,
      'pose': {
        'position': {'x': x, 'y': y, 'z': 0.0},
        'orientation': {
          'x': 0.0,
          'y': 0.0,
          'z': math.sin(yaw / 2),
          'w': math.cos(yaw / 2),
        },
      },
    };
    publish('/move_base_simple/goal', msg);
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _topicStreams.clear();
  }
}

class RosModel extends ChangeNotifier {
  final RosService _rosService = RosService();
  Map<String, dynamic>? robotPose;
  Map<String, dynamic>? mapData;
  List<dynamic>? scanData;
  bool isConnected = false;
  String mode = 'view'; // 'view', 'initial_pose', 'goal_pose'
  String? connectionError;

  RosModel() {
    connect();
    subscribeToTopics();
  }

  void connect() {
    _rosService.connect(
      'ws://192.168.0.6:9090',
          () {
        isConnected = true;
        connectionError = null;
        notifyListeners();
      },
          (error) {
        isConnected = false;
        connectionError = error;
        notifyListeners();
        reconnect();
      },
    );
  }

  void reconnect() {
    _rosService.reconnect(
      'ws://192.168.0.6:9090',
          () {
        isConnected = true;
        connectionError = null;
        subscribeToTopics();
        notifyListeners();
      },
          (error) {
        isConnected = false;
        connectionError = error;
        notifyListeners();
        reconnect();
      },
    );
  }

  void subscribeToTopics() {
    try {
      _rosService
          .subscribe('/amcl_pose', 'geometry_msgs/PoseWithCovarianceStamped')
          .listen(
            (msg) {
          robotPose = msg['msg']['pose']['pose'];
          notifyListeners();
        },
        onError: (e) {
          connectionError = e.toString();
          isConnected = false;
          notifyListeners();
          reconnect();
        },
      );

      _rosService.subscribe('/map', 'nav_msgs/OccupancyGrid').listen(
            (msg) {
          mapData = msg['msg'];
          notifyListeners();
        },
        onError: (e) {
          connectionError = e.toString();
          notifyListeners();
        },
      );

      _rosService.subscribe('/scan', 'sensor_msgs/LaserScan').listen(
            (msg) {
          scanData = msg['msg']['ranges'];
          notifyListeners();
        },
        onError: (e) {
          connectionError = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      connectionError = e.toString();
      isConnected = false;
      notifyListeners();
      reconnect();
    }
  }

  void setMode(String newMode) {
    mode = newMode;
    notifyListeners();
  }

  void setInitialPose(double x, double y, double yaw) {
    _rosService.publishInitialPose(x: x, y: y, yaw: yaw);
  }

  void setGoalPose(double x, double y, double yaw) {
    _rosService.publishGoalPose(x: x, y: y, yaw: yaw);
  }

  @override
  void dispose() {
    _rosService.dispose();
    super.dispose();
  }
}

class RobotVisualizerScreen extends StatelessWidget {
  const RobotVisualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ROS2 Robot Visualizer'),
      ),
      body: Consumer<RosModel>(
        builder: (context, model, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => model.setMode('view'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        model.mode == 'view' ? Colors.blue : null,
                      ),
                      child: const Text('View'),
                    ),
                    ElevatedButton(
                      onPressed: () => model.setMode('initial_pose'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: model.mode == 'initial_pose'
                            ? Colors.blue
                            : null,
                      ),
                      child: const Text('Set Initial Pose'),
                    ),
                    ElevatedButton(
                      onPressed: () => model.setMode('goal_pose'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        model.mode == 'goal_pose' ? Colors.blue : null,
                      ),
                      child: const Text('Set Goal Pose'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  model.isConnected
                      ? 'Connected to ROS2'
                      : 'Disconnected: ${model.connectionError ?? "Unknown error"}',
                  style: TextStyle(
                    color: model.isConnected ? Colors.green : Colors.red,
                  ),
                ),
              ),
              if (model.robotPose != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Robot Pose: x=${model.robotPose!['position']['x'].toStringAsFixed(4)}, '
                        'y=${model.robotPose!['position']['y'].toStringAsFixed(4)}, '
                        'yaw=${(2 * math.atan2(model.robotPose!['orientation']['z'], model.robotPose!['orientation']['w'])).toStringAsFixed(4)} rad',
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: SingleChildScrollView(
                    child: InteractiveViewer(
                      constrained: true,
                      boundaryMargin: const EdgeInsets.all(1000),
                      minScale: 0.1,
                      maxScale: 4.0,
                      child: MapWidget(
                        pose: model.robotPose,
                        mapData: model.mapData,
                        scanData: model.scanData,
                        isConnected: model.isConnected,
                        mode: model.mode,
                        onPoseSet: (x, y, yaw) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(model.mode == 'initial_pose'
                                  ? 'Confirm Initial Pose'
                                  : 'Confirm Goal Pose'),
                              content: Text(
                                'Set pose: x=${x.toStringAsFixed(4)}, y=${y.toStringAsFixed(4)}, yaw=${yaw.toStringAsFixed(4)} rad?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (model.mode == 'initial_pose') {
                                      model.setInitialPose(x, y, yaw);
                                    } else if (model.mode == 'goal_pose') {
                                      model.setGoalPose(x, y, yaw);
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Confirm'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MapWidget extends StatefulWidget {
  final Map<String, dynamic>? pose;
  final Map<String, dynamic>? mapData;
  final List<dynamic>? scanData;
  final bool isConnected;
  final String mode;
  final Function(double x, double y, double yaw) onPoseSet;

  const MapWidget({
    super.key,
    this.pose,
    this.mapData,
    this.scanData,
    required this.isConnected,
    required this.mode,
    required this.onPoseSet,
  });

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  Offset? tapPosition;
  Offset? dragPosition;

  @override
  Widget build(BuildContext context) {
    final mapPainter = MapPainter(
      pose: widget.pose,
      mapData: widget.mapData,
      scanData: widget.scanData,
      tapPosition: tapPosition,
      dragPosition: dragPosition,
      mode: widget.mode,
    );

    return GestureDetector(
      onPanStart: (details) {
        if (widget.mode != 'view') {
          setState(() {
            tapPosition = details.localPosition;
            dragPosition = details.localPosition;
          });
        }
      },
      onPanUpdate: (details) {
        if (widget.mode != 'view') {
          setState(() {
            dragPosition = details.localPosition;
          });
        }
      },
      onPanEnd: (details) {
        if (widget.mode != 'view' &&
            tapPosition != null &&
            dragPosition != null &&
            widget.mapData != null) {
          final mapInfo = widget.mapData!['info'];
          final originX = mapInfo['origin']['position']['x'] as double;
          final originY = mapInfo['origin']['position']['y'] as double;
          final scale = mapPainter.pixelsPerMeter;

          // Convert canvas coordinates to map coordinates (inverted y-axis)
          final mapX = (tapPosition!.dx - mapPainter.canvasOrigin.dx) / scale + mapPainter.minX;
          final mapY = -((tapPosition!.dy - mapPainter.canvasOrigin.dy) / scale) + mapPainter.maxY;
          final dx = (dragPosition!.dx - tapPosition!.dx) / scale;
          final dy = -((dragPosition!.dy - tapPosition!.dy) / scale); // Invert y direction for yaw
          final yaw = math.atan2(dy, dx);

          widget.onPoseSet(mapX, mapY, yaw);
          setState(() {
            tapPosition = null;
            dragPosition = null;
          });
        }
      },
      child: CustomPaint(
        painter: mapPainter,
        size: mapPainter.preferredSize,
      ),
    );
  }
}

class MapPainter extends CustomPainter {
  final Map<String, dynamic>? pose;
  final Map<String, dynamic>? mapData;
  final List<dynamic>? scanData;
  final Offset? tapPosition;
  final Offset? dragPosition;
  final String mode;
  final double pixelsPerMeter = 50.0;
  late Offset canvasOrigin;
  late double minX, maxX, minY, maxY;

  MapPainter({
    this.pose,
    this.mapData,
    this.scanData,
    this.tapPosition,
    this.dragPosition,
    required this.mode,
  });

  double sanitizeValue(double value) {
    if (value.isNaN || value.isInfinite) {
      return 0.0;
    }
    return value;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Determine the bounds of the content (map and robot)
    minX = 0.0;
    maxX = 0.0;
    minY = 0.0;
    maxY = 0.0;
    double originX = 0.0, originY = 0.0;

    if (mapData != null) {
      final mapInfo = mapData!['info'];
      final width = mapInfo['width'] as int;
      final height = mapInfo['height'] as int;
      final resolution = mapInfo['resolution'] as double;
      originX = mapInfo['origin']['position']['x'] as double;
      originY = mapInfo['origin']['position']['y'] as double;

      final mapWidthMeters = width * resolution;
      final mapHeightMeters = height * resolution;
      minX = originX;
      maxX = originX + mapWidthMeters;
      minY = originY;
      maxY = originY + mapHeightMeters;
    }

    if (pose != null) {
      final robotX = pose!['position']['x'] as double;
      final robotY = pose!['position']['y'] as double;
      minX = math.min(minX, robotX - 0.5);
      maxX = math.max(maxX, robotX + 0.5);
      minY = math.min(minY, robotY - 0.5);
      maxY = math.max(maxY, robotY + 0.5);
    }

    minX -= 1.0;
    maxX += 1.0;
    minY -= 1.0;
    maxY += 1.0;

    // Calculate the canvas origin to center the content
    final contentWidth = (maxX - minX) * pixelsPerMeter;
    final contentHeight = (maxY - minY) * pixelsPerMeter;
    canvasOrigin = Offset(
      (size.width - contentWidth) / 2,
      (size.height - contentHeight) / 2,
    );

    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Draw orthonormal grid in meters (inverted y-axis)
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    final textPaint = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    final gridMinX = (minX).floorToDouble();
    final gridMaxX = (maxX).ceilToDouble();
    final gridMinY = (minY).floorToDouble();
    final gridMaxY = (maxY).ceilToDouble();

    for (double x = gridMinX; x <= gridMaxX; x += 1.0) {
      final canvasX = canvasOrigin.dx + (x - minX) * pixelsPerMeter;
      canvas.drawLine(
        Offset(canvasX, 0),
        Offset(canvasX, size.height),
        gridPaint,
      );
      textPaint.text = TextSpan(
        text: x.toStringAsFixed(0),
        style: const TextStyle(color: Colors.black, fontSize: 12),
      );
      textPaint.layout();
      textPaint.paint(canvas, Offset(canvasX - 10, 10));
    }

    for (double y = gridMinY; y <= gridMaxY; y += 1.0) {
      final canvasY = canvasOrigin.dy + (maxY - y) * pixelsPerMeter;
      canvas.drawLine(
        Offset(0, canvasY),
        Offset(size.width, canvasY),
        gridPaint,
      );
      textPaint.text = TextSpan(
        text: y.toStringAsFixed(0),
        style: const TextStyle(color: Colors.black, fontSize: 12),
      );
      textPaint.layout();
      textPaint.paint(canvas, Offset(10, canvasY - 6));
    }

    // Draw map (inverted y-axis)
    if (mapData != null) {
      final mapInfo = mapData!['info'];
      final width = mapInfo['width'] as int;
      final height = mapInfo['height'] as int;
      final resolution = mapInfo['resolution'] as double;
      final data = List<int>.from(mapData!['data']);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = y * width + x;
          final value = data[index];
          Color color;
          if (value == -1) {
            color = Colors.grey; // Unknown
          } else if (value == 0) {
            color = Colors.white; // Free
          } else {
            color = Colors.black; // Occupied
          }

          final mapX = originX + x * resolution;
          final mapY = originY + y * resolution;
          final canvasX = canvasOrigin.dx + (mapX - minX) * pixelsPerMeter;
          final canvasY = canvasOrigin.dy + (maxY - mapY) * pixelsPerMeter;

          canvas.drawRect(
            Rect.fromLTWH(
              canvasX,
              canvasY,
              resolution * pixelsPerMeter,
              resolution * pixelsPerMeter,
            ),
            Paint()..color = color,
          );
        }
      }
    }

    // Draw robot pose (inverted y-axis, corrected orientation)
    if (pose != null) {
      final x = sanitizeValue(pose!['position']['x'] as double);
      final y = sanitizeValue(pose!['position']['y'] as double);
      final qx = sanitizeValue(pose!['orientation']['x'] as double);
      final qy = sanitizeValue(pose!['orientation']['y'] as double);
      final qz = sanitizeValue(pose!['orientation']['z'] as double);
      final qw = sanitizeValue(pose!['orientation']['w'] as double);

      // Calculate yaw from quaternion
      final yaw = -math.atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz));

      final robotPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2;
      canvas.save();
      final canvasX = canvasOrigin.dx + (x - minX) * pixelsPerMeter;
      final canvasY = canvasOrigin.dy + (maxY - y) * pixelsPerMeter;
      canvas.translate(canvasX, canvasY);
      canvas.rotate(yaw);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(-10, 5)  // Base of triangle
        ..lineTo(-10, -5)
        ..close();
      canvas.drawPath(path, robotPaint);
      //canvas.drawLine(Offset(0, 0), Offset(20, 0), robotPaint);  // Forward direction
      canvas.restore();
    }

    // Draw pose setting arrow (inverted y-axis affects user input)
    if (tapPosition != null && dragPosition != null && mode != 'view') {
      final arrowPaint = Paint()
        ..color = mode == 'initial_pose' ? Colors.green : Colors.red
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final path = Path();
      final start = tapPosition!;
      final end = dragPosition!;
      final distance = math.sqrt(
          math.pow(end.dx - start.dx, 2) + math.pow(end.dy - start.dy, 2));
      const dashLength = 5;
      const gapLength = 5;
      double t = 0;
      while (t < distance) {
        final tStart = t / distance;
        final tEnd = math.min((t + dashLength) / distance, 1.0);
        final startPoint = Offset(
          start.dx + tStart * (end.dx - start.dx),
          start.dy + tStart * (end.dy - start.dy),
        );
        final endPoint = Offset(
          start.dx + tEnd * (end.dx - start.dx),
          start.dy + tEnd * (end.dy - start.dy),
        );
        path.moveTo(startPoint.dx, startPoint.dy);
        path.lineTo(endPoint.dx, endPoint.dy);
        t += dashLength + gapLength;
      }
      canvas.drawPath(path, arrowPaint);

      canvas.save();
      canvas.translate(end.dx, end.dy);
      canvas.rotate(math.atan2(end.dy - start.dy, end.dx - start.dx));
      final arrowHead = Path()
        ..moveTo(0, 0)
        ..lineTo(-5, 3)
        ..lineTo(-5, -3)
        ..close();
      canvas.drawPath(arrowHead, arrowPaint..style = PaintingStyle.fill);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) => true;

  Size get preferredSize {
    double minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    if (mapData != null) {
      final mapInfo = mapData!['info'];
      final width = mapInfo['width'] as int;
      final height = mapInfo['height'] as int;
      final resolution = mapInfo['resolution'] as double;
      final originX = mapInfo['origin']['position']['x'] as double;
      final originY = mapInfo['origin']['position']['y'] as double;

      final mapWidthMeters = width * resolution;
      final mapHeightMeters = height * resolution;
      minX = originX;
      maxX = originX + mapWidthMeters;
      minY = originY;
      maxY = originY + mapHeightMeters;
    }

    if (pose != null) {
      final robotX = pose!['position']['x'] as double;
      final robotY = pose!['position']['y'] as double;
      minX = math.min(minX, robotX - 0.5);
      maxX = math.max(maxX, robotX + 0.5);
      minY = math.min(minY, robotY - 0.5);
      maxY = math.max(maxY, robotY + 0.5);
    }

    minX -= 1.0;
    maxX += 1.0;
    minY -= 1.0;
    maxY += 1.0;

    final width = (maxX - minX) * pixelsPerMeter;
    final height = (maxY - minY) * pixelsPerMeter;
    return Size(width, height);
  }
}