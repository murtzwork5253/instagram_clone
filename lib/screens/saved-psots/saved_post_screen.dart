import 'package:Instagram/screens/profilescreen/single_post_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../services/insta_data_provider.dart';
import '../../services/supabase_service.dart';

class SavedPostsScreen extends StatefulWidget {
  @override
  _SavedPostsScreenState createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<PostData> savedPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    final provider = Provider.of<InstaDataProvider>(context, listen: false);
    final posts = await provider.getSavedPosts();
    setState(() {
      savedPosts = posts;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.savedPosts),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : savedPosts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              loc.noPostSavedYet,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18,
              ),
            ),
          ],
        ),
      )
          : GridView.builder(
        padding: EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: savedPosts.length,
        itemBuilder: (context, index) {
          final post = savedPosts[index];
          return GestureDetector(
            onTap: () {
              // Navigate to post detail or full screen view
              // You can implement this based on your app's navigation
              Navigator.push(context, MaterialPageRoute(builder: (_) => SinglePostView(post: post, Url: post.profileImageUrl!)));
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  post.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: Icon(
                        Icons.error,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}