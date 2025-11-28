import 'package:flutter/material.dart';
import 'dart:async';
import '../models/blood_request_model.dart';

/// Beautiful circular countdown timer widget for blood requests
class CountdownTimer extends StatefulWidget {
  final Duration duration;
  final BloodRequest request;
  final VoidCallback? onExpired;
  final double size;
  final bool showText;

  const CountdownTimer({
    Key? key,
    required this.duration,
    required this.request,
    this.onExpired,
    this.size = 80,
    this.showText = true,
  }) : super(key: key);

  @override
  _CountdownTimerState createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _remainingTime;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.duration;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addListener(() {
        setState(() {});
      });

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
          _controller.forward(from: 0.0);
        });
      } else {
        timer.cancel();
        widget.onExpired?.call();
      }
    });
  }

  double get _progress {
    if (widget.duration.inSeconds == 0) return 1.0;
    return 1.0 - (_remainingTime.inSeconds / widget.duration.inSeconds);
  }

  String get _formattedTime {
    if (_remainingTime.inSeconds <= 0) {
      return '00:00';
    }

    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get _verboseTime {
    if (_remainingTime.inSeconds <= 0) {
      return 'Expired';
    }

    final hours = _remainingTime.inHours;
    final minutes = _remainingTime.inMinutes.remainder(60);
    final seconds = _remainingTime.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Color _getTimerColor() {
    if (_remainingTime.inSeconds <= 0) {
      return Colors.red;
    } else if (_remainingTime.inMinutes <= 5) {
      // Critical: Less than 5 minutes
      return Colors.red;
    } else if (_remainingTime.inMinutes <= 15) {
      // Warning: Less than 15 minutes
      return Colors.orange;
    } else {
      // Normal: More than 15 minutes
      return Colors.green;
    }
  }

  Color _getBackgroundColor() {
    if (_remainingTime.inSeconds <= 0) {
      return Colors.red.shade100;
    } else if (_remainingTime.inMinutes <= 5) {
      return Colors.red.shade50;
    } else if (_remainingTime.inMinutes <= 15) {
      return Colors.orange.shade50;
    } else {
      return Colors.green.shade50;
    }
  }

  Color _getTextColor() {
    if (_remainingTime.inSeconds <= 0) {
      return Colors.red;
    } else if (_remainingTime.inMinutes <= 5) {
      return Colors.red;
    } else if (_remainingTime.inMinutes <= 15) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  IconData _getTimerIcon() {
    if (_remainingTime.inSeconds <= 0) {
      return Icons.timer_off;
    } else if (_remainingTime.inMinutes <= 5) {
      return Icons.warning;
    } else if (_remainingTime.inMinutes <= 15) {
      return Icons.schedule;
    } else {
      return Icons.timer;
    }
  }

  String _getTimerStatus() {
    if (_remainingTime.inSeconds <= 0) {
      return 'EXPIRED';
    } else if (_remainingTime.inMinutes <= 5) {
      return 'URGENT';
    } else if (_remainingTime.inMinutes <= 15) {
      return 'ENDING SOON';
    } else {
      return 'ACTIVE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular Progress Timer
        Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getTimerColor().withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),

            // Progress circle
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 6,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(_getTimerColor()),
              ),
            ),

            // Time text
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getTimerIcon(),
                  size: widget.size * 0.25,
                  color: _getTextColor(),
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedTime,
                  style: TextStyle(
                    fontSize: widget.size * 0.2,
                    fontWeight: FontWeight.bold,
                    color: _getTextColor(),
                  ),
                ),
              ],
            ),
          ],
        ),

        if (widget.showText) ...[
          const SizedBox(height: 8),

          // Status text
          Text(
            _getTimerStatus(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _getTextColor(),
              letterSpacing: 1.0,
            ),
          ),

          const SizedBox(height: 4),

          // Verbose time
          Text(
            _verboseTime,
            style: TextStyle(
              fontSize: 11,
              color: _getTextColor().withOpacity(0.8),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      setState(() {
        _remainingTime = widget.duration;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }
}

/// Compact countdown timer for use in lists or tight spaces
class CompactCountdownTimer extends StatelessWidget {
  final Duration duration;
  final BloodRequest request;

  const CompactCountdownTimer({
    Key? key,
    required this.duration,
    required this.request,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final remainingTime = duration;
    final isExpired = remainingTime.inSeconds <= 0;
    final isCritical = remainingTime.inMinutes <= 5;
    final isWarning = remainingTime.inMinutes <= 15;

    Color getColor() {
      if (isExpired) return Colors.red;
      if (isCritical) return Colors.red;
      if (isWarning) return Colors.orange;
      return Colors.green;
    }

    String getTimeText() {
      if (isExpired) return 'Expired';

      final hours = remainingTime.inHours;
      final minutes = remainingTime.inMinutes.remainder(60);
      final seconds = remainingTime.inSeconds.remainder(60);

      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else if (minutes > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${seconds}s';
      }
    }

    IconData getIcon() {
      if (isExpired) return Icons.timer_off;
      if (isCritical) return Icons.warning;
      if (isWarning) return Icons.schedule;
      return Icons.timer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getColor(), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getIcon(),
            size: 14,
            color: getColor(),
          ),
          const SizedBox(width: 4),
          Text(
            getTimeText(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: getColor(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linear progress timer for use in app bars or headers
class LinearCountdownTimer extends StatelessWidget {
  final Duration duration;
  final BloodRequest request;
  final double height;

  const LinearCountdownTimer({
    Key? key,
    required this.duration,
    required this.request,
    this.height = 4,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = duration.inSeconds > 0
        ? 1.0 - (duration.inSeconds / const Duration(hours: 1).inSeconds)
        : 1.0;

    Color getColor() {
      if (duration.inSeconds <= 0) return Colors.red;
      if (duration.inMinutes <= 5) return Colors.red;
      if (duration.inMinutes <= 15) return Colors.orange;
      return Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(getColor()),
          minHeight: height,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Time remaining:',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              duration.inSeconds > 0
                  ? '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s'
                  : 'Expired',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: getColor(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}