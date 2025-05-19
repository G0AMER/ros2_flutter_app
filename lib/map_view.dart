// map_view.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'ros_service.dart';

// Data class for TF transform
class TFTransform {
  final double x, y, yaw;
  TFTransform(this.x, this.y, this.yaw);

  factory TFTransform.fromJson(Map j) {
    final t = j['transform'];
    final trans = t['translation'];
    final ori = t['rotation'];
    double qx = ori['x'], qy = ori['y'], qz = ori['z'], qw = ori['w'];
    double ysqr = qy * qy;
    double t3 = 2.0 * (qw * qz + qx * qy);
    double t4 = 1.0 - 2.0 * (ysqr + qz * qz);
    double yaw = atan2(t3, t4);
    return TFTransform(trans['x'], trans['y'], yaw);
  }
}

enum MapMode { none, initPose, setGoal }

class MapView extends StatefulWidget {
  final MapMode mode;
  const MapView({super.key, required this.mode});
  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  List<List<int>> occupancyGrid = [];
  List<TFTransform> transforms = [];
  List<Offset> planPoints = [];
  Offset? goalPoint;
  Offset robotPos = Offset.zero;
  List<double> scanRanges = [];
  double scanAngleMin = 0, scanAngleInc = 0;

  Offset? initTap, dragPos;
  double mapResolution = 0.05;
  Offset mapOrigin = Offset.zero;
  int mapWidth = 0, mapHeight = 0;

  StreamSubscription? mapSub, tfSub, planSub, goalSub, scanSub, amclSub;

  @override
  void initState() {
    super.initState();
    final ros = RosService();

    mapSub = ros.subscribe('/map', 'nav_msgs/OccupancyGrid').listen((m) {
      final info = m['msg']['info'];
      final data = (m['msg']['data'] as List).cast<int>();
      setState(() {
        mapResolution = info['resolution'];
        mapOrigin = Offset(info['origin']['position']['x'], info['origin']['position']['y']);
        mapWidth = info['width'];
        mapHeight = info['height'];
        occupancyGrid = List.generate(
          mapHeight,
              (r) => data.sublist(r * mapWidth, (r + 1) * mapWidth),
        );
      });
    });

    tfSub = ros.subscribe('/tf', 'tf2_msgs/TFMessage').listen((m) {
      final tfs = (m['msg']['transforms'] as List).cast<Map>();
      setState(() {
        transforms = tfs.map((j) => TFTransform.fromJson(j)).toList();
      });
    });

    planSub = ros.subscribe('/planned_path', 'nav_msgs/Path').listen((m) {
      final poses = (m['msg']['poses'] as List).cast<Map>();
      setState(() {
        planPoints = poses.map((p) {
          final pos = p['pose']['position'];
          return Offset(pos['x'], pos['y']);
        }).toList();
      });
    });

    goalSub = ros.subscribe('/goal_pose', 'geometry_msgs/PoseStamped').listen((m) {
      final p = m['msg']['pose']['position'];
      setState(() => goalPoint = Offset(p['x'], p['y']));
    });

    scanSub = ros.subscribe('/scan', 'sensor_msgs/LaserScan').listen((m) {
      setState(() {
        scanRanges = (m['msg']['ranges'] as List).cast<double>();
        scanAngleMin = m['msg']['angle_min'];
        scanAngleInc = m['msg']['angle_increment'];
      });
    });

    amclSub = ros.subscribe('/amcl_pose', 'geometry_msgs/PoseWithCovarianceStamped').listen((m) {
      final p = m['msg']['pose']['pose']['position'];
      setState(() => robotPos = Offset(p['x'], p['y']));
    });
  }

  @override
  void dispose() {
    mapSub?.cancel();
    tfSub?.cancel();
    planSub?.cancel();
    goalSub?.cancel();
    scanSub?.cancel();
    amclSub?.cancel();
    super.dispose();
  }

  Offset worldToScreen(Offset w, Size s) {
    final double sx = (w.dx - mapOrigin.dx) / mapResolution;
    final double sy = (w.dy - mapOrigin.dy) / mapResolution;
    return Offset(sx, mapHeight - sy) * (s.width / mapWidth);
  }

  Offset screenToWorld(Offset p, Size s) {
    final scale = mapWidth / s.width;
    final double mx = p.dx * scale;
    final double my = (mapHeight - p.dy * scale);
    return Offset(mx * mapResolution + mapOrigin.dx, my * mapResolution + mapOrigin.dy);
  }

  void _onTapDown(TapDownDetails d, Size s) {
    if (widget.mode == MapMode.initPose) {
      setState(() {
        initTap = screenToWorld(d.localPosition, s);
        dragPos = null;
      });
    } else if (widget.mode == MapMode.setGoal) {
      final world = screenToWorld(d.localPosition, s);
      RosService().publish('/goal_pose', {
        'header': {
          'stamp': {
            'sec': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'nanosec': (DateTime.now().millisecondsSinceEpoch % 1000) * 1000000
          },
          'frame_id': 'map'
        },
        'pose': {
          'position': {'x': world.dx, 'y': world.dy, 'z': 0.0},
          'orientation': {
            'x': 0.0,
            'y': 0.0,
            'z': sin(0.0),
            'w': cos(0.0),
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nav goal set at (${world.dx.toStringAsFixed(2)}, ${world.dy.toStringAsFixed(2)})'),
        ),
      );
    }
  }

  void _onPanUpdate(DragUpdateDetails d, Size s) {
    if (widget.mode == MapMode.initPose) {
      setState(() {
        dragPos = screenToWorld(d.localPosition, s);
      });
    }
  }

  void _onPanEnd(Size s) {
    if (widget.mode == MapMode.initPose && initTap != null && dragPos != null) {
      final dx = dragPos!.dx - initTap!.dx;
      final dy = dragPos!.dy - initTap!.dy;
      final yaw = atan2(dy, dx);
      RosService().publishInitialPose(x: initTap!.dx, y: initTap!.dy, yaw: yaw);
    }
    setState(() {
      initTap = null;
      dragPos = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InteractiveViewer(
        constrained: true,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        panEnabled: widget.mode == MapMode.none,
        scaleEnabled: widget.mode == MapMode.none,
        minScale: 0.1,
        maxScale: 10,
        child: LayoutBuilder(builder: (ctx, cons) {
          return GestureDetector(
            onTapDown: (d) => _onTapDown(d, cons.biggest),
            onPanUpdate: (d) => _onPanUpdate(d, cons.biggest),
            onPanEnd: (_) => _onPanEnd(cons.biggest),
            child: CustomPaint(
              size: cons.biggest,
              painter: _MapPainter(
                occupancyGrid: occupancyGrid,
                transforms: transforms,
                planPoints: planPoints,
                goalPoint: goalPoint,
                robot: robotPos,
                scanRanges: scanRanges,
                scanAngleMin: scanAngleMin,
                scanAngleInc: scanAngleInc,
                initTap: initTap,
                dragPos: dragPos,
                worldToScreen: (w) => worldToScreen(w, cons.biggest),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<List<int>> occupancyGrid;
  final List<TFTransform> transforms;
  final List<Offset> planPoints;
  final Offset? goalPoint;
  final Offset robot;
  final List<double> scanRanges;
  final double scanAngleMin, scanAngleInc;
  final Offset? initTap, dragPos;
  final Offset Function(Offset) worldToScreen;

  _MapPainter({
    required this.occupancyGrid,
    required this.transforms,
    required this.planPoints,
    this.goalPoint,
    required this.robot,
    required this.scanRanges,
    required this.scanAngleMin,
    required this.scanAngleInc,
    this.initTap,
    this.dragPos,
    required this.worldToScreen,
  });

  @override
  void paint(Canvas c, Size s) {
    final paintOcc = Paint();
    final rows = occupancyGrid.length;
    final cols = rows > 0 ? occupancyGrid[0].length : 0;
    final cellW = s.width / cols;
    final cellH = s.height / rows;
    for (int r = 0; r < rows; r++) {
      for (int j = 0; j < cols; j++) {
        final v = occupancyGrid[r][j];
        paintOcc.color = v == 0 ? Colors.white : (v < 0 ? Colors.grey : Colors.black);
        c.drawRect(Rect.fromLTWH(j * cellW, r * cellH, cellW, cellH), paintOcc);
      }
    }

    final bounds = Offset.zero & s;
    final scanPaint = Paint()
      ..color = Colors.orange.withOpacity(0.6)
      ..strokeWidth = 1;
    for (int i = 0; i < scanRanges.length; i++) {
      final ang = scanAngleMin + i * scanAngleInc;
      final dist = scanRanges[i];
      final end = robot + Offset(dist * cos(ang), dist * sin(ang));
      final p1 = worldToScreen(robot);
      final p2 = worldToScreen(end);
      final clip = _clipLine(bounds, p1, p2);
      if (clip != null) c.drawLine(clip.item1, clip.item2, scanPaint);
    }

    final pathPaint = Paint()..color = Colors.blue..strokeWidth = 2;
    for (int i = 0; i + 1 < planPoints.length; i++) {
      c.drawLine(worldToScreen(planPoints[i]), worldToScreen(planPoints[i + 1]), pathPaint);
    }

    if (goalPoint != null) {
      c.drawCircle(worldToScreen(goalPoint!), 7, Paint()..color = Colors.green);
    }

    for (var tf in transforms) {
      final o = worldToScreen(Offset(tf.x, tf.y));
      final xAxis = worldToScreen(Offset(tf.x + cos(tf.yaw) * 0.4, tf.y + sin(tf.yaw) * 0.4));
      final yAxis = worldToScreen(Offset(tf.x - sin(tf.yaw) * 0.4, tf.y + cos(tf.yaw) * 0.4));
      c.drawLine(o, xAxis, Paint()..color = Colors.red..strokeWidth = 2);
      c.drawLine(o, yAxis, Paint()..color = Colors.green..strokeWidth = 2);
    }

    if (initTap != null) {
      final p = worldToScreen(initTap!);
      final initPaint = Paint()..color = Colors.green..strokeWidth = 2;
      c.drawLine(p + const Offset(-10, 0), p + const Offset(10, 0), initPaint);
      c.drawLine(p + const Offset(0, -10), p + const Offset(0, 10), initPaint);
    }
    if (initTap != null && dragPos != null) {
      final p1 = worldToScreen(initTap!);
      final p2 = worldToScreen(dragPos!);
      final initPaint = Paint()..color = Colors.green..strokeWidth = 2;
      c.drawLine(p1, p2, initPaint);
      final dir = (p2 - p1).direction;
      final head = 8.0;
      final left = p2 + Offset.fromDirection(dir + pi * 3 / 4, head);
      final right = p2 + Offset.fromDirection(dir - pi * 3 / 4, head);
      c.drawLine(p2, left, initPaint);
      c.drawLine(p2, right, initPaint);
    }

    c.drawCircle(worldToScreen(robot), 6, Paint()..color = Colors.red);
  }

  Tuple2<Offset, Offset>? _clipLine(Rect b, Offset a, Offset c2) {
    if (!_inside(b, a) && !_inside(b, c2)) return null;
    final ca = Offset(a.dx.clamp(b.left, b.right), a.dy.clamp(b.top, b.bottom));
    final cb = Offset(c2.dx.clamp(b.left, b.right), c2.dy.clamp(b.top, b.bottom));
    return Tuple2(ca, cb);
  }

  bool _inside(Rect r, Offset p) =>
      p.dx >= r.left && p.dx <= r.right && p.dy >= r.top && p.dy <= r.bottom;

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      occupancyGrid != old.occupancyGrid ||
          transforms != old.transforms ||
          planPoints != old.planPoints ||
          goalPoint != old.goalPoint ||
          robot != old.robot ||
          scanRanges != old.scanRanges ||
          initTap != old.initTap ||
          dragPos != old.dragPos;
}

class Tuple2<A, B> {
  final A item1;
  final B item2;
  Tuple2(this.item1, this.item2);
}
