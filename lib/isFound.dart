import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ros_service.dart'; // Import the updated ros2_service.dart

class SearchStatusWidget extends StatefulWidget {
  const SearchStatusWidget({super.key});

  @override
  _SearchStatusWidgetState createState() => _SearchStatusWidgetState();
}

class _SearchStatusWidgetState extends State<SearchStatusWidget> {
  bool? _searchStatus; // null: no status, true: found, false: not found

  @override
  void initState() {
    super.initState();
    // Delay subscription to ensure context is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToSearchStatus();
    });
  }

  void _subscribeToSearchStatus() {
    // Access RosModel using Provider and use the public getter
    final rosModel = Provider.of<RosModel>(context, listen: false);
    try {
      rosModel.rosService.subscribe('/search_state', 'std_msgs/Bool').listen(
            (msg) {
          final bool status = msg['msg']['data'] as bool;
          print(status);
          // Ensure the widget is still mounted before updating state
          if (mounted) {
            setState(() {
              _searchStatus = status;
            });
            _showResultDialog(status);
          }
        },
        onError: (e) {
          debugPrint('Error subscribing to /search_status: $e');
        },
      );
    } catch (e) {
      debugPrint('Exception in subscribing to /search_status: $e');
    }
  }

  void _showResultDialog(bool status) {
    // Ensure the context is still valid before showing the dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(status ? 'Object Found' : 'Object Not Found'),
        content: Text(
          status
              ? 'The target object has been successfully found!'
              : 'The target object could not be found after searching all waypoints.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Ensure the widget is still mounted before updating state
              if (mounted) {
                setState(() {
                  _searchStatus = null; // Reset status for the next search
                });
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // This widget doesn't render anything visible
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}