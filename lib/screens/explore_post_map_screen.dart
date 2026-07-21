import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';
import 'place_ai_chat_screen.dart';
import '../utils/time_utils.dart';

class ExplorePostMapScreen extends StatefulWidget {
  final String title;
  final List<dynamic> items; // The items list from ExplorePost

  const ExplorePostMapScreen({
    Key? key,
    required this.title,
    required this.items,
  }) : super(key: key);

  @override
  _ExplorePostMapScreenState createState() => _ExplorePostMapScreenState();
}

class _ExplorePostMapScreenState extends State<ExplorePostMapScreen> {
  final MapController _mapController = MapController();
  final PageController _pageController = PageController(viewportFraction: 0.9);
  
  List<Map<String, dynamic>> _places = [];
  int _selectedIndex = 0;
  LatLng? _mapCenter;

  @override
  void initState() {
    super.initState();
    _extractPlaces();
  }

  void _extractPlaces() {
    int counter = 1;
    for (var item in widget.items) {
      if (item['itemType'] == 'PLACE' && item['place'] != null) {
        final place = item['place'];
        if (place['latitude'] != null && place['longitude'] != null) {
          _places.add({
            'index': counter,
            'item': item,
            'place': place,
            'lat': (place['latitude'] as num).toDouble(),
            'lng': (place['longitude'] as num).toDouble(),
          });
        }
        counter++;
      }
    }
    
    if (_places.isNotEmpty) {
      _mapCenter = LatLng(_places[0]['lat'], _places[0]['lng']);
    } else {
      _mapCenter = const LatLng(21.028511, 105.804817); // Default Hanoi
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
    final lat = _places[index]['lat'];
    final lng = _places[index]['lng'];
    _mapController.move(LatLng(lat, lng), 16.0);
  }

  Widget _buildReviewStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 14);
        } else if (index < rating && (rating - rating.floor()) >= 0.5) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 14);
        } else {
          return const Icon(Icons.star_border, color: Colors.amber, size: 14);
        }
      }),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getSubCategoryText(dynamic subCategory) {
    if (subCategory is String) return subCategory;
    if (subCategory is Map) return subCategory['name']?.toString() ?? subCategory.values.first.toString();
    return subCategory.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // The Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter!,
              initialZoom: 15.5,
              onTap: (_, __) {}, // Optional
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&apistyle=s.t%3A2%7Cp.v%3Aoff',
              ),
              MarkerLayer(
                markers: _places.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final placeData = entry.value;
                  final isSelected = idx == _selectedIndex;
                  final lat = placeData['lat'];
                  final lng = placeData['lng'];
                  final placeIndex = placeData['index'];

                  final markerSize = isSelected ? 48.0 : 36.0;

                  return Marker(
                    point: LatLng(lat, lng),
                    width: markerSize,
                    height: markerSize,
                    child: GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          idx,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935), // Red
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '$placeIndex',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isSelected ? 18 : 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // Bottom Place Cards
          if (_places.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 30, // Some padding from bottom
              height: 280, // Increased height to fit new buttons
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _places.length,
                itemBuilder: (context, index) {
                  final placeData = _places[index];
                  final item = placeData['item'];
                  final place = placeData['place'];
                  
                  final placeName = place['name'] ?? '';
                  final placeImage = place['image'] ?? 'https://via.placeholder.com/300x200';
                  final category = place['category']?['name'] ?? 'Địa điểm';
                  final content = item['content'] ?? '';
                  final placeIndex = placeData['index'];
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Index circle, Name
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFFE53935),
                              child: Text(
                                '$placeIndex',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                placeName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description and Image
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  content.isNotEmpty ? content : (place['description']?.toString().isNotEmpty == true ? place['description'] : 'Đang cập nhật thông tin...'),
                                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  placeImage,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200]),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Rating and Tripadvisor logo
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${place['rating'] ?? 4.5} (${place['userRatingCount'] ?? 7609})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            ),
                            const SizedBox(width: 8),
                            Image.asset('assets/images/tripadvisor.jpg', width: 16, height: 16, fit: BoxFit.contain),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Time
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled, color: Colors.grey, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final hoursText = TimeUtils.getOpeningHoursText(place['openingHours']);
                                  final isClosed = hoursText.toLowerCase().contains('đóng cửa');
                                  return Text(
                                    hoursText,
                                    style: TextStyle(
                                      fontSize: 13, 
                                      color: isClosed ? Colors.red : Colors.black87,
                                      fontWeight: isClosed ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Action Buttons
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Lưu
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF05141),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.bookmark_border, color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text('Lưu', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Chi tiết
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Chi tiết', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              
                              // Direction
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.directions, color: Colors.black87, size: 16),
                              ),
                              const SizedBox(width: 8),
                              
                              // Hỏi AI
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PlaceAIChatScreen(placeName: place['name'] ?? 'Địa điểm'),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.auto_awesome, color: Colors.black87, size: 16),
                                      SizedBox(width: 6),
                                      Text('Hỏi AI', style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
