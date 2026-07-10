import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SaveToTripBottomSheet extends StatefulWidget {
  final Map<String, dynamic> place;
  final VoidCallback onSaved;

  const SaveToTripBottomSheet({super.key, required this.place, required this.onSaved});

  @override
  State<SaveToTripBottomSheet> createState() => _SaveToTripBottomSheetState();
}

class _SaveToTripBottomSheetState extends State<SaveToTripBottomSheet> {
  int _step = 1;
  bool _isLoading = true;
  List<Map<String, dynamic>> _itineraries = [];
  Map<String, dynamic>? _selectedItinerary;
  Map<String, dynamic>? _tripDetails;

  final Set<String> _localSelectedSections = {};
  final Set<int> _localSelectedDays = {};
  final Map<String, int> _originalSections = {};
  final Map<int, int> _originalDays = {};

  final List<Color> _markerColors = [
    AppTheme.red,
    AppTheme.primary,
    AppTheme.accent,
    AppTheme.amber,
    AppTheme.primaryLight,
    AppTheme.green,
  ];

  @override
  void initState() {
    super.initState();
    _fetchItineraries();
  }

  Future<void> _fetchItineraries() async {
    final userId = AuthService().currentUser.value?.id;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    final itins = await DatabaseService().fetchUserItineraries(userId);
    if (mounted) {
      setState(() {
        _itineraries = itins;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectItinerary(Map<String, dynamic> itinerary) async {
    setState(() {
      _selectedItinerary = itinerary;
      _isLoading = true;
      _step = 2;
    });
    
    final details = await DatabaseService().fetchItineraryById(itinerary['id']);
    if (mounted) {
      final savedPlaces = details?['savedPlaces'] as List? ?? [];
      final detailsList = details?['details'] as List? ?? [];
      final targetPlaceId = widget.place['id'] ?? widget.place['placeId'];

      _localSelectedSections.clear();
      _originalSections.clear();
      for (var d in savedPlaces) {
        final pid = d['placeId'] ?? (d['place'] != null ? d['place']['id'] : null);
        if (pid == targetPlaceId && d['section'] != null) {
          _localSelectedSections.add(d['section']);
          _originalSections[d['section']] = d['id'];
        }
      }

      _localSelectedDays.clear();
      _originalDays.clear();
      for (var d in detailsList) {
        final pid = d['placeId'] ?? (d['place'] != null ? d['place']['id'] : null);
        if (pid == targetPlaceId && d['day'] != null) {
          _localSelectedDays.add(d['day']);
          _originalDays[d['day']] = d['id'];
        }
      }

      setState(() {
        _tripDetails = details;
        _isLoading = false;
      });
    }
  }

  String _formatDayDate(int dayIndex, String? startDateStr) {
    if (startDateStr == null || startDateStr.isEmpty) {
      return 'Ngày ${dayIndex + 1}';
    }
    final startDate = DateTime.tryParse(startDateStr);
    if (startDate == null) return 'Ngày ${dayIndex + 1}';
    
    final date = startDate.add(Duration(days: dayIndex));
    return DateFormat('EEEE, d MMMM', 'en_US').format(date);
  }

  void _toggleSectionLocal(String sectionName) {
    setState(() {
      if (_localSelectedSections.contains(sectionName)) {
        _localSelectedSections.remove(sectionName);
      } else {
        _localSelectedSections.add(sectionName);
      }
    });
  }

  void _toggleDayLocal(int dayNum) {
    setState(() {
      if (_localSelectedDays.contains(dayNum)) {
        _localSelectedDays.remove(dayNum);
      } else {
        _localSelectedDays.add(dayNum);
      }
    });
  }

  Future<void> _saveAllChanges() async {
    setState(() => _isLoading = true);
    final targetPlaceId = widget.place['id'] ?? widget.place['placeId'];
    final savedPlaces = _tripDetails?['savedPlaces'] as List? ?? [];
    final detailsList = _tripDetails?['details'] as List? ?? [];

    final originalSecNames = _originalSections.keys.toSet();
    final sectionsToAdd = _localSelectedSections.difference(originalSecNames);
    final sectionsToRemove = originalSecNames.difference(_localSelectedSections);

    final originalDayNums = _originalDays.keys.toSet();
    final daysToAdd = _localSelectedDays.difference(originalDayNums);
    final daysToRemove = originalDayNums.difference(_localSelectedDays);

    for (var sec in sectionsToRemove) {
      final savedId = _originalSections[sec];
      if (savedId != null) {
        await DatabaseService().deletePlaceFromSaved(savedId);
      }
    }
    for (var sec in sectionsToAdd) {
      int maxOrder = 0;
      final sectionDetails = savedPlaces.where((d) => d['section'] == sec).toList();
      for (var d in sectionDetails) {
        final ord = d['sortOrder'] ?? 0;
        if (ord > maxOrder) maxOrder = ord;
      }
      await DatabaseService().addPlaceToSaved(
        itineraryId: _selectedItinerary!['id'],
        placeId: targetPlaceId,
        section: sec,
        sortOrder: maxOrder + 1,
      );
    }

    for (var day in daysToRemove) {
      final detailId = _originalDays[day];
      if (detailId != null) {
        await DatabaseService().deletePlaceFromItinerary(detailId);
      }
    }
    for (var day in daysToAdd) {
      int maxOrder = 0;
      final dayDetails = detailsList.where((d) => d['day'] == day).toList();
      for (var d in dayDetails) {
        final ord = d['sortOrder'] ?? 0;
        if (ord > maxOrder) maxOrder = ord;
      }
      await DatabaseService().addPlaceToItinerary(
        itineraryId: _selectedItinerary!['id'],
        day: day,
        placeId: targetPlaceId,
        sortOrder: maxOrder + 1,
      );
    }

    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật chuyến đi thành công!')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_step == 1) {
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Thêm vào kế hoạch chuyến đi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _itineraries.length,
                itemBuilder: (context, index) {
                  final itin = _itineraries[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    title: Text(
                      itin['name'] ?? 'Chuyến đi chưa đặt tên',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.bodyText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => _selectItinerary(itin),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // Step 2: Select Section or Day
    final savedPlaces = _tripDetails?['savedPlaces'] as List? ?? [];
    final sections = savedPlaces
        .map((d) => d['section'] as String?)
        .where((s) => s != null && s.isNotEmpty)
        .toSet()
        .toList();
        
    final numDays = (_tripDetails?['days'] as num?)?.toInt() ?? 1;
    final startDateStr = _tripDetails?['startDate'] as String?;
    final targetPlaceId = widget.place['id'] ?? widget.place['placeId'];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _step = 1;
                      _selectedItinerary = null;
                      _tripDetails = null;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'Đã thêm vào chuyến đi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _saveAllChanges,
                  child: const Text('Lưu', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (sections.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 8, bottom: 8),
                    child: Text('Tổng quan', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.subtitleText)),
                  ),
                ...sections.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sectionName = entry.value!;
                  final color = _markerColors[index % _markerColors.length];
                  
                  final isChecked = _localSelectedSections.contains(sectionName);
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    leading: Icon(Icons.location_on, color: color),
                    title: Text(
                      sectionName,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.bodyText,
                      ),
                    ),
                    trailing: isChecked ? const Icon(Icons.check, color: AppTheme.darkText) : null,
                    onTap: () => _toggleSectionLocal(sectionName),
                  );
                }),
                
                if (numDays > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 24, top: 16, bottom: 8),
                    child: Text('Hành trình', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.subtitleText)),
                  ),
                ...List.generate(numDays, (i) {
                  final dayNum = i + 1;
                  final dayTitle = _formatDayDate(i, startDateStr);
                  final colorIdx = (sections.length + i) % _markerColors.length;
                  final color = _markerColors[colorIdx];
                  
                  final isChecked = _localSelectedDays.contains(dayNum);
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    leading: Icon(Icons.location_on, color: color),
                    title: Text(
                      dayTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.bodyText,
                      ),
                    ),
                    trailing: isChecked ? const Icon(Icons.check, color: AppTheme.darkText) : null,
                    onTap: () => _toggleDayLocal(dayNum),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
