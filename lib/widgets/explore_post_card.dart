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
    final coverImage = (post['coverImage'] != null && post['coverImage'].toString().isNotEmpty && !post['coverImage'].toString().contains('via.placeholder.com'))
        ? post['coverImage']
        : 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200&q=80';
    final viewCount = post['viewCount'] ?? 0;
    final likeCount = post['likeCount'] ?? 0;
    
    // Author or Platform
    final isPlatform = post['postType'] == 'PLATFORM_CURATION';
    final platformName = post['platformName'] ?? '';
    final platformLogo = post['platformLogo'] ?? '';
    
    final authorName = isPlatform 
        ? platformName 
        : (post['author']?['fullName'] ?? 'Người dùng Ẩn danh');
    
    final authorAvatar = post['author']?['avatar']?.toString() ?? '';
    final avatarUrl = isPlatform 
        ? platformLogo 
        : (authorAvatar.isNotEmpty && !authorAvatar.contains('via.placeholder.com')
            ? authorAvatar
            : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&q=80');

    final numberFormat = NumberFormat.compact();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // 1. Background Cover Image
                  Positioned.fill(
                    child: Image.network(
                      coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 40),
                        );
                      },
                    ),
                  ),

                  // 2. Dark Gradient Overlay (Bottom to Top)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(35),
                            Colors.black.withAlpha(70),
                            Colors.black.withAlpha(215),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // 3. Top Badge Tag
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPlatform ? const Color(0xFF4F46E5).withAlpha(210) : Colors.black.withAlpha(100),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withAlpha(50),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPlatform ? Icons.verified_rounded : Icons.explore_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isPlatform ? (platformName.isNotEmpty ? platformName : 'Chính thức') : 'Khám phá',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. Content (Bottom)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.25,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 4,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        // Author & Stats Bar
                        Row(
                          children: [
                            // Author Avatar
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withAlpha(200), width: 1.2),
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.white24,
                                    child: const Icon(Icons.person, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Author Name
                            Expanded(
                              child: Text(
                                authorName,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(230),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Like count
                            Row(
                              children: [
                                const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  numberFormat.format(likeCount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),

                            // View count
                            Row(
                              children: [
                                const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  numberFormat.format(viewCount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
