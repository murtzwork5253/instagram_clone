import 'package:Instagram/screens/reels_screen/reel_player.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late PageController _pageController; // Declare PageController

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReelProvider>(
      create: (_) => ReelProvider()..fetchReels(),
      child: Scaffold(
        body: Consumer<ReelProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.reels.isEmpty) {
              return const Center(
                child: Text(
                  'No reels available.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            return PageView.builder(
              controller: _pageController, // Assign the controller here
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: provider.reels.length,
              itemBuilder: (context, index) {
                // Pass the current index to the ReelPlayer if needed for other logic
                return ReelPlayer(
                  reel: provider.reels[index],
                  // Remove onSwipeUp/onSwipeDown here, as PageView handles it
                );
              },
            );
          },
        ),
      ),
    );
  }
}