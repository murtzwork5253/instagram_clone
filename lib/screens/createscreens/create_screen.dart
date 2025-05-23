// // import 'dart:io';
// import 'package:Instagram/screens/createscreens/add_post_screen.dart';
// import 'package:Instagram/screens/createscreens/add_reels_screen.dart';
// import 'package:flutter/material.dart';
// // import 'package:image_picker/image_picker.dart';
// // import 'package:provider/provider.dart';
// // import '../../services/insta_data_provider.dart';
// // import '../../services/supabase_storage_service.dart';
//
// class CreateScreen extends StatefulWidget {
//   const CreateScreen({Key? key}) : super(key: key);
//
//   @override
//   State<CreateScreen> createState() => _CreateScreenState();
// }
//
//
// class _CreateScreenState extends State<CreateScreen> {
//   late PageController pageController;
//   int _currentIndex = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     pageController = PageController();
//   }
//
//   @override
//   void dispose() {
//     pageController.dispose();
//     super.dispose();
//   }
//
//   void onPageChanged(int page) {
//     setState(() {
//       _currentIndex = page;
//     });
//   }
//
//   void navigationTapped(int page) {
//     pageController.jumpToPage(page);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return _buildCreateScreen();
//   }
//
//   Widget _buildCreateScreen() {
//     return SafeArea(
//       child: Scaffold(
//         backgroundColor: Colors.black,
//         body: Stack(
//           children: [
//             PageView(
//               controller: pageController,
//               onPageChanged: onPageChanged,
//               children: [
//                 CreatePostScreen(),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
