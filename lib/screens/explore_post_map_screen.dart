import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'place_ai_chat_screen.dart';
import '../utils/time_utils.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import '../widgets/save_to_trip_bottom_sheet.dart';

class ExplorePostMapScreen extends StatefulWidget {
  final String title;
  final List<dynamic> items; // The items list from ExplorePost
  final List<dynamic>? sections; // Custom sections with colorCode and iconCode
  final int? initialPlaceId; // Place ID to focus on initially

  const ExplorePostMapScreen({
    Key? key,
    required this.title,
    required this.items,
    this.sections,
    this.initialPlaceId,
  }) : super(key: key);

  @override
  _ExplorePostMapScreenState createState() => _ExplorePostMapScreenState();
}

class _ExplorePostMapScreenState extends State<ExplorePostMapScreen> {
  final MapController _mapController = MapController();
  late final PageController _pageController;
  
  List<Map<String, dynamic>> _places = [];
  int _selectedIndex = 0;
  LatLng? _mapCenter;

  @override
  void initState() {
    super.initState();
    _extractPlaces();
    _pageController = PageController(initialPage: _selectedIndex, viewportFraction: 0.9);
    
    if (_places.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final loc = _places[_selectedIndex]['location'] as LatLng;
          _mapController.move(loc, widget.initialPlaceId != null ? 16.0 : 14.5);
        }
      });
    }
  }

  String _resolveSectionName(int placeIndex) {
    if (placeIndex < 0 || placeIndex >= _places.length) return '';
    final item = _places[placeIndex]['item'];
    final place = _places[placeIndex]['place'];
    if (item['section'] != null && item['section'].toString().isNotEmpty) return item['section'].toString();
    if (place != null && place['section'] != null && place['section'].toString().isNotEmpty) return place['section'].toString();
    final itemIndex = widget.items.indexOf(item);
    for (int i = itemIndex; i >= 0; i--) {
      if (i < widget.items.length && widget.items[i]['itemType'] == 'SECTION_HEADER' && widget.items[i]['content'] != null) {
        return widget.items[i]['content'].toString();
      }
    }
    return '';
  }

  Color _getMarkerColor(int placeIndex) {
    final secName = _resolveSectionName(placeIndex);
    final sections = widget.sections ?? [];
    for (var sec in sections) {
      if (sec is Map) {
        final name = (sec['name'] ?? '').toString();
        if ((secName.isNotEmpty && name.toLowerCase().trim() == secName.toLowerCase().trim()) || (secName.isEmpty && sections.length == 1)) {
          if (sec['colorCode'] != null) {
            try { return Color(int.parse(sec['colorCode'].toString())); } catch (_) {}
          }
        }
      }
    }
    final item = _places[placeIndex]['item'];
    final place = _places[placeIndex]['place'];
    final directColor = item['colorCode'] ?? place?['colorCode'];
    if (directColor != null) {
      try { return Color(int.parse(directColor.toString())); } catch (_) {}
    }
    return AppTheme.primary;
  }

  IconData? _getMarkerIcon(int placeIndex) {
    final secName = _resolveSectionName(placeIndex);
    final sections = widget.sections ?? [];
    for (var sec in sections) {
      if (sec is Map) {
        final name = (sec['name'] ?? '').toString();
        if ((secName.isNotEmpty && name.toLowerCase().trim() == secName.toLowerCase().trim()) || (secName.isEmpty && sections.length == 1)) {
          if (sec['iconCode'] != null) {
            try {
              final rawCode = int.parse(sec['iconCode'].toString());
              if (rawCode != 983363 && rawCode != 58055 && rawCode != 0) {
                return IconData(rawCode, fontFamily: 'MaterialIcons');
              }
            } catch (_) {}
          }
        }
      }
    }
    final item = _places[placeIndex]['item'];
    final place = _places[placeIndex]['place'];
    final directIcon = item['iconCode'] ?? place?['iconCode'];
    if (directIcon != null) {
      try {
        final rawCode = int.parse(directIcon.toString());
        if (rawCode != 983363 && rawCode != 58055 && rawCode != 0) {
          return IconData(rawCode, fontFamily: 'MaterialIcons');
        }
      } catch (_) {}
    }
    return null;
  }

  void _extractPlaces() {
    int counter = 1;
    int targetIndex = 0;
    for (var item in widget.items) {
      if (item['itemType'] == 'PLACE' && item['place'] != null) {
        final place = item['place'];
        double? lat = double.tryParse(place['latitude']?.toString() ?? '');
        double? lng = double.tryParse(place['longitude']?.toString() ?? '');
        
        if (lat != null && lng != null) {
          final placeId = place['id'] as int?;
          if (widget.initialPlaceId != null && placeId == widget.initialPlaceId) {
            targetIndex = _places.length;
          }
          _places.add({
            'index': counter++,
            'item': item,
            'place': place,
            'location': LatLng(lat, lng),
          });
        }
      }
    }

    _selectedIndex = targetIndex;
    if (_places.isNotEmpty) {
      _mapCenter = _places[_selectedIndex]['location'];
    } else {
      _mapCenter = const LatLng(10.0452, 105.7469); // Default Can Tho
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
    final loc = _places[index]['location'] as LatLng;
    _mapController.move(loc, 15.0);
  }

  void _onMarkerTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Stack(
        children: [
          // FlutterMap
          if (_mapCenter != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _mapCenter!,
                initialZoom: 14.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&apistyle=s.t%3A2%7Cp.v%3Aoff',
                  userAgentPackageName: 'com.cloudmood.app',
                ),
                MarkerLayer(
                  markers: _places.asMap().entries.map((entry) {
                    final index = entry.key;
                    final placeData = entry.value;
                    final isSelected = index == _selectedIndex;
                    final markerColor = _getMarkerColor(index);
                    final markerIcon = _getMarkerIcon(index);
                    
                    return Marker(
                      point: placeData['location'],
                      width: isSelected ? 48 : 36,
                      height: isSelected ? 48 : 36,
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: isSelected ? 3.0 : 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withAlpha(isSelected ? 100 : 60),
                                blurRadius: isSelected ? 12 : 4,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: markerIcon != null
                                ? Icon(
                                    markerIcon,
                                    color: Colors.white,
                                    size: isSelected ? 24 : 18,
                                  )
                                : Text(
                                    '${placeData['index']}',
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
              bottom: 24,
              height: 270,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _places.length,
                itemBuilder: (context, index) {
                  final placeData = _places[index];
                  final item = placeData['item'];
                  final place = placeData['place'] as Map<String, dynamic>;
                  
                  final placeName = (place['name'] ?? '').toString();
                  final placeImage = (place['image'] ?? place['coverImage'] ?? '').toString();
                  final content = (item['content'] ?? '').toString();
                  final placeIndex = placeData['index'];
                  final cardColor = _getMarkerColor(index);
                  final cardIcon = _getMarkerIcon(index);
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
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
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: cardColor,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: cardIcon != null
                                  ? Icon(cardIcon, color: Colors.white, size: 15)
                                  : Text(
                                      '$placeIndex',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                placeName,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
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
                                  content.isNotEmpty
                                      ? content
                                      : (place['description']?.toString().isNotEmpty == true
                                          ? place['description'].toString()
                                          : 'Đang cập nhật thông tin địa điểm...'),
                                  style: TextStyle(fontSize: 13, color: AppTheme.subtitleText, height: 1.4),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (placeImage.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    placeImage,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 20),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        // Rating and Tripadvisor logo
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              '${place['rating'] ?? 4.5} (${place['userRatingCount'] ?? 1035})',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                            ),
                            const SizedBox(width: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Image.asset('assets/images/tripadvisor.jpg', width: 16, height: 16, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        
                        // Time
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, color: Colors.grey[600], size: 15),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final hoursText = TimeUtils.getOpeningHoursText(place['openingHours']);
                                  final isClosed = hoursText.toLowerCase().contains('đóng cửa');
                                  return Text(
                                    hoursText,
                                    style: TextStyle(
                                      fontSize: 12.5, 
                                      color: isClosed ? Colors.red[700] : AppTheme.darkText,
                                      fontWeight: isClosed ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
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
                              // 1. Nút Lưu (Save to trip bottom sheet)
                              InkWell(
                                onTap: () {
                                  SaveToTripBottomSheet.show(
                                    context,
                                    place,
                                    onSaved: () {},
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primary.withAlpha(60),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text('Lưu', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // 2. Nút Chi tiết (Place detail bottom sheet)
                              InkWell(
                                onTap: () {
                                  PlaceDetailBottomSheet.show(context, place);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('Chi tiết', style: TextStyle(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // 3. Nút Chỉ đường (Google Maps / OpenStreetMap directions)
                              InkWell(
                                onTap: () async {
                                  final name = (place['name'] ?? '').toString();
                                  final address = (place['address'] ?? '').toString();
                                  final lat = place['latitude'];
                                  final lon = place['longitude'];
                                  final destinationQuery = (lat != null && lon != null)
                                      ? '$lat,$lon'
                                      : (name.isNotEmpty ? '$name $address' : 'Cần Thơ');
                                  final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destinationQuery)}');
                                  try {
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                    } else {
                                      await launchUrl(url);
                                    }
                                  } catch (e) {
                                    debugPrint('Error launching directions: $e');
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.directions_rounded, color: AppTheme.darkText, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // 4. Nút Hỏi AI (AI Chat screen)
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.auto_awesome, color: AppTheme.darkText, size: 16),
                                      const SizedBox(width: 4),
                                      Text('Hỏi AI', style: TextStyle(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.bold)),
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
