import 'dart:io';
import 'package:Instagram/screens/createscreens/create_reels/create_reel_screen.dart';
import 'package:Instagram/screens/createscreens/create_story/create_story_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For MissingPluginException
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:photo_manager/photo_manager.dart';

// Define an enum to manage the different stages of post creation
enum PostCreationStage {
  gallerySelection,
  postDetails,
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

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

  // Replaced TabController with PageController and ScrollController for custom tabs
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _tabs = ['POST', 'STORY', 'REEL', 'LIVE']; // Added LIVE tab
  int _selectedIndex = 0; // Tracks the selected tab for the custom tab bar

  PostCreationStage _currentStage = PostCreationStage.gallerySelection; // Start at gallery selection

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page?.round() != _selectedIndex) {
        setState(() {
          _selectedIndex = _pageController.page!.round();
          _centerTab(_selectedIndex); // Center the tab when PageView changes
        });
      }
    });

    // Request permissions and fetch media as soon as the screen is built
    requestPermissionAndFetchMedia();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose(); // Dispose scroll controller
    _captionController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _centerTab(index);
    // If the tab changes, we should reset the stage to gallery selection
    // for the new content type (Story/Reel) if that's how they'll work.
    // For now, only 'Post' tab is fully implemented through stages.
    if (index == 0) { // Only reset stage if we're on the 'Post' tab
      setState(() {
        _currentStage = PostCreationStage.gallerySelection;
      });
    } else {
      // For other tabs, ensure we are in gallery selection for consistency if they also handle media selection
      setState(() {
        _currentStage = PostCreationStage.gallerySelection;
      });
    }
  }

  void _centerTab(int index) {
    // Item width (approximate, or can be calculated precisely)
    const double itemWidth = 80.0;
    double offset =
        (itemWidth * index) - (MediaQuery.of(context).size.width - itemWidth) / 2;
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
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image, // Fetch only images for now
        hasAll: true,
      );

      if (albums.isNotEmpty) {
        final AssetPathEntity recentAlbum = albums.first;
        final List<AssetEntity> assets = await recentAlbum.getAssetListPaged(
          page: 0,
          size: 50, // Fetch up to 50 recent images for preview
        );

        if (mounted) {
          setState(() {
            _galleryAssets = assets;
            if (assets.isNotEmpty) {
              if (_selectedMedia == null) {
                _setSelectedMediaFromAsset(assets.first);
              }
            } else {
              _selectedMedia = null; // No assets found
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
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
      if (mounted) {
        setState(() {
          _selectedMedia = XFile(file.path);
        });
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
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
      final String exactname = '${const Uuid().v4()}$fileExt';
      final fileName = '${userId}/${exactname}';

      final bytes = await media.readAsBytes();
      await supabase.storage.from('post-media').uploadBinary(fileName, bytes);

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

      await supabase.from('posts').insert({
        'user_id': userId,
        'caption': _captionController.text.trim(),
        'image_url': mediaUrl,
        'location': _location,
        // 'disable_comments': _disableComments,
        // 'share_to_other_platforms': _shareToOtherPlatforms,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Disable Comments'),
                    value: _disableComments,
                    onChanged: (value) {
                      setModalState(() {
                        _disableComments = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Share to Other Platforms'),
                    value: _shareToOtherPlatforms,
                    onChanged: (value) {
                      setModalState(() {
                        _shareToOtherPlatforms = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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

  void _selectLocation() async {
    // In a real app, you'd use a location picker package here.
    if (mounted) {
      setState(() {
        _location = 'Surat, Gujarat, India'; // Example dummy location
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location added (simulated).')),
      );
    }
  }

  // --- UI building methods for Post Creation Stage ---
  Widget _buildGallerySelectionUI() {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            color: Colors.black, // Darker background for media preview
            child: _selectedMedia != null
                ? Image.file(
              File(_selectedMedia!.path),
              fit: BoxFit.cover,
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
        // Dropdown for Recents/Photos/Videos (placeholder)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Recents Dropdown
              DropdownButton<String>(
                value: 'Recents', // Currently fixed
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
                items: const <String>['Recents', 'Photos', 'Videos'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  // Implement filtering logic here based on newValue
                  debugPrint('Selected gallery filter: $newValue');
                },
              ),
              // Select Multiple Button
              ElevatedButton(
                onPressed: _pickMultipleImages, // Enable this if you implement multiple image picking
                style: ElevatedButton.styleFrom(
                  fixedSize: const Size(134, 20),
                  backgroundColor: Colors.grey[400], // Background color
                  foregroundColor: Colors.black, // Text color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('SELECT MULTIPLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildGalleryGrid(), // The grid view for gallery images
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
    return SafeArea( // Added SafeArea here for the caption details screen
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1, // Instagram post aspect ratio
            child: Container(
              color: Colors.black,
              child: _selectedMedia != null
                  ? Image.file(
                File(_selectedMedia!.path),
                fit: BoxFit.cover,
              )
                  : const Center(child: Text('No media selected', style: TextStyle(color: Colors.white70))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _captionController,
              maxLines: 4,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: TextStyle(color: Colors.white),
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
          ListTile(
            leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
            title: Text(
              _location ?? 'Add Location',
              style: TextStyle(color: _location == null ? Colors.grey[700] : Colors.white),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _selectLocation,
          ),
          const Divider(),
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

  @override
  Widget build(BuildContext context) {
    // Determine PageView scrolling physics
    final ScrollPhysics pageViewPhysics = _currentStage == PostCreationStage.gallerySelection
        ? const PageScrollPhysics() // Enable scrolling in gallery selection
        : const NeverScrollableScrollPhysics(); // Disable scrolling in post details

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _selectedIndex == 0 ? Colors.black : Colors.transparent, // Transparent for other tabs
        elevation: 0,
        leading: _selectedIndex == 0 // Only show leading icon for POST tab
            ? IconButton(
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
        )
            : null, // No leading icon for other tabs
        title: _selectedIndex == 0 // Only show title for POST tab
            ? Text(
          'New post',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        )
            : null, // No title for other tabs
        centerTitle: true,
        actions: _selectedIndex == 0 // Only show actions for POST tab
            ? [
          TextButton(
            onPressed: () {
              if (_currentStage == PostCreationStage.gallerySelection) {
                if (_selectedMedia == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an image first.')),
                  );
                  return;
                }
                setState(() {
                  _currentStage = PostCreationStage.postDetails; // Move to post details
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
        ]
            : null, // No actions for other tabs
      ),

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
                  return const CreateStoryContent();
                } else if (index == 2) { // REEL tab content
                  return const CreateReelContent();
                } else { // LIVE tab content (Placeholder)
                  return const Center(
                    child: Text(
                      'LIVE content goes here',
                      style: TextStyle(fontSize: 24, color: Colors.black),
                    ),
                  );
                }
              },
            ),
          ),
          // Custom Floating Tab Bar at the bottom - only visible on gallery selection stage for any tab
          if (_currentStage == PostCreationStage.gallerySelection)
            Positioned(
              bottom: 20, // Adjusted bottom padding
              left: 0,
              right: 0,
              child: Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.grey[900], // Dark background for the custom tab bar
                  borderRadius: BorderRadius.circular(25),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  itemBuilder: (context, index) {
                    final isSelected = _selectedIndex == index;
                    return GestureDetector(
                      onTap: () => _onTabTap(index),
                      child: Container(
                        width: 80, // Fixed width for each tab item
                        alignment: Alignment.center,
                        child: Text(
                          _tabs[index],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
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
            ),
        ],
      ),
    );
  }
}