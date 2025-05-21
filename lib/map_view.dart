import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ros2_flutter_app/ros_service.dart';

class RobotVisualizerScreen extends StatelessWidget {
  const RobotVisualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ROS2 Robot Visualizer')),
      body: Consumer<RosModel>(
        builder: (context, model, child) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<int>(
                  hint: const Text('Select Target Class'),
                  value: model.selectedTargetId,
                  items:
                      const [
                        'person',
                        'bicycle',
                        'car',
                        'motorcycle',
                        'airplane',
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
                        'couch',
                        'potted plant',
                        'bed',
                        'dining table',
                        'toilet',
                        'tv',
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
                      ].asMap().entries.map((entry) {
                        final index = entry.key;
                        final label = entry.value;
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(label),
                        );
                      }).toList(),
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      model.setSearchTargetId(newValue);
                    }
                  },
                ),
              ),
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
                        backgroundColor:
                            model.mode == 'initial_pose' ? Colors.blue : null,
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
                        path: model.path,
                        isConnected: model.isConnected,
                        mode: model.mode,
                        onPoseSet: (x, y, yaw) {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: Text(
                                    model.mode == 'initial_pose'
                                        ? 'Confirm Initial Pose'
                                        : 'Confirm Goal Pose',
                                  ),
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
  final Map<String, dynamic>? scanData;
  final List<Map<String, dynamic>> path;
  final bool isConnected;
  final String mode;
  final Function(double x, double y, double yaw) onPoseSet;

  const MapWidget({
    super.key,
    this.pose,
    this.mapData,
    this.scanData,
    required this.path,
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
      path: widget.path,
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
          final mapX =
              (tapPosition!.dx - mapPainter.canvasOrigin.dx) / scale +
              mapPainter.minX;
          final mapY =
              -((tapPosition!.dy - mapPainter.canvasOrigin.dy) / scale) +
              mapPainter.maxY;
          final dx = (dragPosition!.dx - tapPosition!.dx) / scale;
          final dy =
              -((dragPosition!.dy - tapPosition!.dy) /
                  scale); // Invert y direction for yaw
          final yaw = math.atan2(dy, dx);

          widget.onPoseSet(mapX, mapY, yaw);
          setState(() {
            tapPosition = null;
            dragPosition = null;
          });
        }
      },
      child: CustomPaint(painter: mapPainter, size: mapPainter.preferredSize),
    );
  }
}

class MapPainter extends CustomPainter {
  final Map<String, dynamic>? pose;
  final Map<String, dynamic>? mapData;
  final Map<String, dynamic>? scanData;
  final List<Map<String, dynamic>> path;
  final Offset? tapPosition;
  final Offset? dragPosition;
  final String mode;
  final double pixelsPerMeter = 50.0;
  late Offset canvasOrigin;
  late double minX, maxX, minY, maxY;

  // Static transform from base_link to laser_frame
  static const double laserYawOffset = math.pi + 1.3;

  MapPainter({
    this.pose,
    this.mapData,
    this.scanData,
    required this.path,
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
    // Determine the bounds of the content (map, robot, scan, and path)
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

    // Extend bounds for laser scan if available
    if (scanData != null && pose != null) {
      final robotX = pose!['position']['x'] as double;
      final robotY = pose!['position']['y'] as double;
      final ranges =
          (scanData!['ranges'] as List<dynamic>)
              .map((r) => r as double)
              .toList();
      final angleMin = scanData!['angle_min'] as double;
      final angleMax = scanData!['angle_max'] as double;
      final angleIncrement = scanData!['angle_increment'] as double;
      final rangeMin = scanData!['range_min'] as double;
      final rangeMax = scanData!['range_max'] as double;

      for (int i = 0; i < ranges.length; i++) {
        final range = sanitizeValue(ranges[i]);
        if (range >= rangeMin && range <= rangeMax) {
          final angle = angleMin + i * angleIncrement;
          final scanX = robotX + range * math.cos(angle);
          final scanY = robotY + range * math.sin(angle);
          minX = math.min(minX, scanX - 0.5);
          maxX = math.max(
            maxX,
            robotX + 0.5,
          ); // Adjusted to avoid overextension
          minY = math.min(minY, scanY - 0.5);
          maxY = math.max(
            maxY,
            robotY + 0.5,
          ); // Adjusted to avoid overextension
        }
      }
    }

    // Extend bounds for path
    for (final pose in path) {
      final x = sanitizeValue(pose['pose']['position']['x'] as double);
      final y = sanitizeValue(pose['pose']['position']['y'] as double);
      minX = math.min(minX, x - 0.5);
      maxX = math.max(maxX, x + 0.5);
      minY = math.min(minY, y - 0.5);
      maxY = math.max(maxY, y + 0.5);
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
    final gridPaint =
        Paint()
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

    // Draw path
    if (path.isNotEmpty) {
      final pathPaint =
          Paint()
            ..color = Colors.yellow
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;

      final pathPoints =
          path.map((pose) {
            final x = sanitizeValue(pose['pose']['position']['x'] as double);
            final y = sanitizeValue(pose['pose']['position']['y'] as double);
            final canvasX = canvasOrigin.dx + (x - minX) * pixelsPerMeter;
            final canvasY = canvasOrigin.dy + (maxY - y) * pixelsPerMeter;
            return Offset(canvasX, canvasY);
          }).toList();

      for (int i = 0; i < pathPoints.length - 1; i++) {
        canvas.drawLine(pathPoints[i], pathPoints[i + 1], pathPaint);
      }

      // Draw waypoints as small circles
      final waypointPaint =
          Paint()
            ..color = Colors.yellow
            ..style = PaintingStyle.fill;
      for (final point in pathPoints) {
        canvas.drawCircle(point, 3.0, waypointPaint);
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
      final robotYaw =
          -math.atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz));

      final robotPaint =
          Paint()
            ..color = Colors.blue
            ..strokeWidth = 2;
      canvas.save();
      final canvasX = canvasOrigin.dx + (x - minX) * pixelsPerMeter;
      final canvasY = canvasOrigin.dy + (maxY - y) * pixelsPerMeter;
      canvas.translate(canvasX, canvasY);
      canvas.rotate(robotYaw);
      final path =
          Path()
            ..moveTo(0, 0)
            ..lineTo(-10, 5) // Base of triangle
            ..lineTo(-10, -5)
            ..close();
      canvas.drawPath(path, robotPaint);
      canvas.restore();

      // Draw laser scan with static transform offset
      if (scanData != null) {
        final ranges =
            (scanData!['ranges'] as List<dynamic>)
                .map((r) => r as double)
                .toList();
        final angleMin = scanData!['angle_min'] as double;
        final angleMax = scanData!['angle_max'] as double;
        final angleIncrement = scanData!['angle_increment'] as double;
        final rangeMin = scanData!['range_min'] as double;
        final rangeMax = scanData!['range_max'] as double;
        final frameId = scanData!['header']['frame_id'] as String?;

        final scanPaint =
            Paint()
              ..color = Colors.red
              ..strokeWidth = 0.1;

        for (int i = 0; i < ranges.length; i++) {
          final range = sanitizeValue(ranges[i]);
          if (range >= rangeMin && range <= rangeMax) {
            final relativeAngle = angleMin + i * angleIncrement;
            final globalAngle =
                robotYaw +
                relativeAngle +
                laserYawOffset; // Apply static yaw offset
            final scanX = x + range * math.cos(globalAngle);
            final scanY = y + range * math.sin(globalAngle);
            final scanCanvasX =
                canvasOrigin.dx + (scanX - minX) * pixelsPerMeter;
            final scanCanvasY =
                canvasOrigin.dy + (maxY - scanY) * pixelsPerMeter;

            /*canvas.drawLine(
              Offset(canvasX, canvasY),
              Offset(scanCanvasX, scanCanvasY),
              scanPaint,
            );*/
          }
        }

        // Debug: Log frame_id if available
        if (frameId != null) {
          print('LaserScan frame_id: $frameId');
        }
      }
    }

    // Draw pose setting arrow (inverted y-axis affects user input)
    if (tapPosition != null && dragPosition != null && mode != 'view') {
      final arrowPaint =
          Paint()
            ..color = mode == 'initial_pose' ? Colors.green : Colors.red
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;

      final path = Path();
      final start = tapPosition!;
      final end = dragPosition!;
      final distance = math.sqrt(
        math.pow(end.dx - start.dx, 2) + math.pow(end.dy - start.dy, 2),
      );
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
      final arrowHead =
          Path()
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

    // Extend bounds for laser scan if available
    if (scanData != null && pose != null) {
      final robotX = pose!['position']['x'] as double;
      final robotY = pose!['position']['y'] as double;
      final ranges =
          (scanData!['ranges'] as List<dynamic>)
              .map((r) => r as double)
              .toList();
      final angleMin = scanData!['angle_min'] as double;
      final angleMax = scanData!['angle_max'] as double;
      final angleIncrement = scanData!['angle_increment'] as double;
      final rangeMin = scanData!['range_min'] as double;
      final rangeMax = scanData!['range_max'] as double;

      for (int i = 0; i < ranges.length; i++) {
        final range = sanitizeValue(ranges[i]);
        if (range >= rangeMin && range <= rangeMax) {
          final angle = angleMin + i * angleIncrement;
          final scanX = robotX + range * math.cos(angle);
          final scanY = robotY + range * math.sin(angle);
          minX = math.min(minX, scanX - 0.5);
          maxX = math.max(maxX, scanX + 0.5);
          minY = math.min(minY, scanY - 0.5);
          maxY = math.max(maxY, scanY + 0.5);
        }
      }
    }

    // Extend bounds for path
    for (final pose in path) {
      final x = pose['pose']['position']['x'] as double;
      final y = pose['pose']['position']['y'] as double;
      minX = math.min(minX, x - 0.5);
      maxX = math.max(maxX, x + 0.5);
      minY = math.min(minY, y - 0.5);
      maxY = math.max(maxY, y + 0.5);
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
