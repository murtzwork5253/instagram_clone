import 'package:flutter/material.dart';
// import 'package:camera/camera.dart'; // Uncomment and add to pubspec.yaml for actual camera

class CreateStoryContent extends StatefulWidget {
  const CreateStoryContent({Key? key}) : super(key: key);

  @override
  State<CreateStoryContent> createState() => _CreateStoryContentState();
}

class _CreateStoryContentState extends State<CreateStoryContent> {
  // late CameraController _controller;
  // bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Placeholder for camera initialization
    // final cameras = await availableCameras();
    // final firstCamera = cameras.first;
    // _controller = CameraController(firstCamera, ResolutionPreset.high);
    // await _controller.initialize();
    // if (mounted) {
    //   setState(() {
    //     _isCameraInitialized = true;
    //   });
    // }
  }

  @override
  void dispose() {
    // _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Background for the camera view
      child: Stack(
        children: [
          // Simulated Camera Preview (replace with CameraPreview(_controller) when actual camera is used)
          Positioned.fill(
            child: Container(color: Colors.grey[800]), // Dummy camera preview
            // Or use an actual image:
            // child: Image.asset(
            //   'assets/images/dummy_camera_preview.jpg',
            //   fit: BoxFit.cover,
            // ),
          ),
          // Gradient Overlay at the top and bottom for text visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120, // Adjust height as needed
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120, // Adjust height as needed
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Top Row: Close, Flash, Settings/More
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () {
                    // This CreateStoryContent is inside a PageView.
                    // To close the entire CreatePostScreen, you'd typically pop it
                    // from where it was pushed. For this context, assuming we
                    // just want to reset to the POST tab if this is dismissed.
                    // Navigator.of(context).pop(); // This would pop the CreatePostScreen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Close Story creation (logic not implemented)')),
                    );
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.flash_off, color: Colors.white, size: 28), // Example: Flash off
                      onPressed: () {
                        // Toggle flash
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white, size: 28), // Or more_vert
                      onPressed: () {
                        // Open story settings
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Side controls (e.g., filters, layouts, boomerangs)
          Positioned(
            right: 10,
            top: MediaQuery.of(context).padding.top + 70, // Below top row
            child: Column(
              children: [
                _buildStoryControlIcon(Icons.text_fields, () { /* Text mode */ }),
                _buildStoryControlIcon(Icons.grid_on, () { /* Layout mode */ }),
                _buildStoryControlIcon(Icons.gif_box_outlined, () { /* Boomerang/Effects */ }),
                // Add more controls as needed
              ],
            ),
          ),

          // Bottom Controls: Gallery, Capture, Camera Switch
          Positioned(
            bottom: 60, // Above the floating tab bar if it's there
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Story Type Selector (e.g., Normal, Boomerang, Layout, Text)
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    // physics: const NeverScrollableScrollPhysics(), // Only scrollable by user selection
                    padding: const EdgeInsets.symmetric(horizontal: 50),
                    children: [
                      _buildStoryTypeChip('LIVE'),
                      _buildStoryTypeChip('REEL'),
                      _buildStoryTypeChip('STORY', isSelected: true), // Default selected
                      _buildStoryTypeChip('POST'),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Gallery Button
                    GestureDetector(
                      onTap: () {
                        // Open gallery
                      },
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                      ),
                    ),
                    // Capture Button
                    GestureDetector(
                      onTap: () {
                        // Capture photo/video
                      },
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Camera Switch Button
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 35),
                      onPressed: () {
                        // Switch camera
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryControlIcon(IconData icon, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildStoryTypeChip(String text, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Chip(
        label: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isSelected ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }
}