// screens/calling/in_call_screen.dart

import 'package:Instagram/screens/calling/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
// import 'package:wakelock/wakelock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// import '../models/call_models.dart';
// import '../services/call_service.dart';

class InCallScreen extends StatefulWidget {
  final CallService callService;
  final String otherUserName;
  final String? otherUserProfileUrl;

  const InCallScreen({
    Key? key,
    required this.callService,
    required this.otherUserName,
    this.otherUserProfileUrl,
  }) : super(key: key);

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Keep screen on during call
    WakelockPlus.enable();

    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    // Start duration timer
    _startDurationTimer();

    // Listen for call end
    widget.callService.onCallEnded = () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    };
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _animationController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startDurationTimer() {
    final call = widget.callService.currentCall;
    if (call != null && call.answeredAt != null) {
      _callDuration = DateTime.now().difference(call.answeredAt!);
    }

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
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String get _publicImageUrl {
    if (widget.otherUserProfileUrl == null) return '';
    if (widget.otherUserProfileUrl!.startsWith('http://') ||
        widget.otherUserProfileUrl!.startsWith('https://')) {
      return widget.otherUserProfileUrl!;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${widget.otherUserProfileUrl}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (didPop) return;

          // Show confirmation dialog
          final shouldLeave = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'Leave call screen?',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'The call will continue in the background. You can return by tapping the call indicator.',
                style: TextStyle(color: Colors.grey[300]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          );

          if (shouldLeave ?? false) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
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
                    const SizedBox(height: 60),
                    // Profile picture
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 70,
                        backgroundImage: _publicImageUrl.isNotEmpty
                            ? NetworkImage(_publicImageUrl)
                            : null,
                        backgroundColor: Colors.grey[800],
                        child: _publicImageUrl.isEmpty
                            ? const Icon(Icons.person, size: 60, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // User name
                    Text(
                      widget.otherUserName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Call duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_callDuration),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Audio visualizer placeholder
                    Container(
                      height: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(15, (index) {
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 300 + (index * 50)),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 4,
                            height: 20 + (index % 3) * 20.0,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Spacer(),
                    // Call controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Mute button
                          _buildControlButton(
                            icon: _isMuted ? Icons.mic_off : Icons.mic,
                            label: _isMuted ? 'Unmute' : 'Mute',
                            onPressed: () {
                              setState(() {
                                _isMuted = !_isMuted;
                              });
                              widget.callService.toggleMute(_isMuted);
                              HapticFeedback.lightImpact();
                            },
                            isActive: _isMuted,
                          ),
                          // End call button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              widget.callService.endCall();
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          // Speaker button
                          _buildControlButton(
                            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                            label: 'Speaker',
                            onPressed: () {
                              setState(() {
                                _isSpeakerOn = !_isSpeakerOn;
                              });
                              widget.callService.toggleSpeaker(_isSpeakerOn);
                              HapticFeedback.lightImpact();
                            },
                            isActive: _isSpeakerOn,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),);
    }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.grey[800],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isActive ? Colors.white : Colors.grey[800]!)
                      .withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.grey[900] : Colors.white,
              size: 26,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}