import 'package:Instagram/screens/profilescreen/single_post_view.dart';
import 'package:Instagram/screens/searchscreen/search_screen_state.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:icons_plus/icons_plus.dart'
    as OIcons;

import '../../services/supabase_service.dart'; // Adjust the import for your OIcons

class InstagramSearchScreen extends StatefulWidget {
  const InstagramSearchScreen({Key? key}) : super(key: key);

  @override
  State<InstagramSearchScreen> createState() => _InstagramSearchScreenState();
}

class _InstagramSearchScreenState extends State<InstagramSearchScreen> {
  late Future<List<String>> _futureImages;

  @override
  void initState() {
    super.initState();
    _futureImages = _fetchImagesFromStorage();
  }

  Future<List<String>> _fetchImagesFromStorage() async {
    final supabase = Supabase.instance.client;
    final List<String> imageUrls = [];

    try {
      final folders = await supabase.storage
          .from('post-media')
          .list(path: '', searchOptions: SearchOptions(limit: 100));

      for (final folder in folders) {
        final isFolder = !folder.name.contains('.'); // simulate a folder check

        if (isFolder) {
          final files = await supabase.storage.from('post-media').list(
              path: folder.name,
              searchOptions: const SearchOptions(limit: 100));

          for (final file in files) {
            if (file.name.endsWith('.jpg') ||
                file.name.endsWith('.png') ||
                file.name.endsWith('.jpeg')) {
              final publicUrl = supabase.storage
                  .from('post-media')
                  .getPublicUrl('${folder.name}/${file.name}');
              imageUrls.add(publicUrl);
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching images: $e');
    }

    return imageUrls;
  }

  Future<Map<String, dynamic>> _fetchPosts(String userId) async {
    final supabase = Supabase.instance.client;

    final postsRes = await supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    return {
      'posts': postsRes,
    };
  }

  Future<void> _refreshImages() async {
    final images = await _fetchImagesFromStorage();
    setState(() {
      _futureImages = Future.value(images);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: TextField(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          SearchScreen(), // Assuming you have a detailed SearchScreen
                    ),
                  );
                },
                decoration: InputDecoration(
                  hintText: 'Ask Meta AI or Search',
                  hintStyle: TextStyle(color: Colors.grey[700]),
                  prefixIcon: Icon(
                    OIcons.Bootstrap.meta,
                    color: Colors.blue,
                    size: 25,
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
                style: TextStyle(color: Colors.white),
                readOnly: true, // Makes it act as a button
              ),
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _futureImages,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading images',
                          style: TextStyle(color: Colors.white)),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text('No images found',
                          style: TextStyle(color: Colors.white)),
                    );
                  }

                  final images = snapshot.data!;


                  return RefreshIndicator(
                    onRefresh: _refreshImages,
                    child: GridView.builder(
                      padding: EdgeInsets.all(3),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            // Handle image tap - navigate to detail view, etc.
                            _showImageDetailView(context, images[index]);
                            // Navigator.push(context, MaterialPageRoute(builder: (_) => SinglePostView(post: , Url: images[index])));
                          },
                          child: Hero(
                            tag: 'searchImage_$index',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: Image.network(
                                images[index],
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[900],
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.grey[800],
                                  child: Icon(Icons.error, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDetailView(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImageDetailScreen(imageUrl: imageUrl),
      ),
    );
  }
}

// Simple image detail screen
class _ImageDetailScreen extends StatelessWidget {
  final String imageUrl;

  const _ImageDetailScreen({Key? key, required this.imageUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
