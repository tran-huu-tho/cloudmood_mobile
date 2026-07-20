import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class ExplorePostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;

  const ExplorePostCard({
    Key? key,
    required this.post,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = post['title'] ?? '';
    final coverImage = post['coverImage'] ?? 'https://via.placeholder.com/100';
    final viewCount = post['viewCount'] ?? 0;
    final likeCount = post['likeCount'] ?? 0;
    
    // Author or Platform
    final isPlatform = post['postType'] == 'PLATFORM_CURATION';
    final platformName = post['platformName'] ?? '';
    final platformLogo = post['platformLogo'] ?? '';
    
    // In db, user fields were updated to fullName and avatar, so we access them safely
    final authorName = isPlatform 
        ? platformName 
        : (post['author']?['fullName'] ?? 'Người dùng Ẩn danh');
    
    final avatarUrl = isPlatform 
        ? platformLogo 
        : (post['author']?['avatar'] ?? 'https://via.placeholder.com/150');

    final numberFormat = NumberFormat.compact();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(
            bottom: BorderSide(
              color: AppTheme.border,
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Square Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                coverImage,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 100,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // Right: Content
            Expanded(
              child: SizedBox(
                height: 100, // Match the height of the image
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Author & Stats Row
                    Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: NetworkImage(avatarUrl),
                          onBackgroundImageError: (_, __) {},
                        ),
                        const SizedBox(width: 6),
                        // Name
                        Expanded(
                          child: Text(
                            authorName,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.subtitleText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Stats
                    Row(
                      children: [
                        const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          numberFormat.format(likeCount),
                          style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.visibility_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          numberFormat.format(viewCount),
                          style: TextStyle(fontSize: 13, color: AppTheme.subtitleText),
                        ),
                        const Spacer(),
                        const Icon(Icons.shortcut, size: 20, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
