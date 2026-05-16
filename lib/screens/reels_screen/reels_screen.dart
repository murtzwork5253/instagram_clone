import 'package:Instagram/screens/reels_screen/reel_modal.dart';
import 'package:Instagram/screens/reels_screen/reel_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../createscreens/create_post/create_post_screen.dart';
import '/screens/reels_screen/reel_provider.dart';

class ReelsScreen extends StatefulWidget {
  final ValueNotifier<int> refreshNotifier;
  final String? initialReelId;

  const ReelsScreen({super.key, required this.refreshNotifier,this.initialReelId});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with TickerProviderStateMixin {
  AnimationController? _appBarController;
  Animation<double>? _appBarAnimation;
  late PageController _pageController;
  int _currentPage = 0;
  bool _isInitialized = false;

  late ReelProvider _reelProvider;

  @override
  void initState() {
    super.initState();

    // We get the provider once and store it. listen: false is crucial.
    _reelProvider = Provider.of<ReelProvider>(context, listen: false);
    _appBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _appBarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _appBarController!,
      curve: Curves.easeInOut,
    ));

    // Initialize reels data first, then mark as initialized
    _initializeReels();
  }

  Future<void> _initializeReels() async {
    try {

      await _reelProvider.fetchReels();

      int initialIndex = 0; // Default to the first reel
      if (widget.initialReelId != null && _reelProvider.reels.isNotEmpty) {
        final foundIndex = _reelProvider.reels
            .indexWhere((reel) => reel.id == widget.initialReelId);
        if (foundIndex != -1) {
          initialIndex = foundIndex; // Set the correct starting index
        }
      }

      // Initialize the controller WITH the correct starting page
      _pageController = PageController(initialPage: initialIndex);
      _currentPage = initialIndex; // Sync the current page variable

      // Add the listener right after initialization
      _pageController.addListener(() {
        final newPage = _pageController.page?.round();
        if (newPage != null && newPage != _currentPage) {
          _currentPage = newPage;
          Provider.of<ReelProvider>(context, listen: false)
              .preloadAdjacentReels(_currentPage);
        }
      });

      // Preload reels around the determined starting reel
      _reelProvider.preloadAdjacentReels(initialIndex);


      // The rest of your method can stay largely the same...
      if (_reelProvider.reels.isNotEmpty) {
        int attempts = 0;
        // IMPORTANT: Check the readiness of the correct initial reel, not always the first one.
        while (!_reelProvider.isControllerReady(_reelProvider.reels[initialIndex].id) && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (_reelProvider.isControllerReady(_reelProvider.reels[initialIndex].id)) {
          print('✅ Initial reel controller ($initialIndex) is ready');
        } else {
          print('⚠️ Initial reel controller not ready after timeout, but continuing...');
        }
      }


      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _appBarController?.forward();
      }
    } catch (e) {
      print('Error initializing reels: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _reelProvider.clearAllControllers(notify: false);
    _pageController.dispose();
    _appBarController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReelProvider>(
      builder: (context, reelsProvider, child) {
        if (reelsProvider.isLoadingMore || !_isInitialized) {
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
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: reels.length,
                onPageChanged: (index) {
                  // Additional callback for page changes
                  setState(() {
                    _currentPage = index;
                  });

                  // Preload adjacent reels
                  reelsProvider.preloadAdjacentReels(index);
                },
                itemBuilder: (ctx, index) {
                  final reel = reels[index];
                  return ReelPlayer(
                    reel: reel,
                    isFirstReel: index == 0, // Pass index for debugging
                  );
                },
              ),
              // Floating AppBar positioned at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _appBarAnimation ?? const AlwaysStoppedAnimation(1.0),
                  builder: (context, child) {
                    return Container(
                      height: MediaQuery.of(context).padding.top + kToolbarHeight,
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
                                      const CreatePostScreen(initialTabIndex: 2),
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