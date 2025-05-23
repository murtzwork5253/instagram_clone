import 'package:Instagram/screens/reels_screen/reel_player.dart';
import 'package:Instagram/screens/reels_screen/reel_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReelProvider>(
      create: (_) => ReelProvider()..fetchReels(),
      child: Scaffold(
        body: Consumer<ReelProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return Center(child: CircularProgressIndicator());
            }
            return PageView.builder(
              scrollDirection: Axis.vertical,
              physics: BouncingScrollPhysics(),
              itemCount: provider.reels.length,
              itemBuilder: (context, index) {
                return ReelPlayer(
                  reel: provider.reels[index],
                  onSwipeUp: () {
                    if (index < provider.reels.length - 1) {
                      PageController().nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  onSwipeDown: () {
                    if (index > 0) {
                      PageController().previousPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                );
              },
            )
            ;
          },
        ),
      ),
    );
  }
}
