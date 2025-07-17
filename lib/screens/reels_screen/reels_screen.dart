import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:Instagram/screens/reels_screen/reel_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../createscreens/create_post/create_post_screen.dart';
import '/screens/reels_screen/reel_provider.dart';

class ReelsScreen extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;

  const ReelsScreen({super.key, required this.refreshNotifier});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with TickerProviderStateMixin {
// Add these variables to your ReelScreen class
  AnimationController? _appBarController;
  Animation<double>? _appBarAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReelProvider>(context, listen: false).fetchReels();
    });
    _appBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this, // Make sure your class extends TickerProviderStateMixin
    );
    _appBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _appBarController!,
      curve: Curves.easeInOut,
    ));

    // Start the animation or control it based on your logic
    _appBarController?.forward();
  }

  // Don't forget to dispose
  @override
  void dispose() {
    _appBarController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, reelsProvider, child) {
        if (reelsProvider.isLoading) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        final reels = reelsProvider.reels;

        if (reels.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No reels available',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Main PageView content
              PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                itemBuilder: (ctx, index) {
                  final reel = reels[index];
                  return ReelPlayer(
                    reel: reel,
                    isFirstReel: index == 0, // Pass if it's the first reel
                  );
                },
              ),

              // Floating AppBar positioned at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation:
                      _appBarAnimation ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    return Container(
                      height:
                          MediaQuery.of(context).padding.top + kToolbarHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(
                                0.8 * (_appBarAnimation?.value ?? 1.0)),
                            Colors.black.withOpacity(
                                0.4 * (_appBarAnimation?.value ?? 1.0)),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Opacity(
                                opacity: _appBarAnimation?.value ?? 1.0,
                                child: const Text(
                                  'Reels',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.camera_alt_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreatePostScreen(initialTabIndex: 2,),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
