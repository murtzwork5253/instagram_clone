// screens/calling/widgets/floating_call_indicator.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../call_manager.dart';
import '../models/call_models.dart';

class FloatingCallIndicator extends StatefulWidget {
  final Widget child;

  const FloatingCallIndicator({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<FloatingCallIndicator> createState() => _FloatingCallIndicatorState();
}

class _FloatingCallIndicatorState extends State<FloatingCallIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  bool _showIndicator = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Check call status periodically
    _checkCallStatus();
    Timer.periodic(const Duration(seconds: 1), (_) {
      _checkCallStatus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  void _checkCallStatus() {
    final callManager = CallManager();
    final hasActiveCall = callManager.callService.currentCall?.isActive ?? false;
    final isAnswered = callManager.getActiveCallStatus() == CallStatus.answered;

    if (mounted) {
      setState(() {
        _showIndicator = hasActiveCall && !callManager.isCallUIActive;
      });
    }

    if (hasActiveCall && isAnswered && _durationTimer == null) {
      _startDurationTimer();
    } else if (!hasActiveCall) {
      _durationTimer?.cancel();
      _durationTimer = null;
      _callDuration = Duration.zero;
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = _callDuration + const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showIndicator)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: GestureDetector(
              onTap: () {
                CallManager().navigateToActiveCall(context);
              },
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _callDuration.inSeconds > 0
                            ? _formatDuration(_callDuration)
                            : 'Tap to return',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}