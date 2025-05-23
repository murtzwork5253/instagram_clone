import 'package:flutter/material.dart';

class CreateReelContent extends StatelessWidget {
  const CreateReelContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Instagram Reels aspect ratio is typically 9:16
    return SafeArea(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          color: Colors.deepPurple, // Placeholder color for Reel
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.video_collection, size: 80, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Create a Reel',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  'Short, entertaining videos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                SizedBox(height: 24),
                // You can add video recording controls, gallery picker etc. here
                // Example:
                // ElevatedButton.icon(
                //   onPressed: () { /* Open camera for reel */ },
                //   icon: Icon(Icons.videocam),
                //   label: Text('Record Reel'),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}