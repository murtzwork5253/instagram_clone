import 'dart:io';
import 'package:Instagram/screens/createscreens/create_reels/create_reel_screen.dart';
import 'package:Instagram/screens/createscreens/create_story/create_story_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For MissingPluginException
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:icons_plus/icons_plus.dart' as OIcons;

import '../../../l10n/app_localizations.dart';
import '../../user_tagging/user_model.dart';
import '../../user_tagging/user_tagging_screen.dart';
import '../../user_tagging/user_tagging_service.dart';
import '../camera_service.dart';
import 'location_selection_screen.dart';

// Define an enum to manage the different stages of post creation
enum PostCreationStage {
  gallerySelection,
  postDetails,
}

class CreatePostScreen extends StatefulWidget {

  final int initialTabIndex;
  const CreatePostScreen({Key? key,this.initialTabIndex=0}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => CreatePostScreenState();
}

class CreatePostScreenState extends State<CreatePostScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionController = TextEditingController();

  List<AssetEntity> _galleryAssets = [];
  XFile? _selectedMedia; // This holds the single selected media for upload
  List<XFile> _selectedMultipleMedia = []; // For multiple selections if implemented
  String? _location;
  bool _disableComments = false;
  bool _shareToOtherPlatforms = false;
  bool _isUploading = false;
  bool _isLoadingGallery = true;
  bool _hasRequestedPermission = false;
  late CameraService _cameraService;
  String _selectedAlbum = 'Recent';
  List<AssetPathEntity> _availableAlbums = [];
  double _mediaAspectRatio = 1.0;
  bool _useOriginalAspectRatio = false;
  Matrix4 _transformation = Matrix4.identity();
  final TransformationController _transformationController = TransformationController();
  List<TaggedUser> _taggedUsers = [];
  final UserTaggingService _taggingService = UserTaggingService();

  // Add these new fields:
  bool _postUseOriginalRatio = false; // Store the ratio choice for this post
  Matrix4 _postTransformation = Matrix4.identity(); // Store the zoom/pan state

  // Replaced TabController with PageController and ScrollController for custom tabs
  PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _tabs = ['POST', 'STORY', 'REEL', 'LIVE']; // Added LIVE tab
  int _selectedIndex = 0; // Tracks the selected tab for the custom tab bar

  PostCreationStage _currentStage = PostCreationStage.gallerySelection; // Start at gallery selection

  // NEW CODE - Replace the above section with this:
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    _pageController = PageController(initialPage: _selectedIndex);

    _cameraService = CameraService(); // Now a normal instance
    _handleTabChange(_selectedIndex);

    _pageController.addListener(() {
      final newIndex = _pageController.page?.round();
      if (newIndex != null && newIndex != _selectedIndex) {
        setState(() {
          _selectedIndex = newIndex;
          _centerTab(_selectedIndex);
          _handleTabChange(_selectedIndex);
        });
      }
    });

    requestPermissionAndFetchMedia();
  }

  Future<void> _handleTabChange(int index) async {
    switch (index) {
      case 1: // STORY
        await _cameraService.restartCamera(enableAudio: false);
        break;
      case 2: // REEL
        await _cameraService.restartCamera(enableAudio: true);
        break;
      default: // POST or LIVE
        await _cameraService.stopCamera();
        break;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _captionController.dispose();
    _cameraService.dispose(); // Now safe to dispose
    _transformationController.dispose();
    super.dispose();
  }

  // In your create_post_screen.dart, modify _onTabTap method
  void _onTabTap(int index) {
    // Dispose current camera resources before switching
    if (_selectedIndex == 1 || _selectedIndex == 2) {
      // Coming from Story or Reel - give time for cleanup
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() => _selectedIndex = index);
        _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _centerTab(index);
      });
    } else {
      setState(() => _selectedIndex = index);
      _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _centerTab(index);
    }
  }

  void _centerTab(int index) {
    const double itemWidth = 80.0;
    const double horizontalPadding = 40.0; // Half of itemWidth for partial visibility

    // Calculate the offset to center the selected tab.
    // The center of the selected item relative to the ListView's starting point (after padding).
    final double centerOfSelectedItemInListView = (index * itemWidth) + (itemWidth / 2);

    // The center of the visible viewport.
    final double centerOfViewport = MediaQuery.of(context).size.width / 2;

    // Calculate the scroll position needed to bring the center of the selected item
    // to the center of the viewport, taking into account the ListView's own padding.
    double offset = centerOfSelectedItemInListView - centerOfViewport + horizontalPadding;


    _scrollController.animateTo(offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    ), duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  // New method to open settings for limited permission
  Future<void> _openPermissionSettings() async {
    await PhotoManager.openSetting();
  }

  Future<void> requestPermissionAndFetchMedia({bool showSnackbarOnDenial = false}) async {
    // Only request if not already requested or if explicitly forced (e.g., from retry button)
    if (_hasRequestedPermission && _galleryAssets.isNotEmpty && !showSnackbarOnDenial) {
      return;
    }

    _hasRequestedPermission = true;

    if (mounted) {
      setState(() {
        _isLoadingGallery = true;
      });
    }

    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth) {
        debugPrint('Photo library access: Authorized');
        await _fetchGalleryMedia();
      } else if (ps == PermissionState.limited) {
        debugPrint('Photo library access: Limited');
        await _fetchGalleryMedia(); // Fetch what's available under limited access
        if (mounted && showSnackbarOnDenial) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Access to some photos. Tap "Manage Access" to select more.'),
              action: SnackBarAction(
                label: 'Manage Access',
                onPressed: () {
                  _openPermissionSettings();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else if (ps == PermissionState.denied) {
        debugPrint('Photo library access: Denied');
        if (mounted && showSnackbarOnDenial) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission to access photos denied. Please enable it in settings.'),
              action: SnackBarAction(
                label: 'Go to Settings',
                onPressed: () {
                  _openPermissionSettings();
                },
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        debugPrint('Photo library permission status: ${ps.name}');
        if (mounted && showSnackbarOnDenial) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Photo library access is ${ps.name}. Limited functionality.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error during permission request or fetching media: $e');
      if (mounted && showSnackbarOnDenial) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading gallery: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
        });
      }
    }
  }

  Future<void> _fetchGalleryMedia() async {
    if (!mounted) return;

    setState(() {
      _isLoadingGallery = true;
    });

    try {
      // Fetch all available albums
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      if (albums.isNotEmpty) {

        final Map<String, AssetPathEntity> uniqueAlbums = {};
        for (final album in albums) {
          if (!uniqueAlbums.containsKey(album.name)) {
            uniqueAlbums[album.name] = album;
          }
        }

        final List<AssetPathEntity> filteredAlbums = uniqueAlbums.values.toList();
        if (mounted) {
          setState(() {
            _availableAlbums = filteredAlbums;
            // Ensure selected album exists in available albums, otherwise use first
            if (!filteredAlbums.any((album) => album.name == _selectedAlbum)) {
              _selectedAlbum = filteredAlbums.first.name;
            }
          });
        }

        // Find the selected album or use the first one (Recent)
        AssetPathEntity selectedAlbumEntity = filteredAlbums.firstWhere(
              (album) => album.name == _selectedAlbum,
          orElse: () => filteredAlbums.first,
        );

        final List<AssetEntity> assets = await selectedAlbumEntity.getAssetListPaged(
          page: 0,
          size: 50,
        );

        if (mounted) {
          setState(() {
            _galleryAssets = assets;
            if (assets.isNotEmpty && _selectedMedia == null) {
              _setSelectedMediaFromAsset(assets.first);
            } else if (assets.isEmpty) {
              _selectedMedia = null;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _availableAlbums = [];
            _galleryAssets = [];
            _selectedMedia = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching gallery media: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading gallery: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGallery = false;
        });
      }
    }
  }

  Future<void> _setSelectedMediaFromAsset(AssetEntity asset) async {
    final File? file = await asset.file;
    if (file != null) {
      // Calculate aspect ratio
      double aspectRatio = asset.width / asset.height;

      if (mounted) {
        setState(() {
          _selectedMedia = XFile(file.path);
          _mediaAspectRatio = aspectRatio;
          _useOriginalAspectRatio = false; // Default to Instagram ratio
          _transformation = Matrix4.identity(); // Reset zoom
          _transformationController.value = Matrix4.identity();
        });
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isGranted) {
      try {
        final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null) {
          if (mounted) {
            setState(() {
              _selectedMedia = pickedFile;
              _currentStage = PostCreationStage.postDetails; // Move to details stage
            });
          }
        }
      } catch (e) {
        debugPrint('Error picking image from camera: $e');
        if (mounted && e is MissingPluginException) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission denied or plugin not configured.')),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open camera: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to take photos.')),
        );
      }
    }
  }

  void _openTaggingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserTaggingScreen(
          currentUserId: supabase.auth.currentUser!.id, // Replace with actual user ID
          initialTaggedUsers: _taggedUsers,
          title: 'Tag People',
          onUsersSelected: (selectedUsers) {
            setState(() {
              _taggedUsers = selectedUsers;
            });
          },
        ),
      ),
    );
  }

  // You can implement this if you plan to support multiple images
  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedMultipleMedia = pickedFiles;
            _selectedMedia = pickedFiles.first; // Set the first one as preview
            _currentStage = PostCreationStage.postDetails; // Move to details stage
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick multiple images: $e')),
        );
      }
    }
  }

  Future<String?> _uploadMedia(XFile media) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final String fileExt = path.extension(media.path);
      final String exactName = '${const Uuid().v4()}$fileExt';
      final String fileName = '$userId/$exactName';

      Uint8List? compressedBytes;

      if (fileExt.toLowerCase() == '.jpg' ||
          fileExt.toLowerCase() == '.jpeg' ||
          fileExt.toLowerCase() == '.png') {
        // 🗜️ Compress image before upload
        compressedBytes = await FlutterImageCompress.compressWithFile(
          media.path,
          minWidth: 1080,
          minHeight: 1080,
          quality: 70,
          format: fileExt.toLowerCase() == '.png'
              ? CompressFormat.png
              : CompressFormat.jpeg,
        );

        if (compressedBytes == null) {
          throw Exception('Image compression failed');
        }
      } else {
        // 📄 For non-image media, upload as-is
        compressedBytes = await media.readAsBytes();
      }

      await supabase.storage.from('post-media').uploadBinary(fileName, compressedBytes);

      final publicUrl = supabase.storage.from('post-media').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return null;
    }
  }

  Future<void> _createPost() async {
    if (_selectedMedia == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select media to upload.')),
        );
      }
      return;
    }

    if (_captionController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please write a caption.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    final mediaUrl = await _uploadMedia(_selectedMedia!);
    if (mediaUrl == null) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
      return;
    }

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Create the post first and get the post ID
      final response = await supabase.from('posts').insert({
        'user_id': userId,
        'caption': _captionController.text.trim(),
        'image_url': mediaUrl,
        'location': _location,
        'disable_comments': _disableComments,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'use_original_ratio': _useOriginalAspectRatio,
        'image_transformation': _transformation.storage.join(','),
        'original_aspect_ratio': _mediaAspectRatio,
      }).select('id').single();

      final postId = response['id'] as String;

      // print("Tagged Users: ${_taggedUsers.map((user) => user.username)}");
      // print("Post ID: $postId");

      // Save tagged users to the post if any exist
      if (_taggedUsers.isNotEmpty) {
        await _taggingService.saveTaggedUsersToPost(
          postId: postId,
          taggedUsers: _taggedUsers,
        );

        // Optional: Notify tagged users
        // await _taggingService.notifyTaggedUsers(
        //   taggedUsers: _taggedUsers,
        //   postId: postId,
        //   authorId: userId,
        // );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.of(context).pop(); // Pop this screen after successful post
      }
    } catch (e) {
      debugPrint('Database insertion error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create post. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _openAdvancedSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text(
                      'Advanced Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Divider(color: Colors.grey),
                  SwitchListTile(
                    title: const Text(
                      'Disable Comments',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Turn off commenting on this post',
                      style: TextStyle(color: Colors.grey),
                    ),
                    value: _disableComments,
                    activeColor: Colors.blue,
                    onChanged: (value) {
                      setModalState(() {
                        _disableComments = value;
                      });
                      setState(() {
                        _disableComments = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onAlbumChanged(String? newAlbum) {
    if (newAlbum != null && newAlbum != _selectedAlbum) {
      setState(() {
        _selectedAlbum = newAlbum;
      });
      _fetchGalleryMedia();
    }
  }

// 6. Method to toggle aspect ratio
  void _toggleAspectRatio() {
    setState(() {
      _useOriginalAspectRatio = !_useOriginalAspectRatio;
      _transformation = Matrix4.identity(); // Reset zoom when changing aspect ratio
      _transformationController.value = Matrix4.identity();
    });
  }

  void _selectLocation() async {
    final selectedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSelectionScreen(),
      ),
    );

    if (selectedLocation != null && mounted) {
      setState(() {
        _location = selectedLocation;
      });
    }
  }

  // --- UI building methods for Post Creation Stage ---
  Widget _buildGallerySelectionUI() {
    return Column(
      children: [
        // Media Preview with Zoom and Aspect Ratio Controls
        Stack(
          children: [
            // Fixed Instagram 1:1 container
            AspectRatio(
              aspectRatio: 1.0, // Always maintain Instagram's 1:1 ratio for container
              child: Container(
                color: Colors.black,
                child: _selectedMedia != null
                    ? InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 3.0,
                  onInteractionUpdate: (details) {
                    setState(() {
                      _transformation = _transformationController.value;
                    });
                  },
                  child: Image.file(
                    File(_selectedMedia!.path),
                    // Change fit based on aspect ratio toggle
                    fit: _useOriginalAspectRatio ? BoxFit.contain : BoxFit.cover,
                  ),
                )
                    : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 60, color: Colors.white70),
                      SizedBox(height: 10),
                      Text('Select media from gallery below', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ),

            // Aspect Ratio Toggle Button (bottom-left)
            if (_selectedMedia != null)
              Positioned(
                left: 16,
                bottom: 10,
                child: GestureDetector(
                  onTap: _toggleAspectRatio,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _useOriginalAspectRatio ? Icons.crop_free : OIcons.EvaIcons.expand,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

            // Zoom Reset Button (top-right)
            if (_selectedMedia != null)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _transformation = Matrix4.identity();
                      _transformationController.value = Matrix4.identity();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.zoom_out_map,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Enhanced Controls Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Album Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: DropdownButton<String>(
                  value: _selectedAlbum,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  underline: const SizedBox(), // Remove default underline
                  items: _availableAlbums.map((AssetPathEntity album) {
                    return DropdownMenuItem<String>(
                      value: album.name,
                      child: Text(
                        album.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: _onAlbumChanged,
                ),
              ),

              // Aspect Ratio Info and Select Multiple Button
              Row(
                children: [
                  // // Aspect Ratio Indicator
                  // if (_selectedMedia != null)
                  //   Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  //     margin: const EdgeInsets.only(right: 8),
                  //     decoration: BoxDecoration(
                  //       color: Colors.grey.shade200,
                  //       borderRadius: BorderRadius.circular(12),
                  //     ),
                  //     child: Text(
                  //       _useOriginalAspectRatio
                  //           ? '${_mediaAspectRatio.toStringAsFixed(2)}:1'
                  //           : '1:1',
                  //       style: const TextStyle(
                  //         fontSize: 12,
                  //         fontWeight: FontWeight.bold,
                  //         color: Colors.black,
                  //       ),
                  //     ),
                  //   ),

                  // Select Multiple Button
                  ElevatedButton(
                    onPressed: _pickMultipleImages,
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size(134, 30),
                      backgroundColor: Colors.grey[400],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'SELECT MULTIPLE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _buildGalleryGrid(),
        ),
      ],
    );
  }

  Widget _buildGalleryGrid() {
    if (_isLoadingGallery) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_galleryAssets.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: () => requestPermissionAndFetchMedia(showSnackbarOnDenial: true),
          icon: const Icon(Icons.image, color: Colors.grey),
          label: const Text('No images found or permission denied. Tap to retry.', style: TextStyle(color: Colors.grey)),
          style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 images per row
        crossAxisSpacing: 2.0,
        mainAxisSpacing: 2.0,
      ),
      itemCount: _galleryAssets.length + 1, // +1 for the camera icon
      itemBuilder: (context, index) {
        if (index == 0) {
          // First item is the camera icon
          return GestureDetector(
            onTap: _pickImageFromCamera,
            child: Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.camera_alt, size: 40, color: Colors.black),
              ),
            ),
          );
        }
        final AssetEntity asset = _galleryAssets[index - 1]; // Adjust index for gallery assets

        return GestureDetector(
          onTap: () => _setSelectedMediaFromAsset(asset),
          child: Stack(
            children: [
              Positioned.fill(
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(
                    const ThumbnailSize(200, 200), // Larger thumbnail for grid
                    quality: 80,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              ),
              // Checkmark for selected media
              if (_selectedMedia != null && _selectedMedia!.path.contains(asset.id))
                Positioned.fill(
                  child: Container(
                    color: Colors.blue.withOpacity(0.3),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 30),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- UI building methods for Post Details Stage ---
  Widget _buildPostDetailsUI() {

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Media Preview with current aspect ratio and zoom state
          AspectRatio(
            aspectRatio: 1.0, // Always maintain Instagram's 1:1 container
            child: Container(
              color: Colors.black,
              child: _selectedMedia != null
                  ? Transform(
                transform: _transformation,
                child: Image.file(
                  File(_selectedMedia!.path),
                  // Change fit based on aspect ratio toggle
                  fit: _useOriginalAspectRatio ? BoxFit.contain : BoxFit.cover,
                ),
              )
                  : const Center(
                child: Text(
                  'No media selected',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),

          // // Aspect Ratio Info
          // if (_selectedMedia != null)
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //     color: Colors.grey.shade100,
          //     child: Row(
          //       children: [
          //         Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
          //         const SizedBox(width: 8),
          //         Text(
          //           'Aspect Ratio: ${_useOriginalAspectRatio ? '${_mediaAspectRatio.toStringAsFixed(2)}:1 (Original)' : '1:1 (Instagram)'}',
          //           style: TextStyle(
          //             color: Colors.grey.shade600,
          //             fontSize: 12,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),

          // Caption Input
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: const TextStyle(color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.black,
              ),
            ),
          ),

          const Divider(),

          // Location Selection
          ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
            title: Text(
              _location ?? 'Add Location',
              style: TextStyle(
                color: _location == null ? Colors.grey[700] : Colors.white,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _selectLocation,
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.person_add, color: Colors.white),
            title: Text(
              _taggedUsers.isEmpty
                  ? 'Tag People'
                  : 'Tagged ${_taggedUsers.length} people',
              style: const TextStyle(color: Colors.white),
            ),
            onTap: _openTaggingScreen,
          ),
          if (_taggedUsers.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 9),
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _taggedUsers.length,
                itemBuilder: (context, index) {
                  final user = _taggedUsers[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 70,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: user.profileImageUrl != null
                              ? NetworkImage(_getDisplayUrl(user.profileImageUrl!))
                              : null,
                          child: user.profileImageUrl == null
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        Text(
                          user.username,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(),

          // Advanced Settings
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.grey),
            title: const Text('Advanced Settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _openAdvancedSettings,
          ),

          const Divider(),
        ],
      ),
    );
  }

  String _getDisplayUrl(String profileUrl) {
    if (profileUrl.startsWith('http://') || profileUrl.startsWith('https://')) {
      return profileUrl;
    }
    return 'https://kprizlkexocjxvygfbyn.supabase.co/storage/v1/object/public/avatars/$profileUrl';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    // Determine PageView scrolling physics
    final ScrollPhysics pageViewPhysics = _currentStage == PostCreationStage.gallerySelection
        ? const PageScrollPhysics() // Enable scrolling in gallery selection
        : const NeverScrollableScrollPhysics(); // Disable scrolling in post details


    return Scaffold(
      appBar: _selectedIndex == 0 // Conditionally render the entire AppBar
          ? AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _currentStage == PostCreationStage.gallerySelection
                ? Icons.close // Close icon for gallery selection
                : Icons.arrow_back, // Back icon for post details
            color: Colors.white,
          ),
          onPressed: () {
            if (_currentStage == PostCreationStage.postDetails) {
              setState(() {
                _currentStage = PostCreationStage.gallerySelection; // Go back to gallery
              });
            } else {
              Navigator.of(context).pop(); // Close the screen entirely
            }
          },
        ),
        title: Text(
          loc!.newPost,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              if (_currentStage == PostCreationStage.gallerySelection) {
                if (_selectedMedia == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an image first.')),
                  );
                  return;
                }
                // Save the current display state before moving to details
                setState(() {
                  _postUseOriginalRatio = _useOriginalAspectRatio;
                  _postTransformation = _transformation;
                  _currentStage = PostCreationStage.postDetails;
                });
              } else {
                _createPost(); // Call the share function
              }
            },
            child: _isUploading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
                : Text(
              _currentStage == PostCreationStage.gallerySelection ? 'Next' : 'Share',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      )
          : null, // No AppBar for other tabs
      body: Stack( // Using Stack to position the custom tab bar over the PageView
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _tabs.length, // Number of tabs including LIVE
              physics: pageViewPhysics, // Apply conditional scrolling physics
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                  _centerTab(index);
                  // When changing pages, if it's not the Post tab,
                  // reset the post creation stage to gallery selection.
                  if (index != 0) {
                    _currentStage = PostCreationStage.gallerySelection;
                  }
                });
              },
              itemBuilder: (_, index) {
                if (index == 0) { // POST tab content
                  return _currentStage == PostCreationStage.gallerySelection
                      ? _buildGallerySelectionUI()
                      : SingleChildScrollView(child: _buildPostDetailsUI());
                } else if (index == 1) { // STORY tab content
                  return CreateStoryContent(cameraService: _cameraService);
                } else if (index == 2) { // REEL tab content
                  return CreateReelContent(cameraService: _cameraService);
                } else { // LIVE tab content (Placeholder)
                  return const Center(
                    child: Text(
                      'LIVE content goes here',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  );
                }
              },
            ),
          ),
          // Custom Floating Tab Bar at the bottom - only visible on gallery selection stage for any tab
          if (_currentStage == PostCreationStage.gallerySelection)
            Builder( // Using Builder to access context for screen width calculation
                builder: (context) {
                  double dynamicLeft;

                  // Define dynamicLeft based on selectedIndex
                  // These are example values; you may need to fine-tune them
                  // to achieve the exact visual positioning you desire.
                  if (_selectedIndex == 0) {
                    dynamicLeft = 150.0; // Keeps 'POST' tab visible towards the right
                  } else if (_selectedIndex == 1) {
                    // Adjust left to shift the bar so 'STORY' is more centered or prominent
                    dynamicLeft = MediaQuery.of(context).size.width / 2 - 142;
                  } else if (_selectedIndex == 2) {
                    // Further adjust for 'REEL'
                    dynamicLeft = MediaQuery.of(context).size.width / 2 - 220;
                  } else { // For _selectedIndex == 3 (LIVE) or any other unexpected index
                    // Align 'LIVE' towards the far left or adjust as needed
                    dynamicLeft = MediaQuery.of(context).size.width / 2 - 296;
                  }

                  return Positioned(
                    bottom: 20, // Adjusted bottom padding
                    left: dynamicLeft,
                    right: 0, // Keeping right as 0. This means the width of the tab bar container will be dynamic.
                    child: Container(
                      height: 40,
                      // Removed horizontal margin from Container
                      decoration: BoxDecoration(
                        // Make background transparent for Story/Reel/Live pages
                        color: (_selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 3)
                            ? Colors.transparent
                            : Colors.grey[900], // Dark background for the POST tab
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length,
                        // !!! IMPORTANT: Removed physics: NeverScrollableScrollPhysics() !!!
                        padding: const EdgeInsets.symmetric(horizontal: 20.0), // Reverted to 40.0 for half-hidden effect
                        itemBuilder: (context, index) {
                          // Removed isEffectivelyHidden logic to ensure all tabs are interactive
                          final isSelected = _selectedIndex == index;
                          return GestureDetector(
                            onTap: () => _onTabTap(index), // Always allow tapping
                            child: Container(
                              width: 80, // Fixed width for each tab item to maintain layout
                              alignment: Alignment.center,
                              child: Text(
                                _tabs[index],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white, // All visible tabs white
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
            ),
        ],
      ),
    );
  }
}