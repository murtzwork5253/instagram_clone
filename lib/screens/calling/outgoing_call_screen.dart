// screens/calling/outgoing_call_screen.dart

import 'package:Instagram/screens/calling/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'in_call_screen.dart';
import 'models/call_models.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String? receiverProfileUrl;
  final CallService callService;

  const OutgoingCallScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfileUrl,
    required this.callService,
  }) : super(key: key);

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  CallStatus _callStatus = CallStatus.initiated;
  Timer? _timeoutTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Setup call status listener
    widget.callService.onCallStatusChanged = (status) {
      if (mounted) {
        setState(() {
          _callStatus = status;
        });

        if (status == CallStatus.answered) {
          _timeoutTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => InCallScreen(
                callService: widget.callService,
                otherUserName: widget.receiverName,
                otherUserProfileUrl: widget.receiverProfileUrl,
              ),
            ),
          );
        } else if (status == CallStatus.declined || status == CallStatus.busy) {
          _handleCallRejected(status);
        }
      }
    };

    // Start call timeout (60 seconds)
    _timeoutTimer = Timer(const Duration(seconds: 60), () {
      _handleCallTimeout();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _handleCallRejected(CallStatus status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          status == CallStatus.busy ? 'User Busy' : 'Call Declined',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          status == CallStatus.busy
              ? '${widget.receiverName} is on another call'
              : '${widget.receiverName} declined your call',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleCallTimeout() {
    widget.callService.endCall();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No answer')),
    );
  }

  String get _publicImageUrl {
    if (widget.receiverProfileUrl == null) return '';
    if (widget.receiverProfileUrl!.startsWith('http://') ||
        widget.receiverProfileUrl!.startsWith('https://')) {
      return widget.receiverProfileUrl!;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/${widget.receiverProfileUrl}';
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
          backgroundColor: Colors.grey[900],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarBrightness: Brightness.dark,
            ),
            automaticallyImplyLeading: false,
          ),
          body: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Profile picture with pulse animation
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 75,
                      backgroundImage: _publicImageUrl.isNotEmpty
                          ? NetworkImage(_publicImageUrl)
                          : null,
                      backgroundColor: Colors.grey[800],
                      child: _publicImageUrl.isEmpty
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Receiver name
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                // Call status
                Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
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
                        onPressed: () {
                          setState(() {
                            _isMuted = !_isMuted;
                          });
                          widget.callService.toggleMute(_isMuted);
                        },
                        backgroundColor: _isMuted ? Colors.white : Colors.grey[800]!,
                        iconColor: _isMuted ? Colors.grey[900]! : Colors.white,
                      ),
                      // End call button
                      _buildControlButton(
                        icon: Icons.call_end,
                        onPressed: () {
                          widget.callService.endCall();
                          Navigator.of(context).pop();
                        },
                        backgroundColor: Colors.red,
                        iconColor: Colors.white,
                        size: 70,
                      ),
                      // Speaker button
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        onPressed: () {
                          setState(() {
                            _isSpeakerOn = !_isSpeakerOn;
                          });
                          widget.callService.toggleSpeaker(_isSpeakerOn);
                        },
                        backgroundColor: _isSpeakerOn ? Colors.white : Colors.grey[800]!,
                        iconColor: _isSpeakerOn ? Colors.grey[900]! : Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
    );
    }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    double size = 60,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: size * 0.4),
        color: iconColor,
        onPressed: onPressed,
      ),
    );
  }

  String _getStatusText() {
    switch (_callStatus) {
      case CallStatus.initiated:
        return 'Calling...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.answered:
        return 'Connecting...';
      case CallStatus.declined:
        return 'Call declined';
      case CallStatus.busy:
        return 'User busy';
      default:
        return 'Calling...';
    }
  }
}