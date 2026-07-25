import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapPickerScreen({Key? key, this.initialPosition}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(10.03022, 105.78753); // Default to Can Tho
  bool _isLoadingLocation = false;
  double _currentZoom = 16.0;

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
