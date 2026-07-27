import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapPickerScreen({Key? key, this.initialPosition}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng _currentCenter = const LatLng(10.03022, 105.78753); // Default to Can Tho
  bool _isLoadingLocation = false;
  double _currentZoom = 16.0;

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  Timer? _debounceTimer;

  String _cleanLocationName(String rawName) {
    if (rawName.isEmpty) return '';
    return rawName
        .replaceAll(RegExp(r'\s*\(?\b\d{4,6}\b\)?\s*,?'), '')
        .replaceAll(RegExp(r',\s*,'), ',')
        .replaceAll(RegExp(r'^,\s*|\s*,$'), '')
        .trim();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null && 
        widget.initialPosition!.latitude != 0.0 && 
        widget.initialPosition!.longitude != 0.0) {
      _currentCenter = widget.initialPosition!;
    } else {
      _determinePosition();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() {
      _isLoadingLocation = true;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = newPos;
      });
      _mapController.move(newPos, 16.0);
    } catch (e) {
      debugPrint('Error getting location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (query.trim().length >= 2) {
        _searchLocation(query);
      } else {
        setState(() {
          _searchResults = [];
          _showSearchResults = false;
        });
      }
    });
  }

  Future<void> _searchLocation(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&accept-language=vi',
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'CloudMoodMobile/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data is List ? data : [];
          _showSearchResults = _searchResults.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(dynamic item) {
    final double? lat = double.tryParse(item['lat']?.toString() ?? '');
    final double? lon = double.tryParse(item['lon']?.toString() ?? '');

    if (lat != null && lon != null) {
      final newPos = LatLng(lat, lon);
      final cleanedName = _cleanLocationName(item['display_name']?.toString() ?? '');
      setState(() {
        _currentCenter = newPos;
        _showSearchResults = false;
        _searchController.text = cleanedName.split(',')[0];
      });
      _mapController.move(newPos, 16.0);
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chọn vị trí trên bản đồ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: _currentZoom,
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  setState(() {
                    _currentCenter = position.center!;
                    if (position.zoom != null) {
                      _currentZoom = position.zoom!;
                    }
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.cloudmood.app',
              ),
            ],
          ),
          
          // Center Pin Overlay Indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 36),
              child: Icon(
                Icons.location_on_rounded,
                size: 44,
                color: AppTheme.red,
              ),
            ),
          ),

          // Top Floating Search Bar
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search_rounded, color: AppTheme.subtitleText, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(fontSize: 13, color: AppTheme.darkText),
                          decoration: InputDecoration(
                            hintText: 'Tìm tên đường, địa điểm gần ghim...',
                            hintStyle: TextStyle(fontSize: 13, color: AppTheme.subtitleText.withOpacity(0.7)),
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_isSearching)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppTheme.subtitleText,
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        ),
                    ],
                  ),
                ),

                // Search Results Dropdown List
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.grey.withOpacity(0.15)),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        final rawName = item['display_name']?.toString() ?? '';
                        final displayName = _cleanLocationName(rawName);
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: Icon(Icons.location_on_outlined, color: AppTheme.primary, size: 18),
                          title: Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: AppTheme.darkText),
                          ),
                          onTap: () => _selectSearchResult(item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Panel containing GPS and Confirmation Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Floating GPS Button (positioned above bottom card)
                FloatingActionButton(
                  heroTag: 'gps_fab',
                  onPressed: _isLoadingLocation ? null : _determinePosition,
                  backgroundColor: AppTheme.surface,
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        )
                      : Icon(Icons.my_location_rounded, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),

                // Confirmation Details Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: AppTheme.surface,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gps_fixed_rounded, color: AppTheme.primary, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Tọa độ ghim hiện tại:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.subtitleText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_currentCenter.latitude.toStringAsFixed(6)}, ${_currentCenter.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context, _currentCenter);
                            },
                            child: const Text(
                              'XÁC NHẬN VỊ TRÍ NÀY',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Zoom in / Zoom out controls (raised up to avoid bottom card)
          Positioned(
            bottom: 240,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoom_in_fab',
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom + 1).clamp(1.0, 20.0);
                    });
                    _mapController.move(_currentCenter, _currentZoom);
                  },
                  backgroundColor: AppTheme.surface,
                  child: Icon(Icons.add, color: AppTheme.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'zoom_out_fab',
                  onPressed: () {
                    setState(() {
                      _currentZoom = (_currentZoom - 1).clamp(1.0, 20.0);
                    });
                    _mapController.move(_currentCenter, _currentZoom);
                  },
                  backgroundColor: AppTheme.surface,
                  child: Icon(Icons.remove, color: AppTheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
