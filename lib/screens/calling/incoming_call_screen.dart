// screens/calling/incoming_call_screen.dart

import 'package:Instagram/screens/calling/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

// import '../models/call_models.dart';
// import '../services/call_service.dart';
import 'in_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String? callerProfileUrl;
  final CallService callService;

  const IncomingCallScreen({
    Key? key,
    required this.callerId,
    required this.callerName,
    this.callerProfileUrl,
    required this.callService,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _ringAnimation;
  late Animation<Offset> _acceptSlideAnimation;
  late Animation<Offset> _declineSlideAnimation;

  Timer? _autoDeclineTimer;

  @override
  void initState() {
    super.initState();

    // Ring animation
    _ringAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _ringAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _ringAnimationController,
      curve: Curves.easeInOut,
    ));

    // Slide animations for buttons
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _acceptSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutBack,
    ));

    _declineSlideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutBack,
    ));

    // Auto-decline after 30 seconds
    _autoDeclineTimer = Timer(const Duration(seconds: 30), () {
      _handleDecline();
    });

    // Add this callback to handle the call ending remotely
    widget.callService.onCallEnded = () {
      if (mounted) {
        // If the call ends for any reason, pop the screen
        Navigator.of(context).pop();
      }
    };

    // Vibrate for incoming call
    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _ringAnimationController.dispose();
    _slideAnimationController.dispose();
    _autoDeclineTimer?.cancel();
    super.dispose();
  }

  void _handleAccept() async {
    _autoDeclineTimer?.cancel();

    await widget.callService.acceptCall();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InCallScreen(
            callService: widget.callService,
            otherUserName: widget.callerName,
            otherUserProfileUrl: widget.callerProfileUrl,
          ),
        ),
      );
    }
  }

  void _handleDecline() async {
    _autoDeclineTimer?.cancel();
    await widget.callService.rejectCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String get _publicImageUrl {
    if (widget.callerProfileUrl == null) return '';
    if (widget.callerProfileUrl!.startsWith('http://') ||
        widget.callerProfileUrl!.startsWith('https://')) {
      return widget.callerProfileUrl!;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${widget.callerProfileUrl}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (didPop) return;
          // For incoming call, just decline if trying to go back
          _handleDecline();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[900]!,
                  Colors.black,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  // Incoming call text
                  Text(
                    'Incoming Audio Call',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Caller profile picture with ring animation
                  ScaleTransition(
                    scale: _ringAnimation,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'caller_profile_${widget.callerId}',
                        child: CircleAvatar(
                          radius: 80,
                          backgroundImage: _publicImageUrl.isNotEmpty
                              ? NetworkImage(_publicImageUrl)
                              : null,
                          backgroundColor: Colors.grey[800],
                          child: _publicImageUrl.isEmpty
                              ? const Icon(Icons.person, size: 70, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Caller name
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'is calling you...',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  // Call action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decline button
                        SlideTransition(
                          position: _declineSlideAnimation,
                          child: _buildActionButton(
                            icon: Icons.call_end,
                            label: 'Decline',
                            backgroundColor: Colors.red,
                            onTap: _handleDecline,
                          ),
                        ),
                        // Accept button
                        SlideTransition(
                          position: _acceptSlideAnimation,
                          child: _buildActionButton(
                            icon: Icons.call,
                            label: 'Accept',
                            backgroundColor: Colors.green,
                            onTap: _handleAccept,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),);
    }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 35,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}