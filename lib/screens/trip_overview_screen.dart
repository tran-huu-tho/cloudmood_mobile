import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'explore_post_detail_screen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../widgets/section_style_sheet.dart';
import '../widgets/itinerary_style_sheet.dart';
import '../widgets/expandable_opening_hours.dart';
import 'trip_ai_chat_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../widgets/inline_place_details.dart';
import '../widgets/save_to_trip_bottom_sheet.dart';
import '../widgets/place_detail_bottom_sheet.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/explore_post_card.dart';
import 'explore_post_detail_screen.dart';

class TripOverviewScreen extends StatefulWidget {
  final Map<String, dynamic> itinerary;

  const TripOverviewScreen({super.key, required this.itinerary});

  @override
  State<TripOverviewScreen> createState() => _TripOverviewScreenState();
}

class _TripOverviewScreenState extends State<TripOverviewScreen>
    with SingleTickerProviderStateMixin {
  Set<String>? _checkedSections;
  Set<int>? _checkedDays;
  late TabController _tabController;
  late Map<String, dynamic> _itineraryData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allPlaces = [];
  List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _savedPlaces = [];
  List<Map<String, dynamic>> _searchCategories = [];
  String? _activeSearchQuery;
  List<Map<String, dynamic>> _filteredMapPlaces = [];
  List<Map<String, dynamic>> _explorePosts = [];
  bool _isLoadingExplore = false;

  // Pagination for web images
  int _webImagesPage = 1;
  bool _isLoadingMoreWebImages = false;
  List<dynamic> _webImages = [];
  bool _hasMoreWebImages = true;
  String _lastWebQuery = '';

  String _privacySetting = 'friends';

  // Overview Tab section names
  final List<String> _sectionNames = [];
  final Map<String, TextEditingController> _searchControllers = {};
  final Map<String, List<Map<String, dynamic>>> _searchResults = {};

  // For inline section title editing
  String? _editingSection;
  final TextEditingController _sectionTitleController = TextEditingController();
  final FocusNode _sectionTitleFocusNode = FocusNode();

  final Map<String, Color> _sectionColors = {};
  final Map<String, IconData> _sectionIcons = {};
  final Map<String, String> _sectionTypes = {};
  final Map<String, ExpansibleController> _expansionControllers = {};

  bool _isSelectionMode = false;
  final Set<int> _selectedItemIds = {};
  final Set<String> _selectedSections = {};
  int? _focusedPlaceId;
  bool _isSheetHalf = false;
  final List<Color> _availableColors = [
    Colors.green,
    Colors.tealAccent,
    Colors.lightBlue,
    Colors.blue,
    Colors.deepPurple,
    Colors.pinkAccent,
    Colors.orange,
    Colors.orangeAccent,
    const Color(0xFF2E7D32),
    const Color(0xFF00695C),
    const Color(0xFF1565C0),
    const Color(0xFF283593),
    const Color(0xFF6A1B9A),
    const Color(0xFFAD1457),
    Colors.brown,
    const Color(0xFF5D4037),
  ];

  // Expense Tab custom items
  String _formatTimeStr(String t) {
    if (t.contains('T')) {
      try {
        final dt = DateTime.parse(t).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  List<Map<String, dynamic>> _customExpenses = [];

  // Itinerary Tab custom items
  final Map<int, String> _daySubtitles = {};
  final Map<int, Color> _dayColors = {};
  final Map<int, bool> _dayCollapsed = {};
  int _activeDayIndex = 0;
  late final ScrollController _itineraryScrollController = ScrollController();
  final Map<int, GlobalKey> _dayKeys = {};

  // Map state
  bool _isMapExpanded = false;
  LatLng? _mapCenter;
  bool _isDragging = false;
  double? _dragHeight;
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  Map<String, dynamic>? _selectedMapPlace;

  // AI Dialog state
  final bool _isGeneratingAI = false;
  OverlayEntry? _currentNotification;
  int? _editingNoteId;
  String? _focusedTodoItemKey;
  final Set<int> _expandedPlaceIds = {};

  @override
  void initState() {
    super.initState();
    _itineraryData = widget.itinerary;
    _privacySetting = 'friends';
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('privacy_${_itineraryData['id']}');
      if (saved != null && mounted) {
        setState(() => _privacySetting = saved);
      }
    });
    final int numDays = (_itineraryData['days'] as int?) ?? 1;
    _checkedDays = Set.from(Iterable.generate(numDays, (i) => i + 1));
    final bool isGuide = _itineraryData['isGuide'] == true;
    _tabController = TabController(length: isGuide ? 2 : 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _currentNotification?.remove();
    _currentNotification = null;
    _tabController.dispose();
    _itineraryScrollController.dispose();
    for (var controller in _searchControllers.values) {
      controller.dispose();
    }
    _sectionTitleController.dispose();
    _sectionTitleFocusNode.dispose();
    super.dispose();
  }

  void _saveSectionTitle(String oldTitle, String newTitle) {
    if (newTitle.trim().isEmpty || newTitle == oldTitle) {
      setState(() {
        _editingSection = null;
      });
      return;
    }

    String finalTitle = newTitle.trim();
    int counter = 1;
    while (_sectionNames.any(
      (sec) => sec.toLowerCase() == finalTitle.toLowerCase() && sec != oldTitle,
    )) {
      finalTitle = '${newTitle.trim()} $counter';
      counter++;
    }
    newTitle = finalTitle;

    setState(() {
      final index = _sectionNames.indexOf(oldTitle);
      if (index != -1) {
        _sectionNames[index] = newTitle;
        if (_searchControllers.containsKey(oldTitle)) {
          _searchControllers[newTitle] = _searchControllers.remove(oldTitle)!;
        }
        if (_searchResults.containsKey(oldTitle)) {
          _searchResults[newTitle] = _searchResults.remove(oldTitle)!;
        }
        for (var d in _savedPlaces) {
          if (d['section'] == oldTitle) {
            d['section'] = newTitle;
            if (d['id'] != null) {
              DatabaseService().updateSavedPlace(d['id'] as int, {
                'section': newTitle,
              });
            }
          }
        }
        if (_sectionColors.containsKey(oldTitle)) {
          _sectionColors[newTitle] = _sectionColors.remove(oldTitle)!;
        }
        if (_sectionIcons.containsKey(oldTitle)) {
          _sectionIcons[newTitle] = _sectionIcons.remove(oldTitle)!;
        }
      }
      _editingSection = null;
    });

    // Sync the rename to database (delete old, insert new)
    DatabaseService().deleteItinerarySection(
      _itineraryData['id'] as int,
      oldTitle,
    );
    _syncSectionsToDatabase();
  }

  void _showSectionStyleSheet(
    BuildContext context,
    String sectionName, {
    int initialTabIndex = 0,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SectionStyleSheet(
        initialSection: sectionName,
        sections: _sectionNames,
        savedPlaces: _savedPlaces,
        sectionColors: _sectionColors,
        sectionIcons: _sectionIcons,
        initialTabIndex: initialTabIndex,
        onSaved: (newSections, newPlaces, newColors, newIcons) {
          setState(() {
            _sectionNames.clear();
            _sectionNames.addAll(newSections);
            _savedPlaces = newPlaces;
            _sectionColors.clear();
            _sectionColors.addAll(newColors);
            if (newIcons != null) {
              _sectionIcons.clear();
              _sectionIcons.addAll(newIcons);
            }
          });
          _syncSectionsToDatabase();
        },
      ),
    );
  }

  void _showItineraryStyleSheet(
    BuildContext context, {
    int initialTabIndex = 0,
    int initialDayIndex = 0,
  }) {
    final int totalDays = (_itineraryData['days'] as num?)?.toInt() ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryStyleSheet(
        daysCount: totalDays,
        details: _details,
        dayColors: _dayColors,
        initialTabIndex: initialTabIndex,
        initialDayIndex: initialDayIndex,
        onSaved: (newDetails, newColors) async {
          setState(() {
            _dayColors.clear();
            _dayColors.addAll(newColors);
            _details = newDetails;
          });

          await _saveDayColors();

          for (var p in _details) {
            await DatabaseService().updateItineraryDetail(p['id'] as int, {
              'day': p['day'],
              'sortOrder': p['sortOrder'],
            });
          }

          await _loadData(silent: true);
        },
      ),
    );
  }

  void _showPremiumNotification({
    required String message,
    required IconData icon,
    required Color color,
    String? title,
  }) {
    if (!mounted) return;

    // Clear existing notification
    _currentNotification?.remove();
    _currentNotification = null;

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, val, child) {
                return Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -20 * (1.0 - val)),
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (title != null)
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.darkText,
                                fontSize: 13,
                              ),
                            ),
                          Text(
                            message,
                            style: TextStyle(
                              color: title != null
                                  ? AppTheme.subtitleText
                                  : AppTheme.darkText,
                              fontSize: 12,
                              fontWeight: title != null
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _currentNotification?.remove();
                        _currentNotification = null;
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: AppTheme.subtitleText,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentNotification = entry;
    overlay.insert(entry);

    // Auto-remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted && _currentNotification == entry) {
        entry.remove();
        if (_currentNotification == entry) {
          _currentNotification = null;
        }
      }
    });
  }

  Future<void> _fetchMapData() async {
    final String dest = _itineraryData['destination'] ?? '';
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(dest)}&format=json&limit=1',
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'CloudMoodApp/1.0'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty) {
          final double lat = double.parse(data[0]['lat'].toString());
          final double lon = double.parse(data[0]['lon'].toString());
          if (mounted) {
            setState(() {
              _mapCenter = LatLng(lat, lon);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching map: $e');
    }
  }

  Future<void> _fetchExplorePosts() async {
    setState(() => _isLoadingExplore = true);
    final String dest = _itineraryData['destination'] ?? '';
    try {
      final response = await http.get(
        Uri.parse(
          'http://localhost:3000/explore?destination=${Uri.encodeComponent(dest)}',
        ),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _explorePosts = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching explore posts: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingExplore = false);
      }
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }

    // Fetch map data in background
    if (_mapCenter == null) {
      _fetchMapData();
    }
    _fetchExplorePosts();
    final itineraryId = _itineraryData['id'] as int;

    // Fetch refreshed itinerary details
    final refreshed = await DatabaseService().fetchItineraryById(itineraryId);
    if (refreshed != null) {
      _itineraryData = refreshed;
      final rawDetails = List<Map<String, dynamic>>.from(
        refreshed['details'] ?? [],
      );
      rawDetails.sort((a, b) {
        final int orderA = a['sortOrder'] ?? 0;
        final int orderB = b['sortOrder'] ?? 0;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        final int idA = a['id'] ?? 0;
        final int idB = b['id'] ?? 0;
        return idA.compareTo(idB);
      });
      _details = rawDetails;

      final rawSaved = List<Map<String, dynamic>>.from(
        refreshed['savedPlaces'] ?? [],
      );
      rawSaved.sort((a, b) {
        final int orderA = a['sortOrder'] ?? 0;
        final int orderB = b['sortOrder'] ?? 0;
        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }
        final int idA = a['id'] ?? 0;
        final int idB = b['id'] ?? 0;
        return idA.compareTo(idB);
      });
      _savedPlaces = rawSaved;
    }

    // Fetch places near destination for Explore and recommendations (only if not loaded)
    if (_allPlaces.isEmpty) {
      final String dest = _itineraryData['destination'] ?? '';
      final places = await DatabaseService().fetchPlacesByDestination(dest);
      _allPlaces = places;
    }

    // Restore custom section names, colors, and icons from Database
    final savedSections = _itineraryData['sections'] as List<dynamic>?;
    _sectionNames.clear();
    if (savedSections != null && savedSections.isNotEmpty) {
      // Sort by sortOrder
      savedSections.sort(
        (a, b) => (a['sortOrder'] as int? ?? 0).compareTo(
          b['sortOrder'] as int? ?? 0,
        ),
      );
      for (var sec in savedSections) {
        final name = sec['name'] as String;
        if (!_sectionNames.contains(name)) {
          _sectionNames.add(name);
          _searchControllers.putIfAbsent(name, () => TextEditingController());
          _searchResults.putIfAbsent(name, () => []);
        }
        _sectionColors[name] = Color(int.parse(sec['colorCode'] as String));
        final int rawCode = sec['iconCode'] as int;
        _sectionIcons[name] = rawCode == 983363
            ? Icons.looks_one_rounded
            : IconData(rawCode, fontFamily: 'MaterialIcons');
        _sectionTypes[name] = sec['sectionType'] as String? ?? 'LIST';
      }
    }

    // Ensure any section that has saved places is in _sectionNames (excluding day-based sections)
    for (var place in _savedPlaces) {
      final section = place['section'] as String?;
      if (section != null &&
          !_sectionNames.contains(section) &&
          !(section.startsWith('Ngày') && _itineraryData['isGuide'] != true)) {
        _sectionNames.add(section);
        _searchControllers.putIfAbsent(section, () => TextEditingController());
        _searchResults.putIfAbsent(section, () => []);
        _sectionColors.putIfAbsent(
          section,
          () =>
              _availableColors[_sectionNames.length % _availableColors.length],
        );
        _sectionIcons.putIfAbsent(section, () => Icons.folder_rounded);
        _sectionTypes.putIfAbsent(section, () => 'LIST');
      }
    }

    _checkedSections ??= Set.from(_sectionNames);

    // Restore custom expenses
    final prefs = await SharedPreferences.getInstance();
    final savedExpenses = prefs.getString('expenses_$itineraryId');
    if (savedExpenses != null) {
      try {
        _customExpenses = List<Map<String, dynamic>>.from(
          json.decode(savedExpenses),
        );
      } catch (e) {
        debugPrint('Error loading expenses: $e');
      }
    }

    final daySubtitlesStr = prefs.getString('day_subtitles_$itineraryId');
    _daySubtitles.clear();
    if (daySubtitlesStr != null) {
      try {
        final Map<String, dynamic> parsed = json.decode(daySubtitlesStr);
        parsed.forEach((k, v) {
          _daySubtitles[int.parse(k)] = v as String;
        });
      } catch (e) {
        debugPrint('Error loading day subtitles: $e');
      }
    }

    final dayConfigs = _itineraryData['dayConfigs'] as Map<String, dynamic>?;
    _dayColors.clear();
    if (dayConfigs != null) {
      try {
        dayConfigs.forEach((k, v) {
          if (v is Map && v['color'] != null) {
            _dayColors[int.parse(k)] = Color(int.parse(v['color'].toString()));
          }
        });
      } catch (e) {
        debugPrint('Error loading day colors from dayConfigs: $e');
      }
    }

    if (_searchCategories.isEmpty) {
      final categories = await DatabaseService().getCategories();
      if (mounted) {
        setState(() {
          _searchCategories = categories;
        });
      }
    }

    if (mounted) {
      setState(() {
        if (!silent) {
          _isLoading = false;
        }
      });
    }
  }

  Future<void> _saveDaySubtitles() async {
    final prefs = await SharedPreferences.getInstance();
    final itineraryId = _itineraryData['id'] as int;
    final Map<String, String> dataToSave = {};
    _daySubtitles.forEach((k, v) {
      dataToSave[k.toString()] = v;
    });
    await prefs.setString(
      'day_subtitles_$itineraryId',
      json.encode(dataToSave),
    );
  }

  Future<void> _saveDayColors() async {
    final itineraryId = _itineraryData['id'] as int;
    final Map<String, dynamic> dataToSave = {};
    _dayColors.forEach((k, v) {
      dataToSave[k.toString()] = {'color': v.toARGB32().toString()};
    });

    // Call database to save
    await DatabaseService().updateItineraryDayConfigs(itineraryId, dataToSave);
  }

  String _getDayLabel(int dayIndex) {
    final startStr = _itineraryData['startDate'] as String?;
    if (startStr == null) {
      return 'Ngày ${dayIndex + 1}';
    }
    final startDate = DateTime.tryParse(startStr);
    if (startDate == null) {
      return 'Ngày ${dayIndex + 1}';
    }
    final date = startDate.add(Duration(days: dayIndex));
    final weekday = date.weekday;
    String weekdayStr = '';
    switch (weekday) {
      case DateTime.monday:
        weekdayStr = 'T2';
        break;
      case DateTime.tuesday:
        weekdayStr = 'T3';
        break;
      case DateTime.wednesday:
        weekdayStr = 'T4';
        break;
      case DateTime.thursday:
        weekdayStr = 'T5';
        break;
      case DateTime.friday:
        weekdayStr = 'T6';
        break;
      case DateTime.saturday:
        weekdayStr = 'T7';
        break;
      case DateTime.sunday:
        weekdayStr = 'CN';
        break;
    }
    return '$weekdayStr ${date.day}/${date.month}';
  }

  Future<void> _insertDayAfter(int dayIndex) async {
    final itineraryId = _itineraryData['id'] as int;
    final int targetDay = dayIndex + 1; // Insert after this day

    // Shift days in DB
    await DatabaseService().shiftItineraryDetailsDays(
      itineraryId: itineraryId,
      targetDay: targetDay,
      offset: 1,
    );

    // Update itinerary total days
    final currentDays = (_itineraryData['days'] as num?)?.toInt() ?? 1;
    await DatabaseService().updateItinerary(itineraryId, {
      'days': currentDays + 1,
    });
    await _loadData();
  }

  Future<void> _deleteDay(int dayIndex) async {
    final itineraryId = _itineraryData['id'] as int;
    final int targetDay = dayIndex + 1;

    // Delete details belonging to targetDay
    await DatabaseService().deleteItineraryDetailsForDay(
      itineraryId: itineraryId,
      day: targetDay,
    );

    // Shift day numbers down for details after targetDay
    await DatabaseService().shiftItineraryDetailsDays(
      itineraryId: itineraryId,
      targetDay: targetDay,
      offset: -1,
    );

    // Update itinerary total days
    final currentDays = (_itineraryData['days'] as num?)?.toInt() ?? 1;
    if (currentDays > 1) {
      await DatabaseService().updateItinerary(itineraryId, {
        'days': currentDays - 1,
      });
    }
    await _loadData();
  }

  Future<void> _changeTripStartDate() async {
    final currentStartStr = _itineraryData['startDate'] as String?;
    final currentDays = (_itineraryData['days'] as num?)?.toInt() ?? 1;
    final currentStart = currentStartStr != null
        ? DateTime.tryParse(currentStartStr)
        : DateTime.now();
    final currentEnd = currentStart?.add(
      Duration(days: currentDays > 0 ? currentDays - 1 : 0),
    );

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: currentStart != null && currentEnd != null
          ? DateTimeRange(start: currentStart, end: currentEnd)
          : null,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final itId = _itineraryData['id'] as int;
      final newDays = picked.end.difference(picked.start).inDays + 1;

      await DatabaseService().updateItinerary(itId, {
        'startDate': picked.start.toIso8601String().substring(0, 10),
        'days': newDays,
      });
      await _loadData();
    }
  }

  void _showDayOptionsSheet(int dayIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: AppTheme.darkText),
                  title: const Text('Chỉnh sửa tiêu đề phụ'),
                  onTap: () {
                    Navigator.pop(context);
                    _editDaySubtitle(dayIndex);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.palette_outlined,
                    color: AppTheme.darkText,
                  ),
                  title: const Text('Thay đổi màu sắc'),
                  onTap: () {
                    Navigator.pop(context);
                    _showItineraryStyleSheet(
                      context,
                      initialTabIndex: 0,
                      initialDayIndex: dayIndex,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.unfold_less_rounded,
                    color: AppTheme.darkText,
                  ),
                  title: const Text('Thu gọn tất cả các ngày'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      final int totalDays =
                          (_itineraryData['days'] as num?)?.toInt() ?? 1;
                      for (int i = 0; i < totalDays; i++) {
                        _dayCollapsed[i] = true;
                      }
                    });
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.playlist_add_rounded,
                    color: AppTheme.darkText,
                  ),
                  title: const Text('Chèn ngày sau'),
                  onTap: () {
                    Navigator.pop(context);
                    _insertDayAfter(dayIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  title: const Text(
                    'Xóa ngày',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteDay(dayIndex);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.menu_book_rounded,
                    color: AppTheme.darkText,
                  ),
                  title: const Text('Thêm địa điểm vào nhật ký'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPremiumNotification(
                      title: 'Tính năng nâng cao',
                      message:
                          'Tính năng liên kết Nhật ký hành trình sẽ sớm khả dụng!',
                      icon: Icons.info_outline_rounded,
                      color: AppTheme.primary,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.calendar_month_outlined,
                    color: AppTheme.darkText,
                  ),
                  title: const Text('Thay đổi ngày chuyến đi'),
                  onTap: () {
                    Navigator.pop(context);
                    _changeTripStartDate();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.sort_rounded, color: AppTheme.darkText),
                  title: const Text('Sắp xếp lại các phần'),
                  onTap: () {
                    Navigator.pop(context);
                    _showItineraryStyleSheet(context, initialTabIndex: 1);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editDaySubtitle(int dayIndex) {
    final controller = TextEditingController(
      text: _daySubtitles[dayIndex] ?? '',
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Nhập tiêu đề phụ cho ${_getDayLabel(dayIndex)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            decoration: AppTheme.inputDecoration(
              hintText: 'Ví dụ: Tham quan bảo tàng, Nghỉ dưỡng...',
              prefixIcon: Icons.edit_rounded,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final txt = controller.text.trim();
                setState(() {
                  _daySubtitles[dayIndex] = txt;
                });
                _saveDaySubtitles();
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _changeDayColor(int dayIndex) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Chọn màu sắc ngày',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _availableColors.map((color) {
                final isSelected = _dayColors[dayIndex] == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _dayColors[dayIndex] = color;
                    });
                    _saveDayColors();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : Border.all(color: Colors.grey[300]!, width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _syncSectionsToDatabase() async {
    final itineraryId = _itineraryData['id'] as int;
    for (int i = 0; i < _sectionNames.length; i++) {
      final name = _sectionNames[i];
      final color =
          _sectionColors[name]?.toARGB32() ?? AppTheme.primary.toARGB32();
      final icon =
          _sectionIcons[name]?.codePoint ?? Icons.looks_one_rounded.codePoint;
      await DatabaseService().upsertItinerarySection(
        itineraryId: itineraryId,
        name: name,
        colorCode: color.toString(),
        iconCode: icon,
        sortOrder: i,
        sectionType: _sectionTypes[name] ?? 'LIST',
      );
    }
  }

  Future<void> _saveExpensesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final itineraryId = _itineraryData['id'] as int;
    await prefs.setString(
      'expenses_$itineraryId',
      json.encode(_customExpenses),
    );
  }

  // Add place to a section/day
  Future<void> _addPlace(
    Map<String, dynamic> place,
    String sectionOrDay,
  ) async {
    final itineraryId = _itineraryData['id'] as int;
    final placeId = place['id'] as int;
    dynamic result;

    if (sectionOrDay.startsWith('Ngày') && _itineraryData['isGuide'] != true) {
      final int day =
          int.tryParse(sectionOrDay.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      result = await DatabaseService().addPlaceToItinerary(
        itineraryId: itineraryId,
        placeId: placeId,
        day: day,
      );
    } else {
      result = await DatabaseService().addPlaceToSaved(
        itineraryId: itineraryId,
        placeId: placeId,
        section: sectionOrDay,
      );
    }

    if (result != null) {
      _showPremiumNotification(
        title: 'Thêm thành công',
        message: 'Đã thêm "${place['name']}" vào $sectionOrDay!',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.green,
      );
      await _loadData(silent: true);
    } else {
      await _loadData();
    }
  }

  // Delete place
  Future<void> _removePlaceDetail(
    int detailId,
    String placeName, {
    bool isSavedPlace = false,
  }) async {
    final success = isSavedPlace
        ? await DatabaseService().deletePlaceFromSaved(detailId)
        : await DatabaseService().deletePlaceFromItinerary(detailId);
    if (success) {
      _showPremiumNotification(
        title: 'Đã xóa',
        message: 'Đã xóa "$placeName" khỏi lịch trình.',
        icon: Icons.delete_sweep_outlined,
        color: Colors.redAccent,
      );
      await _loadData(silent: true);
    } else {
      await _loadData();
    }
  }

  // Local place search within destination
  void _onSearchChanged(String query, String sectionName) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults[sectionName] = [];
      });
      return;
    }

    final filtered = _allPlaces.where((place) {
      final name = (place['name'] as String).toLowerCase();
      final addr = (place['address'] as String).toLowerCase();
      final q = query.toLowerCase();
      return name.contains(q) || addr.contains(q);
    }).toList();

    setState(() {
      _searchResults[sectionName] = filtered;
    });
  }

  // Dialog to prompt user where to add a place
  void _showAddPlaceDialog(Map<String, dynamic> place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Thêm "${place['name']}" vào chuyến đi',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'DANH SÁCH TỔNG QUAN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.subtitleText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                ..._sectionNames.map((sec) {
                  return ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: AppTheme.primary,
                    ),
                    title: Text(sec),
                    onTap: () {
                      Navigator.pop(context);
                      _addPlace(place, sec);
                    },
                  );
                }),
                const Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'HÀNH TRÌNH THEO NGÀY',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.subtitleText,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: (_itineraryData['days'] as num?)?.toInt() ?? 1,
                    itemBuilder: (context, idx) {
                      final dayLabel = 'Ngày ${idx + 1}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPeach,
                            foregroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _addPlace(place, dayLabel);
                          },
                          child: Text(
                            dayLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // Create new section
  void _deleteSelectedItems() async {
    if (_selectedItemIds.isEmpty) return;

    final idsToDelete = _selectedItemIds.toList();
    final success = await DatabaseService().deleteMultipleSavedPlaces(
      idsToDelete,
    );
    if (success) {
      setState(() {
        _isSelectionMode = false;
        _selectedItemIds.clear();
        _selectedSections.clear();
      });
      _loadData(silent: true);
    }
  }

  void _showSelectSectionBottomSheet({required bool isCopy}) {
    if (_selectedItemIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isCopy ? 'Sao chép đến...' : 'Di chuyển đến...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ..._sectionNames.map((section) {
                return ListTile(
                  leading: Icon(
                    _sectionIcons[section] ?? Icons.looks_one_rounded,
                    color: _sectionColors[section] ?? AppTheme.primary,
                  ),
                  title: Text(section),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ids = _selectedItemIds.toList();
                    bool success = false;
                    if (isCopy) {
                      success = await DatabaseService().copySavedPlaces(
                        ids,
                        section,
                      );
                    } else {
                      success = await DatabaseService().moveSavedPlaces(
                        ids,
                        section,
                      );
                    }
                    if (success) {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedItemIds.clear();
                        _selectedSections.clear();
                      });
                      _loadData(silent: true);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _createNewSection() {
    int counter = 1;
    String baseName = 'Danh sách mới';
    String newName = baseName;

    while (_sectionNames.any(
      (sec) => sec.toLowerCase() == newName.toLowerCase(),
    )) {
      counter++;
      newName = '$baseName $counter';
    }

    setState(() {
      _sectionNames.add(newName);
      _searchControllers[newName] = TextEditingController();
      _searchResults[newName] = [];

      final usedColors = _sectionColors.values.toSet();
      Color? newColor;
      for (var c in _availableColors) {
        if (!usedColors.contains(c)) {
          newColor = c;
          break;
        }
      }
      if (newColor == null) {
        final idx = _sectionNames.length % _availableColors.length;
        newColor = _availableColors[idx];
      }
      _sectionColors[newName] = newColor;
      _sectionIcons[newName] = Icons.looks_one_rounded;
      _sectionTypes[newName] = 'LIST';

      _editingSection = newName;
      _sectionTitleController.text = newName;
    });

    _syncSectionsToDatabase();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _sectionTitleFocusNode.requestFocus();
      }
    });
  }

  // Custom Expense Adder Dialog
  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Thêm chi tiêu mới',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: AppTheme.inputDecoration(
                  hintText: 'Tên khoản chi (vd: Vé máy bay)',
                  prefixIcon: Icons.shopping_bag_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: AppTheme.inputDecoration(
                  hintText: 'Số tiền (VNĐ)',
                  prefixIcon: Icons.attach_money_rounded,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final title = titleController.text.trim();
                final amt = int.tryParse(amountController.text.trim()) ?? 0;
                if (title.isNotEmpty && amt > 0) {
                  setState(() {
                    _customExpenses.add({
                      'title': title,
                      'amount': amt,
                      'date': DateTime.now().toIso8601String().substring(0, 10),
                    });
                  });
                  _saveExpensesToPrefs();
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Thêm',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // AI Itinerary Planner Generator simulating API
  void _runAIPlanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripAIChatScreen(
          destination: _itineraryData['destination'] ?? 'Điểm đến',
        ),
      ),
    );
  }

  void _focusPlaceOnMap(int? id) {
    if (id == null) return;

    // Find the place in the trip lists
    final detail = _savedPlaces.firstWhere(
      (p) => p['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (detail.isEmpty) return;

    final place = detail['place'] as Map<String, dynamic>?;
    if (place != null &&
        place['latitude'] != null &&
        place['longitude'] != null) {
      final lat = (place['latitude'] as num).toDouble();
      final lon = (place['longitude'] as num).toDouble();
      // Offset latitude by -0.005 so marker is in the upper visible half
      _mapController.move(LatLng(lat - 0.005, lon), 15.0);
    }
  }

  void _showMapOverview() {
    setState(() {
      _isMapExpanded = true;
      _isSheetHalf = true;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusPlaceOnMap(_focusedPlaceId);
    });
  }

  void _showShareDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const Text(
                'Mời bạn đồng hành',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Có thể chỉnh sửa',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Chỉ xem',
                        style: TextStyle(color: AppTheme.subtitleText),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Mời qua email',
                  prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareIconOption(
                    Icons.link_rounded,
                    'Sao chép\nliên kết',
                  ),
                  _buildShareIconOption(Icons.ios_share_rounded, 'Khác'),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.manage_accounts_rounded),
                title: const Text(
                  'Quản lý bạn đồng hành',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ), // Close SingleChildScrollView
    );
  }

  Widget _buildShareIconOption(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, color: AppTheme.darkText, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
        ),
      ],
    );
  }

  void _showMapSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Cài đặt chuyến đi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  Icons.reply_rounded,
                  'Chia sẻ',
                  onTap: _showShareDialog,
                ),
                _buildSettingTile(
                  Icons.edit_rounded,
                  'Chỉnh sửa tiêu đề',
                  onTap: _showEditTitleDialog,
                ),
                _buildSettingTile(
                  Icons.image_rounded,
                  'Thay đổi ảnh bìa',
                  onTap: _showChangeImageSheet,
                ),
                _buildSettingTile(
                  Icons.lock_rounded,
                  'Cài đặt quyền riêng tư',
                  onTap: _showPrivacySettingsSheet,
                ),
                _buildSettingTile(
                  Icons.attach_money_rounded,
                  'Cài đặt chi phí',
                ),
                _buildSettingTile(
                  Icons.directions_car_rounded,
                  'Chế độ vận chuyển mặc định',
                ),
                _buildSettingTile(
                  Icons.lightbulb_outline_rounded,
                  'Mẹo du lịch chuyên gia',
                ),
                _buildSettingTile(
                  Icons.info_outline_rounded,
                  'Trợ giúp & cách thực hiện',
                ),
                _buildSettingTile(
                  Icons.help_outline_rounded,
                  'Phản hồi & hỗ trợ',
                ),
                _buildSettingTile(
                  Icons.format_list_bulleted_rounded,
                  'Hiển thị tiến trình các nhiệm vụ quan trọng',
                ),
                _buildSettingTile(
                  Icons.delete_outline_rounded,
                  'Xóa chuyến đi này',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.darkText),
      title: Text(title, style: TextStyle(color: AppTheme.darkText)),
      onTap: () {
        Navigator.pop(context);
        if (onTap != null) {
          onTap();
        }
      },
    );
  }

  void _showPrivacySettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              Widget buildPrivacyOption(
                String title,
                String subtitle,
                IconData icon,
                String value,
              ) {
                return ListTile(
                  leading: Icon(icon, color: AppTheme.darkText),
                  title: Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.subtitleText,
                      fontSize: 12,
                    ),
                  ),
                  trailing: _privacySetting == value
                      ? Icon(Icons.check, color: AppTheme.darkText)
                      : null,
                  onTap: () async {
                    setSheetState(() => _privacySetting = value);
                    setState(() => _privacySetting = value);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'privacy_${_itineraryData['id']}',
                      value,
                    );
                    Navigator.pop(context);
                  },
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: AppTheme.darkText),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Cài đặt quyền riêng tư',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildPrivacyOption(
                    'Công khai',
                    'Bất kỳ ai cũng có thể xem',
                    Icons.public,
                    'public',
                  ),
                  buildPrivacyOption(
                    'Bạn bè',
                    'Chỉ những người theo dõi chung của bạn mới có thể xem',
                    Icons.group,
                    'friends',
                  ),
                  buildPrivacyOption(
                    'Riêng tư',
                    'Chỉ bạn và những người có liên kết mới có thể xem',
                    Icons.lock,
                    'private',
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        );
      },
    );
  }

  IconData _getPrivacyIcon() {
    switch (_privacySetting) {
      case 'public':
        return Icons.public;
      case 'private':
        return Icons.lock;
      case 'friends':
      default:
        return Icons.group;
    }
  }

  void _showEditTitleDialog() {
    final TextEditingController titleController = TextEditingController(
      text: _itineraryData['title'] as String? ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Chỉnh sửa tiêu đề',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              hintText: 'Nhập tiêu đề mới',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Hủy',
                style: TextStyle(color: AppTheme.subtitleText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final newTitle = titleController.text.trim();
                if (newTitle.isNotEmpty &&
                    newTitle != _itineraryData['title']) {
                  setState(() {
                    _itineraryData['title'] = newTitle;
                  });
                  final itineraryId = _itineraryData['id'] as int?;
                  if (itineraryId != null) {
                    try {
                      await DatabaseService().updateItinerary(itineraryId, {
                        'title': newTitle,
                      });
                    } catch (e) {
                      debugPrint('Error updating title: $e');
                    }
                  }
                }
                if (mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  void _showSearchOverlay() {
    List<Map<String, dynamic>> overlaySearchResults = [];
    bool isSearching = false;
    String currentQuery = '';
    Timer? debounce;
    final dest = _itineraryData['destination'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setStateOverlay) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.9,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) {
                            setStateOverlay(() {
                              currentQuery = val;
                            });
                            if (debounce?.isActive ?? false) debounce!.cancel();
                            debounce = Timer(
                              const Duration(milliseconds: 500),
                              () async {
                                if (val.isEmpty) {
                                  setStateOverlay(() {
                                    overlaySearchResults = [];
                                    isSearching = false;
                                  });
                                  return;
                                }
                                setStateOverlay(() {
                                  isSearching = true;
                                });
                                final results = await DatabaseService()
                                    .searchPlaces(
                                      destination: dest,
                                      query: val,
                                    );
                                setStateOverlay(() {
                                  overlaySearchResults = results;
                                  isSearching = false;
                                });
                              },
                            );
                          },
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm theo tên hoặc địa chỉ',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (currentQuery.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: overlaySearchResults.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              leading: const Icon(Icons.search_rounded),
                              title: Text(
                                'Tìm kiếm: $currentQuery',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text('Xem kết quả trên bản đồ'),
                              onTap: () async {
                                final query = currentQuery;
                                Navigator.pop(context);
                                setState(() {
                                  _activeSearchQuery = query;
                                  _isMapExpanded = true;
                                  _isSheetHalf = false;
                                });

                                final results = await DatabaseService()
                                    .searchPlaces(
                                      destination: dest,
                                      query: query,
                                    );

                                setState(() {
                                  _filteredMapPlaces = results;
                                  if (results.isNotEmpty) {
                                    final lat =
                                        (results.first['latitude'] as num)
                                            .toDouble();
                                    final lon =
                                        (results.first['longitude'] as num)
                                            .toDouble();
                                    _mapController.move(LatLng(lat, lon), 13.0);
                                    _selectedMapPlace = results.first;
                                  }
                                });
                              },
                            );
                          }

                          final place = overlaySearchResults[index - 1];
                          return ListTile(
                            leading: const Icon(Icons.place_rounded),
                            title: Text(place['name'] ?? ''),
                            subtitle: Text(
                              place['address'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setState(() {
                                _activeSearchQuery = place['name'];
                                _filteredMapPlaces = [place];
                                _isMapExpanded = true;
                                _isSheetHalf = false;
                                if (place['latitude'] != null &&
                                    place['longitude'] != null) {
                                  _mapController.move(
                                    LatLng(
                                      (place['latitude'] as num).toDouble(),
                                      (place['longitude'] as num).toDouble(),
                                    ),
                                    15.0,
                                  );
                                }
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    )
                  else ...[
                    const Text(
                      'Tìm kiếm thường xuyên',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_searchCategories.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: _searchCategories.length,
                          itemBuilder: (context, index) {
                            final category = _searchCategories[index];
                            final iconCode = category['iconCode'] as int?;
                            IconData iconData = Icons.category_rounded;

                            if (iconCode != null) {
                              iconData = IconData(
                                iconCode,
                                fontFamily: 'MaterialIcons',
                              );
                            } else {
                              final iconString = category['icon'] as String?;
                              if (iconString != null && iconString.isNotEmpty) {
                                try {
                                  if (iconString.startsWith('0x')) {
                                    iconData = IconData(
                                      int.parse(iconString),
                                      fontFamily: 'MaterialIcons',
                                    );
                                  }
                                } catch (_) {}
                              }
                            }

                            return _buildSearchCategory(
                              iconData,
                              category['name'] ?? '',
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchCategory(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () async {
        Navigator.pop(context);
        setState(() {
          _activeSearchQuery = title;
          _isMapExpanded = true;
          _isSheetHalf = false;
        });

        final dest = _itineraryData['destination'] ?? '';
        final results = await DatabaseService().searchPlaces(
          destination: dest,
          categoryName: title,
        );

        setState(() {
          _filteredMapPlaces = results;
          if (results.isNotEmpty) {
            final lat = (results.first['latitude'] as num).toDouble();
            final lon = (results.first['longitude'] as num).toDouble();
            _mapController.move(LatLng(lat, lon), 13.0);
            _selectedMapPlace = results.first;
          }
        });
      },
    );
  }

  void _showLayersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Khám phá khu vực',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: _searchCategories.isEmpty
                        ? const Center(
                            child: Text(
                              'Không có dữ liệu',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _searchCategories.length,
                            itemBuilder: (context, index) {
                              final cat = _searchCategories[index];
                              return GestureDetector(
                                onTap: () async {
                                  Navigator.pop(context);
                                  setState(() {
                                    _activeSearchQuery = cat['name'];
                                    _isMapExpanded = true;
                                    _isSheetHalf = false;
                                  });
                                  final dest =
                                      _itineraryData['destination'] ?? '';
                                  final results = await DatabaseService()
                                      .searchPlaces(
                                        destination: dest,
                                        categoryName: cat['name'],
                                      );
                                  setState(() {
                                    _filteredMapPlaces = results;
                                    if (results.isNotEmpty) {
                                      final lat =
                                          (results.first['latitude'] as num)
                                              .toDouble();
                                      final lon =
                                          (results.first['longitude'] as num)
                                              .toDouble();
                                      _mapController.move(
                                        LatLng(lat, lon),
                                        13.0,
                                      );
                                      _selectedMapPlace = results.first;
                                    }
                                  });
                                },
                                child: Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.grey.shade100,
                                        child: Icon(
                                          IconData(
                                            cat['iconCode'] ??
                                                Icons.place.codePoint,
                                            fontFamily: 'MaterialIcons',
                                          ),
                                          color: AppTheme.subtitleText,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        cat['name'] ?? '',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.subtitleText,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Địa điểm đã lưu của bạn',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_sectionNames.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tổng quan',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    ..._sectionNames.map((section) {
                      final color = _sectionColors[section] ?? AppTheme.primary;
                      return CheckboxListTile(
                        secondary: Icon(Icons.location_on, color: color),
                        title: Text(
                          section,
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _checkedSections?.contains(section) ?? true,
                        activeColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.trailing,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) {
                          setSheetState(() {
                            if (val == true) {
                              _checkedSections?.add(section);
                            } else {
                              _checkedSections?.remove(section);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }),
                    const Divider(),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hành trình',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  if (_checkedDays != null)
                    ...List.generate((_itineraryData['days'] as int?) ?? 1, (
                      index,
                    ) {
                      final day = index + 1;
                      final color = _dayColors[day - 1] ?? AppTheme.primary;
                      return CheckboxListTile(
                        secondary: Icon(Icons.location_on, color: color),
                        title: Text(
                          'Ngày $day',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _checkedDays!.contains(day),
                        activeColor: AppTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.trailing,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) {
                          setSheetState(() {
                            if (val == true) {
                              _checkedDays!.add(day);
                            } else {
                              _checkedDays!.remove(day);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      final int numDays = (_itineraryData['days'] as int?) ?? 1;
      final bool hasFilter =
          (_checkedSections != null &&
              _checkedSections!.length < _sectionNames.length) ||
          (_checkedDays != null && _checkedDays!.length < numDays);
      if (hasFilter && mounted) {
        setState(() {
          _isMapExpanded = true;
          _isSheetHalf = false;
        });
      }
    });
  }

  Widget _buildExploreIcon(IconData icon, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade100,
          child: Icon(icon, color: AppTheme.subtitleText),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
        ),
      ],
    );
  }

  Widget _buildSavedPlaceLayer(String title, Color color) {
    return Row(
      children: [
        Icon(Icons.location_on, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
        Checkbox(value: true, onChanged: (v) {}, activeColor: AppTheme.primary),
      ],
    );
  }

  Future<void> _goToMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dịch vụ định vị đã bị tắt.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền truy cập vị trí bị từ chối.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quyền bị từ chối vĩnh viễn, hãy bật trong cài đặt.'),
          ),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          15.0,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi lấy vị trí: $e')));
      }
    }
  }

  Map<String, dynamic> _buildPostData() {
    final List<Map<String, dynamic>> items = [];

    for (final section in _sectionNames) {
      items.add({'itemType': 'SECTION_HEADER', 'content': section});

      final sectionDetails = _savedPlaces
          .where((d) => d['section'] == section)
          .toList();
      sectionDetails.sort(
        (a, b) => (a['sortOrder'] ?? 0).compareTo(b['sortOrder'] ?? 0),
      );

      for (final detail in sectionDetails) {
        if (detail['place'] != null) {
          final place = detail['place'];
          String content = detail['content'] ?? '';
          if (content.trim().isEmpty && place['description'] != null) {
            content = place['description'];
          }
          items.add({
            'itemType': 'PLACE',
            'placeId': place['id'],
            'place': place,
            'content': content,
          });
        } else if (detail['noteText'] != null) {
          final String text = detail['noteText'] ?? detail['notetext'] ?? '';
          final bool isTodo = text.startsWith('[TODO]');
          if (isTodo) {
            items.add({
              'itemType': 'TODO',
              'content': jsonEncode({
                'title': text.replaceFirst('[TODO]', '').trim(),
                'items': detail['todoItems'] ?? detail['todoitems'] ?? [],
              }),
            });
          } else {
            items.add({'itemType': 'NOTE', 'content': text});
          }
        }
      }
    }

    return {
      'title': _itineraryData['title'] ?? 'Hướng dẫn của tôi',
      'description': _itineraryData['description'] ?? '',
      'destination': _itineraryData['destination'] ?? '',
      'coverImage':
          _itineraryData['coverImage'] ?? 'https://via.placeholder.com/800x400',
      'postType': 'USER_CURATION',
      'items': items,
    };
  }

  void _previewGuide() {
    final user = AuthService().currentUser.value;
    final postData = _buildPostData();

    final mockPost = {
      ...postData,
      'id': _itineraryData['id'] ?? 'preview',
      'author': {
        'fullName': user?.fullName ?? 'Người dùng',
        'avatar': user?.avatar ?? 'https://via.placeholder.com/150',
      },
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExplorePostDetailScreen(
          post: mockPost,
          title: mockPost['title'] as String,
        ),
      ),
    );
  }

  void _showChangeImageSheet() {
    _webImagesPage = 1;
    _isLoadingMoreWebImages = false;
    _webImages = [];
    _hasMoreWebImages = true;
    _lastWebQuery = _itineraryData['destination'] ?? '';

    final ScrollController scrollController = ScrollController();
    bool isInitialLoading = true;
    bool initialized = false;
    void Function(void Function())? sheetSetState;

    Future<void> fetchWebImages({bool loadMore = false}) async {
      if (loadMore) {
        if (_isLoadingMoreWebImages || !_hasMoreWebImages) return;
        _isLoadingMoreWebImages = true;
        sheetSetState?.call(() {});
        _webImagesPage++;
      } else {
        isInitialLoading = true;
        _webImagesPage = 1;
      }

      try {
        final result = await DatabaseService().searchWebImages(
          _lastWebQuery,
          page: _webImagesPage,
        );

        if (loadMore) {
          _webImages.addAll(result['results'] ?? []);
          _hasMoreWebImages = result['hasMore'] ?? false;
          _isLoadingMoreWebImages = false;
        } else {
          _webImages = result['results'] ?? [];
          _hasMoreWebImages = result['hasMore'] ?? false;
          isInitialLoading = false;
        }
      } catch (e) {
        if (loadMore) {
          _isLoadingMoreWebImages = false;
        } else {
          isInitialLoading = false;
        }
        debugPrint('fetchWebImages error: $e');
      }
      if (mounted) sheetSetState?.call(() {});
    }

    scrollController.addListener(() {
      if (scrollController.hasClients &&
          scrollController.position.pixels >=
              scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMoreWebImages && _hasMoreWebImages) {
          fetchWebImages(loadMore: true);
        }
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            sheetSetState = setSheetState;

            if (!initialized) {
              initialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                fetchWebImages();
              });
            }

            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Thay đổi ảnh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const TabBar(
                      tabs: [
                        Tab(text: 'Từ web'),
                        Tab(text: 'Tải lên'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Từ web
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Tìm kiếm theo địa điểm',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                    ),
                                  ),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      _lastWebQuery = val.trim();
                                      _webImages = [];
                                      _webImagesPage = 1;
                                      fetchWebImages();
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: isInitialLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _webImages.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Không tìm thấy ảnh cho "$_lastWebQuery"',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      )
                                    : GridView.builder(
                                        controller: scrollController,
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                              childAspectRatio: 1,
                                            ),
                                        itemCount:
                                            _webImages.length +
                                            (_isLoadingMoreWebImages ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index == _webImages.length) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          final imageUrl =
                                              _webImages[index]['url']
                                                  as String? ??
                                              '';
                                          if (imageUrl.isEmpty)
                                            return const SizedBox();
                                          return GestureDetector(
                                            onTap: () async {
                                              final itineraryId =
                                                  _itineraryData['id'];
                                              if (itineraryId != null) {
                                                final updated =
                                                    await DatabaseService()
                                                        .updateItinerary(
                                                          itineraryId,
                                                          {
                                                            'coverImage':
                                                                imageUrl,
                                                          },
                                                        );
                                                if (updated) {
                                                  setState(() {
                                                    _itineraryData['coverImage'] =
                                                        imageUrl;
                                                  });
                                                }
                                              }
                                              if (mounted)
                                                Navigator.pop(context);
                                            },
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder:
                                                    (context, child, progress) {
                                                      if (progress == null)
                                                        return child;
                                                      return Container(
                                                        color: Colors.grey[100],
                                                        child: const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      color: Colors.grey[200],
                                                      child: const Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                          // Tab 2: Tải lên
                          const Center(
                            child: Text('Tính năng tải ảnh đang phát triển'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => scrollController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final destination = _itineraryData['destination'] ?? 'Điểm đến';
    final PreferredSizeWidget appBarBottom = PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.subtitleText,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: _itineraryData['isGuide'] == true
              ? const [Tab(text: 'Tổng quan'), Tab(text: 'Khám phá')]
              : const [
                  Tab(text: 'Tổng quan'),
                  Tab(text: 'Hành trình'),
                  Tab(text: 'Chi phí'),
                  Tab(text: 'Khám phá'),
                ],
        ),
      ),
    );

    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight =
        topPadding + 56.0 + 48.0; // 56 for AppBar + 48 for TabBar
    final screenHeight = MediaQuery.of(context).size.height;
    final double halfHeight = (screenHeight - headerHeight) * 0.55;
    final double targetSheetHeight = !_isMapExpanded
        ? (screenHeight - headerHeight)
        : (_selectedMapPlace != null
              ? 0.0
              : (_isSheetHalf ? halfHeight : 75.0));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 1. Background Map
          Positioned.fill(
            child: _mapCenter != null
                ? FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _mapCenter!,
                      initialZoom: 13.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedMapPlace = null;
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&apistyle=s.t%3A2%7Cp.v%3Aoff',
                      ),
                      MarkerLayer(
                        markers: (() {
                          final List<Marker> allMarkers = [];

                          if (_activeSearchQuery != null) {
                            final sortedFiltered =
                                List<Map<String, dynamic>>.from(
                                  _filteredMapPlaces,
                                );
                            sortedFiltered.sort((a, b) {
                              final isSelectedMapPlaceId =
                                  _selectedMapPlace != null
                                  ? (_selectedMapPlace!['place']?['id'] ??
                                        _selectedMapPlace!['id'])
                                  : null;
                              final isA =
                                  a['id'] != null &&
                                  (a['id'] == _focusedPlaceId ||
                                      (isSelectedMapPlaceId != null &&
                                          isSelectedMapPlaceId == a['id']));
                              final isB =
                                  b['id'] != null &&
                                  (b['id'] == _focusedPlaceId ||
                                      (isSelectedMapPlaceId != null &&
                                          isSelectedMapPlaceId == b['id']));
                              if (isA && !isB) return 1;
                              if (!isA && isB) return -1;
                              return 0;
                            });

                            allMarkers.addAll(
                              sortedFiltered.map((place) {
                                if (place['latitude'] == null ||
                                    place['longitude'] == null) {
                                  return null;
                                }
                                final lat = (place['latitude'] as num)
                                    .toDouble();
                                final lon = (place['longitude'] as num)
                                    .toDouble();
                                final isSelectedMapPlaceId =
                                    _selectedMapPlace != null
                                    ? (_selectedMapPlace!['place']?['id'] ??
                                          _selectedMapPlace!['id'])
                                    : null;
                                final isSelected =
                                    isSelectedMapPlaceId == place['id'];
                                final markerSize = isSelected ? 56.0 : 32.0;

                                return Marker(
                                  point: LatLng(lat, lon),
                                  width: markerSize,
                                  height: markerSize,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedMapPlace = place;
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: isSelected ? 3 : 2,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black87
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                  spreadRadius: 2,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.white,
                                          size: isSelected ? 32 : 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).whereType<Marker>(),
                            );
                          }

                          final currentPlaces = <Map<String, dynamic>>[];

                          if (_activeSearchQuery == null) {
                            for (var p in _savedPlaces) {
                              final sectionName =
                                  p['section'] as String? ??
                                  (_sectionNames.isNotEmpty
                                      ? _sectionNames.first
                                      : null);
                              if (sectionName == null ||
                                  _checkedSections == null ||
                                  _checkedSections!.contains(sectionName)) {
                                if (p['place'] != null) {
                                  currentPlaces.add({
                                    'type': 'overview',
                                    'data': p,
                                    'id': p['place']['id'],
                                  });
                                }
                              }
                            }

                            for (var d in _details) {
                              final day = d['day'] as int? ?? 1;
                              if (d['place'] != null &&
                                  (_checkedDays == null ||
                                      _checkedDays!.contains(day))) {
                                currentPlaces.add({
                                  'type': 'itinerary',
                                  'data': d,
                                  'id': d['place']['id'],
                                });
                              }
                            }
                          }

                          final sortedPlaces = List<Map<String, dynamic>>.from(
                            currentPlaces,
                          );
                          sortedPlaces.sort((a, b) {
                            final isAFocused =
                                a['id'] != null &&
                                (a['id'] == _focusedPlaceId ||
                                    (_selectedMapPlace != null &&
                                        _selectedMapPlace!['id'] == a['id']));
                            final isBFocused =
                                b['id'] != null &&
                                (b['id'] == _focusedPlaceId ||
                                    (_selectedMapPlace != null &&
                                        _selectedMapPlace!['id'] == b['id']));

                            if (isAFocused && !isBFocused) return 1;
                            if (!isAFocused && isBFocused) return -1;

                            // Prioritize itinerary (drawn on top)
                            final aTypeScore = a['type'] == 'overview' ? 0 : 1;
                            final bTypeScore = b['type'] == 'overview' ? 0 : 1;
                            return aTypeScore.compareTo(bTypeScore);
                          });

                          allMarkers.addAll(
                            sortedPlaces.map((wrapper) {
                              final bool isOverview =
                                  wrapper['type'] == 'overview';
                              final savedPlace = wrapper['data'];
                              final place = savedPlace['place'];
                              if (place == null ||
                                  place['latitude'] == null ||
                                  place['longitude'] == null) {
                                return null;
                              }
                              final lat = (place['latitude'] as num).toDouble();
                              final lon = (place['longitude'] as num)
                                  .toDouble();

                              int indexInSection;
                              Color color;
                              IconData? icon;

                              if (isOverview) {
                                final sectionName =
                                    savedPlace['section'] as String?;
                                final sectionList = _savedPlaces
                                    .where((d) => d['section'] == sectionName)
                                    .toList();
                                indexInSection =
                                    sectionList.indexWhere(
                                      (d) => d['id'] == savedPlace['id'],
                                    ) +
                                    1;
                                color =
                                    _sectionColors[sectionName] ??
                                    AppTheme.primary;
                                icon = _sectionIcons[sectionName];
                              } else {
                                final day = savedPlace['day'] as int? ?? 1;
                                final dayList = _details
                                    .where((d) => d['day'] == day)
                                    .toList();
                                indexInSection =
                                    dayList.indexWhere(
                                      (d) => d['id'] == savedPlace['id'],
                                    ) +
                                    1;
                                color = _dayColors[day - 1] ?? AppTheme.primary;
                                icon = null;
                              }

                              final bool isSheetMinimized =
                                  _isMapExpanded &&
                                  !_isSheetHalf &&
                                  _selectedMapPlace == null;
                              final isSelectedMapPlaceId =
                                  _selectedMapPlace != null
                                  ? (_selectedMapPlace!['place']?['id'] ??
                                        _selectedMapPlace!['id'])
                                  : null;
                              final isFocused =
                                  !isSheetMinimized &&
                                  ((place['id'] == _focusedPlaceId) ||
                                      (isSelectedMapPlaceId == place['id']));
                              final double markerSize = isFocused ? 56.0 : 32.0;

                              return Marker(
                                point: LatLng(lat, lon),
                                width: markerSize,
                                height: markerSize,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedMapPlace = savedPlace;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: isFocused ? 3 : 2,
                                      ),
                                      boxShadow: isFocused
                                          ? [
                                              BoxShadow(
                                                color: color.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child:
                                          (icon == null ||
                                              icon.codePoint ==
                                                  Icons
                                                      .looks_one_rounded
                                                      .codePoint)
                                          ? Text(
                                              '$indexInSection',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: isFocused ? 24 : 12,
                                              ),
                                            )
                                          : Icon(
                                              icon,
                                              color: Colors.white,
                                              size: isFocused ? 30 : 16,
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }).whereType<Marker>(),
                          );

                          if (_currentLocation != null) {
                            allMarkers.add(
                              Marker(
                                point: _currentLocation!,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return allMarkers;
                        })(),
                      ),
                    ],
                  )
                : Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
          ),

          // 2. Map Action Buttons (Hidden when full screen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            top: topPadding + 60,
            right: !_isMapExpanded ? -100 : 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Search Button
                GestureDetector(
                  onTap: _showSearchOverlay,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.search_rounded,
                        color: AppTheme.darkText,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Layers Button
                if (_activeSearchQuery == null) ...[
                  GestureDetector(
                    onTap: _showLayersSheet,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.layers_rounded,
                          color: AppTheme.darkText,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Hotel Button (Placeholder)
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng Khách sạn sẽ sớm ra mắt!'),
                      ),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.bed_rounded,
                        color: AppTheme.darkText,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Location Button
                GestureDetector(
                  onTap: _goToMyLocation,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.near_me_rounded, // Location arrow
                        color: AppTheme.darkText,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Dynamic Custom Header
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            color: !_isMapExpanded ? Colors.white : Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Bar
                  SizedBox(
                    height: 56,
                    child: _isSelectionMode
                        ? Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(left: 16),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF44336),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_selectedItemIds.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: Colors.black87,
                                ),
                                tooltip: 'Sao chép đến...',
                                onPressed: () =>
                                    _showSelectSectionBottomSheet(isCopy: true),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.drive_file_move_outline,
                                  color: Colors.black87,
                                ),
                                tooltip: 'Di chuyển đến...',
                                onPressed: () => _showSelectSectionBottomSheet(
                                  isCopy: false,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.black87,
                                ),
                                tooltip: 'Xóa',
                                onPressed: _deleteSelectedItems,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.black87,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedItemIds.clear();
                                    _selectedSections.clear();
                                  });
                                },
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                margin: EdgeInsets.only(
                                  left: 16,
                                  top: _isMapExpanded ? 8 : 0,
                                ),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: !_isMapExpanded
                                      ? Colors.transparent
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: !_isMapExpanded
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    if (_activeSearchQuery != null) {
                                      setState(() {
                                        _activeSearchQuery = null;
                                        _filteredMapPlaces = [];
                                        _selectedMapPlace = null;
                                        _isMapExpanded = false;
                                      });
                                    } else if (_isMapExpanded) {
                                      setState(() => _isMapExpanded = false);
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: AppTheme.darkText,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: !_isMapExpanded
                                    ? Text(
                                        _itineraryData['title'] as String? ??
                                            'Hướng dẫn',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppTheme.darkText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : const SizedBox(),
                              ),

                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                margin: EdgeInsets.only(
                                  right: 16,
                                  top: _isMapExpanded ? 8 : 0,
                                ),
                                height: 32,
                                decoration: BoxDecoration(
                                  color: !_isMapExpanded
                                      ? Colors.transparent
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: !_isMapExpanded
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_itineraryData['isGuide'] == true)
                                      GestureDetector(
                                        onTap: _previewGuide,
                                        child: Container(
                                          width: 32,
                                          color: Colors.transparent,
                                          child: Center(
                                            child: Icon(
                                              Icons.visibility_rounded,
                                              color: AppTheme.darkText,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    GestureDetector(
                                      onTap: _showChangeImageSheet,
                                      child: Container(
                                        width: 32,
                                        color: Colors.transparent,
                                        child: Center(
                                          child: Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: AppTheme.darkText,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_isMapExpanded)
                                      Container(
                                        width: 1,
                                        height: 12,
                                        color: Colors.grey.shade300,
                                      ),

                                    GestureDetector(
                                      onTap: _showMapSettingsSheet,
                                      child: Container(
                                        width: 32,
                                        color:
                                            Colors.transparent, // for hit test
                                        child: Center(
                                          child: Icon(
                                            Icons.more_horiz_rounded,
                                            color: AppTheme.darkText,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Tab Bar (Only visible when full screen)
                  if (!_isMapExpanded) appBarBottom,
                ],
              ),
            ),
          ),

          // 4. Main Content Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: _dragHeight ?? targetSheetHeight,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: !_isMapExpanded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  if (_isMapExpanded || _isDragging)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 15,
                      offset: const Offset(0, -5),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: !_isMapExpanded
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(24)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableHeight = constraints.maxHeight;
                    final handleHeight = _isMapExpanded ? 20.0 : 16.0;
                    final tabBarHeight = _isMapExpanded ? 48.0 : 0.0;
                    final contentHeight = math.max(
                      0.0,
                      availableHeight - handleHeight - tabBarHeight,
                    );

                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          GestureDetector(
                            onVerticalDragStart: (details) {
                              setState(() {
                                _isDragging = true;
                                _dragHeight = targetSheetHeight;
                              });
                            },
                            onVerticalDragUpdate: (details) {
                              setState(() {
                                _dragHeight =
                                    (_dragHeight ?? targetSheetHeight) -
                                    details.primaryDelta!;
                                // Clamp the height
                                final max = screenHeight - headerHeight;
                                final min = _selectedMapPlace != null
                                    ? 0.0
                                    : 75.0; // Allow dragging down to bottom
                                if (_dragHeight! > max) _dragHeight = max;
                                if (_dragHeight! < min) _dragHeight = min;
                              });
                            },
                            onVerticalDragEnd: (details) {
                              final max = screenHeight - headerHeight;
                              final min = _selectedMapPlace != null
                                  ? 0.0
                                  : 75.0;
                              final half = (screenHeight - headerHeight) * 0.55;
                              final wasExpanded = _isMapExpanded;

                              setState(() {
                                _isDragging = false;
                                if (details.primaryVelocity != null &&
                                    details.primaryVelocity!.abs() > 300) {
                                  if (details.primaryVelocity! > 0) {
                                    // Swiped down
                                    if (!_isMapExpanded) {
                                      _isMapExpanded = true;
                                      _isSheetHalf = true;
                                    } else if (_isSheetHalf) {
                                      _isSheetHalf = false;
                                    }
                                  } else {
                                    // Swiped up
                                    if (_isMapExpanded && !_isSheetHalf) {
                                      _isSheetHalf = true;
                                    } else if (_isMapExpanded && _isSheetHalf) {
                                      _isMapExpanded = false;
                                      _isSheetHalf = false;
                                    }
                                  }
                                } else {
                                  final h = _dragHeight ?? targetSheetHeight;
                                  final distToFull = (h - max).abs();
                                  final distToHalf = (h - half).abs();
                                  final distToMin = (h - min).abs();

                                  if (distToFull <= distToHalf &&
                                      distToFull <= distToMin) {
                                    _isMapExpanded = false;
                                    _isSheetHalf = false;
                                  } else if (distToHalf <= distToFull &&
                                      distToHalf <= distToMin) {
                                    _isMapExpanded = true;
                                    _isSheetHalf = true;
                                  } else {
                                    _isMapExpanded = true;
                                    _isSheetHalf = false;
                                  }
                                }
                                _dragHeight = null;

                                if (!_isMapExpanded || _isSheetHalf) {
                                  final int numDays =
                                      (_itineraryData['days'] as int?) ?? 1;
                                  if (_checkedSections != null) {
                                    _checkedSections = Set.from(_sectionNames);
                                  }
                                  if (_checkedDays != null) {
                                    _checkedDays = Set.from(
                                      Iterable.generate(numDays, (i) => i + 1),
                                    );
                                  }

                                  if (_activeSearchQuery != null) {
                                    _activeSearchQuery = null;
                                    _filteredMapPlaces = [];
                                    _selectedMapPlace = null;
                                  }
                                }
                              });

                              if (!wasExpanded && _isMapExpanded) {
                                Future.delayed(
                                  const Duration(milliseconds: 100),
                                  () {
                                    _focusPlaceOnMap(_focusedPlaceId);
                                  },
                                );
                              }
                            },
                            child: Container(
                              color: Colors.transparent,
                              width: double.infinity,
                              padding: EdgeInsets.only(
                                top: 12,
                                bottom: _isMapExpanded ? 4 : 0,
                              ),
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Show TabBar inside the sheet when expanded so we can still switch tabs
                          if (_isMapExpanded)
                            Container(
                              color: Colors.white,
                              child: TabBar(
                                controller: _tabController,
                                labelColor: AppTheme.primary,
                                unselectedLabelColor: AppTheme.subtitleText,
                                indicatorColor: AppTheme.primary,
                                indicatorWeight: 3,
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                tabs: _itineraryData['isGuide'] == true
                                    ? const [
                                        Tab(text: 'Tổng quan'),
                                        Tab(text: 'Khám phá'),
                                      ]
                                    : const [
                                        Tab(text: 'Tổng quan'),
                                        Tab(text: 'Hành trình'),
                                        Tab(text: 'Chi phí'),
                                        Tab(text: 'Khám phá'),
                                      ],
                              ),
                            ),

                          // The Tab Views
                          SizedBox(
                            height: contentHeight,
                            child: Stack(
                              children: [
                                _isLoading
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          color: AppTheme.primary,
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (constraints.maxHeight < 100) {
                                            return const SizedBox.shrink();
                                          }
                                          return TabBarView(
                                            controller: _tabController,
                                            children:
                                                _itineraryData['isGuide'] ==
                                                    true
                                                ? [
                                                    _buildOverviewTab(),
                                                    _buildExploreTab(),
                                                  ]
                                                : [
                                                    _buildOverviewTab(),
                                                    _buildItineraryTab(),
                                                    _buildExpensesTab(),
                                                    _buildExploreTab(),
                                                  ],
                                          );
                                        },
                                      ),

                                // FABs
                                if (!_isMapExpanded)
                                  Positioned(
                                    right: 16,
                                    bottom: 16,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primary,
                                                Color(0xFF7C3AED),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: FloatingActionButton(
                                            heroTag: 'ai_btn',
                                            onPressed: _runAIPlanner,
                                            backgroundColor: Colors.transparent,
                                            elevation: 0,
                                            mini: true,
                                            child: const Icon(
                                              Icons.auto_awesome_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        FloatingActionButton(
                                          heroTag: 'map_btn',
                                          onPressed: _showMapOverview,
                                          backgroundColor: AppTheme.darkText,
                                          mini: true,
                                          child: const Icon(
                                            Icons.map_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        FloatingActionButton(
                                          heroTag: 'add_btn',
                                          onPressed: () async {
                                            if (_tabController.index == 1) {
                                              _showPremiumNotification(
                                                title: 'Hướng dẫn',
                                                message:
                                                    'Vui lòng chọn địa điểm bên dưới để thêm!',
                                                icon:
                                                    Icons.info_outline_rounded,
                                                color: AppTheme.primary,
                                              );
                                            } else {
                                              _createNewSection();
                                            }
                                          },
                                          backgroundColor: AppTheme.darkText,
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
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
            ),
          ),

          // Zoom Button (Moved outside so it doesn't get clipped by AnimatedContainer)
          if (_isMapExpanded && _selectedMapPlace == null && !_isSheetHalf)
            Positioned(
              left: 16,
              bottom: 75.0 + 16.0,
              child: GestureDetector(
                onTap: _showZoomOptionsBottomSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 20, color: Colors.black87),
                      SizedBox(width: 8),
                      Text(
                        'Phóng to vào...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isMapExpanded && _selectedMapPlace != null)
            _buildMapPlaceBottomSheet(),
          if (_activeSearchQuery != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đang tìm kiếm: $_activeSearchQuery',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeSearchQuery = null;
                            _filteredMapPlaces = [];
                            _selectedMapPlace = null;
                            _isMapExpanded = false;
                          });
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addNoteInline(String section) async {
    final itineraryId = _itineraryData['id'] as int;

    dynamic result;
    if (section.startsWith('Ngày') && _itineraryData['isGuide'] != true) {
      final int day =
          int.tryParse(section.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final dayDetails = _details.where((d) => d['day'] == day).toList();
      int maxOrder = 0;
      for (var d in dayDetails) {
        final ord = d['sortOrder'] ?? 0;
        if (ord > maxOrder) maxOrder = ord;
      }
      result = await DatabaseService().addPlaceToItinerary(
        itineraryId: itineraryId,
        day: day,
        noteText: 'Thêm ghi chú tại đây',
        sortOrder: maxOrder + 1,
      );
    } else {
      final sectionDetails = _savedPlaces
          .where((d) => d['section'] == section)
          .toList();
      int maxOrder = 0;
      for (var d in sectionDetails) {
        final ord = d['sortOrder'] ?? 0;
        if (ord > maxOrder) maxOrder = ord;
      }
      result = await DatabaseService().addPlaceToSaved(
        itineraryId: itineraryId,
        section: section,
        noteText: 'Thêm ghi chú tại đây',
        sortOrder: maxOrder + 1,
      );
    }

    if (result != null) {
      setState(() {
        _editingNoteId = result['id'] as int?;
      });
      await _loadData(silent: true);
    }
  }

  Future<void> _addChecklistInline(String section) async {
    final itineraryId = _itineraryData['id'] as int;

    dynamic result;
    if (section.startsWith('Ngày') && _itineraryData['isGuide'] != true) {
      final int day =
          int.tryParse(section.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      final dayDetails = _details.where((d) => d['day'] == day).toList();
      int maxOrder = 0;
      for (var d in dayDetails) {
        final ord = d['sortOrder'] ?? d['sortorder'] ?? 0;
        if (ord > maxOrder) maxOrder = ord;
      }
      result = await DatabaseService().addPlaceToItinerary(
        itineraryId: itineraryId,
        day: day,
        noteText: '[TODO] Danh sách công việc',
        sortOrder: maxOrder + 1,
      );
    } else {
      final sectionDetails = _savedPlaces
          .where((d) => d['section'] == section)
          .toList();
      int maxOrder = 0;
      for (var d in sectionDetails) {
        final ord = d['sortOrder'] ?? d['sortorder'] ?? 0;
        if (ord > maxOrder) maxOrder = ord;
      }
      result = await DatabaseService().addPlaceToSaved(
        itineraryId: itineraryId,
        section: section,
        noteText: '[TODO] Danh sách công việc',
        sortOrder: maxOrder + 1,
      );
    }

    if (result != null) {
      setState(() {
        _editingNoteId = result['id'] as int?;
      });
      await _loadData(silent: true);
    }
  }

  void _showTemplateBottomSheet(
    int checklistId,
    List<dynamic> currentItems,
    bool isItineraryDetail,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ChecklistTemplateSheet(
          checklistId: checklistId,
          currentItems: currentItems,
          onAddItems: (newItems) async {
            final List<Map<String, dynamic>> updated =
                List<Map<String, dynamic>>.from(
                  currentItems
                      .map((it) => Map<String, dynamic>.from(it as Map))
                      .toList(),
                );
            for (var itemText in newItems) {
              if (!updated.any((it) => it['text'] == itemText)) {
                updated.add({'text': itemText, 'done': false});
              }
            }
            final success = await DatabaseService().updateNoteOrDetail(
              checklistId,
              {'todoItems': updated},
              isItineraryDetail,
            );
            if (success && mounted) {
              _loadData(silent: true);
            }
          },
        );
      },
    );
  }

  void _fitMapToBounds(List<Map<String, dynamic>> details) {
    if (details.isEmpty) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLon = 180.0;
    double maxLon = -180.0;
    bool hasValidPoints = false;

    for (var d in details) {
      final p = d['place'];
      if (p != null && p['latitude'] != null && p['longitude'] != null) {
        final lat = (p['latitude'] as num).toDouble();
        final lon = (p['longitude'] as num).toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
        hasValidPoints = true;
      }
    }

    if (!hasValidPoints) return;

    // Add some padding to bounds
    final latPadding = (maxLat - minLat) * 0.1;
    final lonPadding = (maxLon - minLon) * 0.1;

    // If it's a single point, bounds will be zero, so we pad it.
    if (maxLat == minLat && maxLon == minLon) {
      _mapController.move(LatLng(minLat, minLon), 15.0);
      return;
    }

    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLon - lonPadding),
      LatLng(maxLat + latPadding, maxLon + lonPadding),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _showZoomOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Phóng to vào',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Hoàn thành',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // All points
                  ListTile(
                    leading: const Icon(Icons.search, color: Colors.black87),
                    title: const Text('Hiển thị tất cả điểm trên bản đồ'),
                    onTap: () {
                      _fitMapToBounds(_savedPlaces);
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),

                  // Sections
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Tổng quan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ..._sectionNames.map((section) {
                    final color = _sectionColors[section] ?? AppTheme.primary;
                    return ListTile(
                      leading: Icon(Icons.location_on, color: color),
                      title: Text(section),
                      onTap: () {
                        final sectionPlaces = _savedPlaces
                            .where((d) => d['section'] == section)
                            .toList();
                        _fitMapToBounds(sectionPlaces);
                        Navigator.pop(context);
                      },
                    );
                  }),

                  const Divider(),

                  // Days
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Hành trình',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ...List.generate(
                    (_itineraryData['days'] as num?)?.toInt() ?? 1,
                    (i) {
                      final dayNum = i + 1;
                      return ListTile(
                        leading: Icon(Icons.location_on, color: AppTheme.amber),
                        title: Text('Ngày $dayNum'),
                        onTap: () {
                          final dayPlaces = _details
                              .where((d) => d['day'] == dayNum)
                              .toList();
                          _fitMapToBounds(dayPlaces);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapPlaceBottomSheet() {
    if (_selectedMapPlace == null) return const SizedBox();

    final p =
        _selectedMapPlace!['place'] as Map<String, dynamic>? ??
        _selectedMapPlace!;
    final name = p['name'] ?? 'Địa điểm';
    final description = p['description'] ?? p['editorialSummary'] ?? '';

    String imageUrl = p['image'] ?? '';

    // Determine the color and icon from category or section
    IconData? finalIcon;
    Color finalColor = const Color(0xFF3B5998);
    int? indexInSection;

    final sectionName = _selectedMapPlace!['section'] as String?;
    final day = _selectedMapPlace!['day'] as int?;

    if (sectionName != null) {
      finalColor = _sectionColors[sectionName] ?? AppTheme.primary;
      finalIcon = _sectionIcons[sectionName];
      final sectionList = _savedPlaces
          .where((d) => d['section'] == sectionName)
          .toList();
      sectionList.sort(
        (a, b) => (a['sortOrder'] as int? ?? 0).compareTo(
          b['sortOrder'] as int? ?? 0,
        ),
      );
      indexInSection =
          sectionList.indexWhere((d) => d['id'] == _selectedMapPlace!['id']) +
          1;
    } else if (day != null) {
      finalColor = _dayColors[day - 1] ?? AppTheme.primary;
      final dayList = _details.where((d) => d['day'] == day).toList();
      dayList.sort(
        (a, b) => (a['sortOrder'] as int? ?? 0).compareTo(
          b['sortOrder'] as int? ?? 0,
        ),
      );
      indexInSection =
          dayList.indexWhere((d) => d['id'] == _selectedMapPlace!['id']) + 1;
    } else {
      if (p['category'] != null) {
        final cat = p['category'];
        if (cat['iconCode'] != null) {
          finalIcon = IconData(cat['iconCode'], fontFamily: 'MaterialIcons');
        }
        if (cat['id'] != null) {
          final List<Color> colors = [
            const Color(0xFF3B5998),
            const Color(0xFFE91E63),
            const Color(0xFF009688),
            const Color(0xFFFF9800),
            const Color(0xFF9C27B0),
            const Color(0xFF4CAF50),
            const Color(0xFFF44336),
            const Color(0xFF673AB7),
            const Color(0xFF00BCD4),
          ];
          finalColor = colors[(cat['id'] as num).toInt() % colors.length];
        }
      }
    }

    final targetPlaceId = p['id'];
    int savedCount = 0;
    for (var d in _savedPlaces) {
      if ((d['placeId'] ?? d['place']?['id']) == targetPlaceId &&
          (d['section'] != null && d['section'].toString().isNotEmpty)) {
        savedCount++;
      }
    }
    for (var d in _details) {
      if ((d['placeId'] ?? d['place']?['id']) == targetPlaceId &&
          d['day'] != null) {
        savedCount++;
      }
    }
    bool isSavedToCurrentTrip = savedCount > 0;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category or Section Circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: finalColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child:
                      indexInSection != null &&
                          (finalIcon == null ||
                              finalIcon.codePoint ==
                                  Icons.looks_one_rounded.codePoint)
                      ? Text(
                          '$indexInSection',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : Icon(
                          finalIcon ?? Icons.place,
                          color: Colors.white,
                          size: 14,
                        ),
                ),
                const SizedBox(width: 12),
                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.darkText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Mô tả: $description',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.subtitleText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Thumbnail
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Actions
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      SaveToTripBottomSheet.show(
                        context,
                        _selectedMapPlace!['place'] ?? _selectedMapPlace!,
                        onSaved: () {
                          _loadData(); // refresh data if it was saved to the current trip
                        },
                        initialItinerary: widget.itinerary,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSavedToCurrentTrip
                            ? Colors.grey[200]
                            : AppTheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSavedToCurrentTrip
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            color: isSavedToCurrentTrip
                                ? Colors.black
                                : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isSavedToCurrentTrip
                                ? 'Đã thêm vào $savedCount danh sách'
                                : 'Thêm vào chuyến đi',
                            style: TextStyle(
                              color: isSavedToCurrentTrip
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (isSavedToCurrentTrip) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.black,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      PlaceDetailBottomSheet.show(
                        context,
                        p,
                        icon: finalIcon,
                        color: finalColor,
                        text: indexInSection?.toString(),
                        savedCount: savedCount,
                        currentItinerary: widget.itinerary,
                        onTripUpdated: () {
                          _loadData();
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Chi tiết',
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      if (p['latitude'] != null && p['longitude'] != null) {
                        final lat = p['latitude'];
                        final lon = p['longitude'];
                        final url = Uri.parse(
                          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
                        );
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions,
                        color: AppTheme.darkText,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: AppTheme.darkText,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Hỏi AI',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedNoteCard(
    Map<String, dynamic> detail,
    int index,
    int listIdx,
    List<Map<String, dynamic>> sectionDetails,
  ) {
    final bool isItineraryDetail = detail.containsKey('day');
    final String text = detail['noteText'] ?? detail['notetext'] ?? '';
    final bool isCollapsed =
        detail['isCollapsed'] == true || detail['iscollapsed'] == true;
    final int id = detail['id'] as int;
    final bool isEditing = id == _editingNoteId;

    final bool isTodo = text.startsWith('[TODO]');
    final String displayTitle = isTodo
        ? text.replaceFirst('[TODO]', '').trim()
        : text;

    TextEditingController? editController;
    if (isEditing) {
      editController = TextEditingController(
        text: isTodo
            ? displayTitle
            : (text == 'Thêm ghi chú tại đây' ? '' : text),
      );
      editController.selection = TextSelection.fromPosition(
        TextPosition(offset: editController.text.length),
      );
    }

    List<dynamic> reactions = [];
    if (detail['reactions'] != null) {
      if (detail['reactions'] is List) {
        reactions = detail['reactions'] as List;
      } else if (detail['reactions'] is String) {
        try {
          reactions = json.decode(detail['reactions']) as List;
        } catch (_) {}
      }
    }

    List<dynamic> todoList = [];
    final rawTodo = detail['todoItems'] ?? detail['todoitems'];
    if (rawTodo != null) {
      if (rawTodo is List) {
        todoList = rawTodo;
      } else if (rawTodo is String) {
        try {
          todoList = json.decode(rawTodo) as List;
        } catch (_) {}
      }
    }

    final bool allDone =
        todoList.isNotEmpty && todoList.every((item) => item['done'] == true);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedItemIds.contains(id)) {
              _selectedItemIds.remove(id);
            } else {
              _selectedItemIds.add(id);
            }
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: icon + title + collapse/check toggle
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTodo
                        ? Icons.fact_check_outlined
                        : Icons.description_outlined,
                    color: AppTheme.subtitleText,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: isEditing
                        ? TextField(
                            controller: editController,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: isTodo
                                  ? 'Tên danh sách...'
                                  : 'Nhập ghi chú...',
                              hintStyle: const TextStyle(
                                color: Colors.black26,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (val) async {
                              final cleanVal = val.trim();
                              String finalVal = cleanVal.isEmpty
                                  ? (isTodo
                                        ? 'Danh sách công việc'
                                        : 'Ghi chú mới')
                                  : cleanVal;
                              if (isTodo) finalVal = '[TODO] $finalVal';
                              await DatabaseService().updateNoteOrDetail(id, {
                                'noteText': finalVal,
                              }, isItineraryDetail);
                              setState(() => _editingNoteId = null);
                              await _loadData(silent: true);
                            },
                          )
                        : GestureDetector(
                            onTap: () => setState(() => _editingNoteId = id),
                            child: Text(
                              isTodo
                                  ? (displayTitle.isEmpty
                                        ? 'Danh sách công việc'
                                        : displayTitle)
                                  : (text.isEmpty
                                        ? 'Thêm ghi chú tại đây'
                                        : text),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.darkText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                // Right-side button: save / all-done / collapse-toggle
                if (isEditing)
                  GestureDetector(
                    onTap: () async {
                      final cleanVal = editController?.text.trim() ?? '';
                      String finalVal = cleanVal.isEmpty
                          ? (isTodo ? 'Danh sách công việc' : 'Ghi chú mới')
                          : cleanVal;
                      if (isTodo) finalVal = '[TODO] $finalVal';
                      await DatabaseService().updateNoteOrDetail(id, {
                        'noteText': finalVal,
                      }, isItineraryDetail);
                      setState(() => _editingNoteId = null);
                      await _loadData(silent: true);
                    },
                    child: Icon(
                      Icons.check_rounded,
                      color: AppTheme.green,
                      size: 22,
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => DatabaseService()
                        .updateNoteOrDetail(id, {
                          'isCollapsed': !isCollapsed,
                        }, isItineraryDetail)
                        .then((_) => _loadData(silent: true)),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                        color: AppTheme.subtitleText,
                        size: 20,
                      ),
                    ),
                  ),
                if (_isSelectionMode)
                  IgnorePointer(
                    child: Checkbox(
                      value: _selectedItemIds.contains(id),
                      onChanged: (_) {},
                      activeColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Todo items list
            if (isTodo && todoList.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) newIndex -= 1;
                    final updated = List.from(todoList);
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    DatabaseService()
                        .updateNoteOrDetail(id, {
                          'todoItems': updated,
                        }, isItineraryDetail)
                        .then((_) => _loadData(silent: true));
                  },
                  children: todoList.asMap().entries.map((entry) {
                    final itemIdx = entry.key;
                    final item = entry.value;
                    final String itemText = item['text'] ?? '';
                    final bool done = item['done'] == true;
                    final String itemKey = '${id}_$itemText';
                    final bool isFocused = _focusedTodoItemKey == itemKey;

                    return Padding(
                      key: ValueKey(itemKey),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final updated = todoList.map((it) {
                                if (it['text'] == itemText) {
                                  return {...it as Map, 'done': !done};
                                }
                                return it;
                              }).toList();
                              DatabaseService()
                                  .updateNoteOrDetail(id, {
                                    'todoItems': updated,
                                  }, isItineraryDetail)
                                  .then((_) => _loadData(silent: true));
                            },
                            child: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: done
                                  ? AppTheme.primary
                                  : AppTheme.subtitleText,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isFocused) {
                                    _focusedTodoItemKey = null;
                                  } else {
                                    _focusedTodoItemKey = itemKey;
                                  }
                                });
                              },
                              child: Container(
                                color: Colors.transparent,
                                child: Text(
                                  itemText,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: done
                                        ? AppTheme.subtitleText
                                        : AppTheme.darkText,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isFocused) ...[
                            GestureDetector(
                              onTap: () {
                                final updated = List.from(todoList)
                                  ..removeWhere((it) => it['text'] == itemText);
                                DatabaseService()
                                    .updateNoteOrDetail(id, {
                                      'todoItems': updated,
                                    }, isItineraryDetail)
                                    .then((_) => _loadData(silent: true));
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: itemIdx,
                              child: Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 16,
                                  color: AppTheme.subtitleText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            // ── Add todo item input
            if (isTodo && !isCollapsed) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 36),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      color: AppTheme.subtitleText,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Thêm mục mới...',
                          hintStyle: TextStyle(
                            color: AppTheme.subtitleText,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        onSubmitted: (val) {
                          final cleanVal = val.trim();
                          if (cleanVal.isNotEmpty &&
                              !todoList.any((it) => it['text'] == cleanVal)) {
                            final updated = List.from(todoList)
                              ..add({'text': cleanVal, 'done': false});
                            DatabaseService()
                                .updateNoteOrDetail(id, {
                                  'todoItems': updated,
                                }, isItineraryDetail)
                                .then((_) => _loadData(silent: true));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Collapsed emoji display for notes
            if (!isTodo && isCollapsed && reactions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: reactions.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      final updated = List.from(reactions)..remove(emoji);
                      DatabaseService()
                          .updateNoteOrDetail(id, {
                            'reactions': updated,
                          }, isItineraryDetail)
                          .then((_) => _loadData(silent: true));
                    },
                    child: _emojiChip(emoji as String),
                  );
                }).toList(),
              ),
            ],

            // ── Toolbar (shown when expanded)
            if (!isCollapsed) ...[
              const SizedBox(height: 8),
              Divider(color: AppTheme.border, height: 1, thickness: 0.5),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: isTodo
                        // Todo left side: "Danh sách làm sẵn" button
                        ? GestureDetector(
                            onTap: () => _showTemplateBottomSheet(
                              id,
                              todoList,
                              isItineraryDetail,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.card_travel_outlined,
                                  color: AppTheme.subtitleText,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Danh sách làm sẵn',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.darkText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        // Note left side: emoji chips + picker button
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...reactions.map((emoji) {
                                return GestureDetector(
                                  onTap: () {
                                    final updated = List.from(reactions)
                                      ..remove(emoji);
                                    DatabaseService()
                                        .updateNoteOrDetail(id, {
                                          'reactions': updated,
                                        }, isItineraryDetail)
                                        .then((_) => _loadData(silent: true));
                                  },
                                  child: _emojiChip(emoji as String),
                                );
                              }),
                              // Emoji picker button
                              GestureDetector(
                                onTap: () => _showEmojiPickerSheet(
                                  id,
                                  reactions,
                                  isItineraryDetail,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Icon(
                                    Icons.sentiment_satisfied_alt_outlined,
                                    color: AppTheme.subtitleText,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  // Right: delete, drag, collapse
                  GestureDetector(
                    onTap: () => _removePlaceDetail(
                      id,
                      text,
                      isSavedPlace: !isItineraryDetail,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.subtitleText,
                        size: 18,
                      ),
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: listIdx,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        color: AppTheme.subtitleText,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emojiChip(String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 3),
          Text(
            '1',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPickerSheet(
    int noteId,
    List<dynamic> currentReactions,
    bool isItineraryDetail,
  ) {
    // Full emoji list organized by categories
    const Map<String, List<String>> emojiCategories = {
      'Mặt cười & cảm xúc': [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '🤣',
        '😂',
        '🙂',
        '😊',
        '😇',
        '🥰',
        '😍',
        '🤩',
        '😘',
        '😗',
        '😚',
        '😙',
        '🥲',
        '😋',
        '😛',
        '😜',
        '🤪',
        '😝',
        '🤑',
        '🤗',
        '🤭',
        '🫢',
        '🫣',
        '🤫',
        '🤔',
        '🫡',
        '🤐',
        '🤨',
        '😐',
        '😑',
        '😶',
        '😏',
        '😒',
        '🙄',
        '😬',
        '🤥',
        '😌',
        '😔',
        '😪',
        '🤤',
        '😴',
        '😷',
        '🤒',
        '🤕',
        '🤢',
        '🤮',
        '🤧',
        '🥵',
        '🥶',
        '🥴',
        '😵',
        '🤯',
        '🤠',
        '🥸',
        '😎',
        '🤓',
        '🧐',
        '😕',
        '😟',
        '🙁',
        '☹️',
        '😮',
        '😯',
        '😲',
        '😳',
        '🥺',
        '😦',
        '😧',
        '😨',
        '😰',
        '😥',
        '😢',
        '😭',
        '😱',
        '😖',
        '😣',
        '😞',
        '😓',
        '😩',
        '😫',
        '🥱',
        '😤',
        '😡',
        '😠',
        '🤬',
        '😈',
        '👿',
        '💀',
        '☠️',
        '💩',
        '🤡',
        '👹',
        '👺',
        '👻',
        '👽',
        '👾',
        '🤖',
      ],
      'Con người & cơ thể': [
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '🫱',
        '🫲',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞',
        '🫰',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '🖕',
        '👇',
        '☝️',
        '🫵',
        '👍',
        '👎',
        '✊',
        '👊',
        '🤛',
        '🤜',
        '👏',
        '🙌',
        '🫶',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '💪',
        '🦾',
        '🦿',
        '🦵',
        '🦶',
        '👂',
        '🦻',
        '👃',
        '🫀',
        '🫁',
        '🧠',
        '🦷',
        '🦴',
        '👀',
        '👁️',
        '👅',
        '👄',
        '🫦',
      ],
      'Du lịch & địa điểm': [
        '✈️',
        '🚀',
        '🛸',
        '🚁',
        '🛺',
        '🚂',
        '🚆',
        '🚇',
        '🚊',
        '🚝',
        '🚞',
        '🚋',
        '🚌',
        '🚍',
        '🚎',
        '🏎️',
        '🚑',
        '🚒',
        '🚓',
        '🚐',
        '🛻',
        '🚚',
        '🚛',
        '🚜',
        '🏍️',
        '🛵',
        '🛺',
        '🚲',
        '🛴',
        '🛹',
        '🛼',
        '🛷',
        '🚏',
        '🛣️',
        '🛤️',
        '🌍',
        '🌎',
        '🌏',
        '🗺️',
        '🧭',
        '🏔️',
        '⛰️',
        '🌋',
        '🗻',
        '🏕️',
        '🏖️',
        '🏜️',
        '🏝️',
        '🏞️',
        '🏟️',
        '🏛️',
        '🏗️',
        '🏘️',
        '🏠',
        '🏡',
        '🏢',
        '🏣',
        '🏤',
        '🏥',
        '🏦',
        '🏨',
        '🏩',
        '🏪',
        '🏫',
        '🏬',
        '🏭',
        '🏯',
        '🏰',
        '🗼',
        '🗽',
        '🗾',
        '🎌',
        '🏳️',
        '🏴',
        '🚩',
      ],
      'Ăn uống': [
        '🍏',
        '🍎',
        '🍊',
        '🍋',
        '🍌',
        '🍍',
        '🥭',
        '🍇',
        '🍓',
        '🫐',
        '🍈',
        '🍒',
        '🍑',
        '🥝',
        '🍅',
        '🫒',
        '🥥',
        '🥑',
        '🍆',
        '🥔',
        '🥕',
        '🌽',
        '🌶️',
        '🫑',
        '🥒',
        '🥬',
        '🥦',
        '🧄',
        '🧅',
        '🥜',
        '🫘',
        '🍞',
        '🥐',
        '🥖',
        '🫓',
        '🥨',
        '🥯',
        '🧀',
        '🥚',
        '🍳',
        '🧈',
        '🥞',
        '🧇',
        '🥓',
        '🥩',
        '🍗',
        '🍖',
        '🦴',
        '🌭',
        '🍔',
        '🍟',
        '🍕',
        '🫓',
        '🌮',
        '🌯',
        '🫔',
        '🥙',
        '🧆',
        '🥚',
        '🍱',
        '🍘',
        '🍙',
        '🍚',
        '🍛',
        '🍜',
        '🍝',
        '🍠',
        '🍢',
        '🍣',
        '🍤',
        '🍥',
        '🥮',
        '🍡',
        '🥟',
        '🥠',
        '🥡',
        '🦀',
        '🦞',
        '🦐',
        '🦑',
        '🦪',
        '🍦',
        '🍧',
        '🍨',
        '🍩',
        '🍪',
        '🎂',
        '🍰',
        '🧁',
        '🥧',
        '🍫',
        '🍬',
        '🍭',
        '🍮',
        '🍯',
        '☕',
        '🍵',
        '🧃',
        '🥤',
        '🧋',
        '🍶',
        '🍾',
        '🍷',
        '🍸',
        '🍹',
        '🍺',
        '🍻',
        '🥂',
        '🥃',
        '🫗',
      ],
      'Hoạt động': [
        '⚽',
        '🏀',
        '🏈',
        '⚾',
        '🥎',
        '🎾',
        '🏐',
        '🏉',
        '🥏',
        '🎱',
        '🪀',
        '🏓',
        '🏸',
        '🏒',
        '🥍',
        '🏏',
        '🪃',
        '🥅',
        '⛳',
        '🪁',
        '🤿',
        '🎣',
        '🤸',
        '🤼',
        '🤺',
        '🤾',
        '⛷️',
        '🏂',
        '🏋️',
        '🚵',
        '🚴',
        '🏊',
        '🤽',
        '🧗',
        '🏇',
        '🏆',
        '🥇',
        '🥈',
        '🥉',
        '🎖️',
        '🎗️',
        '🏅',
        '🎫',
        '🎟️',
        '🎪',
        '🎭',
        '🎨',
        '🖼️',
        '🎰',
        '🎲',
        '🧩',
        '🎮',
        '🕹️',
        '🎯',
        '🎳',
      ],
      'Ký hiệu & khác': [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❤️‍🔥',
        '❤️‍🩹',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '☮️',
        '✝️',
        '☪️',
        '🕉️',
        '✡️',
        '🔯',
        '🕎',
        '☯️',
        '☦️',
        '🛐',
        '⛎',
        '♈',
        '♉',
        '♊',
        '♋',
        '♌',
        '♍',
        '♎',
        '♏',
        '♐',
        '♑',
        '♒',
        '♓',
        '🆔',
        '⚛️',
        '🉑',
        '☢️',
        '☣️',
        '📵',
        '🚫',
        '⛔',
        '🔞',
        '📛',
        '🔰',
        '⭕',
        '✅',
        '☑️',
        '✔️',
        '❎',
        '🔱',
        '🔲',
        '🔳',
        '⬛',
        '⬜',
        '◼️',
        '◻️',
        '◾',
        '◽',
        '▪️',
        '▫️',
        '🔺',
        '🔻',
        '💠',
        '🔘',
        '🔵',
        '🟣',
        '⚫',
        '🟤',
        '🔴',
        '🟠',
        '🟡',
        '🟢',
        '🔶',
        '🔷',
        '🔸',
        '🔹',
        '🔊',
        '🔔',
        '🔕',
        '🎵',
        '🎶',
        '💡',
        '🔦',
        '🕯️',
        '💰',
        '💵',
        '💴',
        '💶',
        '💷',
        '💸',
        '💳',
        '🪙',
        '💹',
        '✉️',
        '📧',
        '📨',
        '📩',
        '📤',
        '📥',
        '📦',
        '📫',
        '📪',
        '📬',
        '📭',
        '📮',
        '🗳️',
        '✏️',
        '✒️',
        '🖊️',
        '🖋️',
        '📝',
        '📁',
        '📂',
        '🗂️',
        '📅',
        '📆',
        '🗒️',
        '🗓️',
        '📇',
        '📈',
        '📉',
        '📊',
        '📋',
        '📌',
        '📍',
        '🗺️',
        '📎',
        '🖇️',
        '✂️',
        '🗃️',
        '🗄️',
        '🗑️',
        '🔒',
        '🔓',
        '🔏',
        '🔐',
        '🔑',
        '🗝️',
        '🔨',
        '🪓',
        '⛏️',
        '⚒️',
        '🛠️',
        '🗡️',
        '⚔️',
        '🛡️',
        '🪃',
        '🔧',
        '🪛',
        '🔩',
        '⚙️',
        '🗜️',
        '⚖️',
        '🪝',
        '🔗',
        '⛓️',
        '🪤',
        '🧲',
        '🔋',
        '🪫',
        '🔌',
        '💻',
        '🖥️',
        '🖨️',
        '⌨️',
        '🖱️',
        '🖲️',
        '💾',
        '💿',
        '📀',
        '🧮',
        '🎥',
        '🎞️',
        '📽️',
        '🎬',
        '📺',
        '📷',
        '📸',
        '📹',
        '📼',
        '🔍',
        '🔎',
        '🕯️',
        '💡',
        '🔦',
        '🏮',
        '🪔',
        '📡',
        '🔭',
        '🔬',
        '🩺',
        '🩻',
        '🩹',
        '💊',
        '🩸',
        '🧬',
        '🦠',
        '🧫',
        '🧪',
        '⚗️',
        '🛁',
        '🚿',
        '🪥',
        '🧴',
        '🧷',
        '🧹',
        '🧺',
        '🧻',
        '🪣',
        '🧼',
        '🫧',
        '🪒',
        '🧽',
        '🪜',
        '🛒',
        '🚪',
        '🪞',
        '🪟',
        '🛏️',
        '🛋️',
        '🚽',
        '🪠',
        '🚰',
      ],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String? selectedCategory = emojiCategories.keys.first;
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: StatefulBuilder(
                builder: (ctx, setInner) {
                  selectedCategory ??= emojiCategories.keys.first;
                  final emojis = emojiCategories[selectedCategory]!;
                  return Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Close button
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 22,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                      // Category tabs
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: emojiCategories.keys.map((cat) {
                            final icons = const {
                              'Mặt cười & cảm xúc':
                                  Icons.sentiment_satisfied_alt,
                              'Con người & cơ thể': Icons.accessibility_new,
                              'Du lịch & địa điểm': Icons.flight,
                              'Ăn uống': Icons.restaurant,
                              'Hoạt động': Icons.sports_soccer,
                              'Ký hiệu & khác': Icons.flag,
                            };
                            final bool active = selectedCategory == cat;
                            return GestureDetector(
                              onTap: () =>
                                  setInner(() => selectedCategory = cat),
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppTheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  icons[cat] ?? Icons.emoji_emotions,
                                  size: 22,
                                  color: active ? Colors.white : Colors.black54,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const Divider(height: 1),
                      // Category label
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedCategory!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black45,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      // Emoji grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                                childAspectRatio: 1,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                              ),
                          itemCount: emojis.length,
                          itemBuilder: (_, i) {
                            final emoji = emojis[i];
                            final alreadySelected = currentReactions.contains(
                              emoji,
                            );
                            return GestureDetector(
                              onTap: () {
                                List<dynamic> updated;
                                if (alreadySelected) {
                                  updated = List.from(currentReactions)
                                    ..remove(emoji);
                                } else {
                                  updated = List.from(currentReactions)
                                    ..add(emoji);
                                }
                                DatabaseService()
                                    .updateNoteOrDetail(noteId, {
                                      'reactions': updated,
                                    }, isItineraryDetail)
                                    .then((_) {
                                      _loadData(silent: true);
                                      Navigator.pop(ctx);
                                    });
                              },
                              child: Container(
                                decoration: alreadySelected
                                    ? BoxDecoration(
                                        color: AppTheme.primary.withAlpha(30),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.primary.withAlpha(80),
                                        ),
                                      )
                                    : null,
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaceTags(Map<String, dynamic> place) {
    List<dynamic> tags = [];

    if (place['category'] != null && place['category']['name'] != null) {
      tags = [place['category']['name']];
    } else {
      tags = ['Điểm tham quan'];
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map(
            (cat) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                cat.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSavedPlaceCard(Map<String, dynamic> detail, int index) {
    final int id = detail['id'] as int;
    final bool isCollapsed = !_expandedPlaceIds.contains(id);

    if (detail['place'] == null && detail['noteText'] != null) {
      final sectionDetails = _savedPlaces
          .where((d) => d['section'] == detail['section'])
          .toList();
      return Container(
        key: ValueKey('note_$id'),
        child: _buildSavedNoteCard(detail, index + 1, index, sectionDetails),
      );
    }

    final place = detail['place'] ?? {};
    final categoryName = place['category']?['name'] ?? 'Điểm tham quan';
    final String name = place['name'] ?? 'Địa điểm';
    final String image = place['image'] ?? '';

    String? extraInfo;
    if (place['openingHours'] != null) {
      extraInfo = TimeUtils.getOpeningHoursText(place['openingHours']);
    }

    return VisibilityDetector(
      key: Key("place_${detail['id']}"),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.6) {
          if (_focusedPlaceId != detail['id']) {
            setState(() {
              _focusedPlaceId = detail['id'] as int?;
            });
            if (_isMapExpanded &&
                place['latitude'] != null &&
                place['longitude'] != null) {
              final lat = (place['latitude'] as num).toDouble();
              final lon = (place['longitude'] as num).toDouble();
              // Offset latitude by -0.005 so marker is in the upper visible half
              _mapController.move(LatLng(lat - 0.005, lon), 15.0);
            }
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (_isSelectionMode && detail['id'] != null) {
            setState(() {
              if (_selectedItemIds.contains(id)) {
                _selectedItemIds.remove(id);
              } else {
                _selectedItemIds.add(id);
              }
            });
          } else {
            setState(() {
              if (isCollapsed) {
                _expandedPlaceIds.add(id);
              } else {
                _expandedPlaceIds.remove(id);
              }
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Slidable(
            key: ValueKey('saved_place_${detail['id']}'),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.25,
              children: [
                CustomSlidableAction(
                  onPressed: (context) => _removePlaceDetail(
                    detail['id'],
                    name,
                    isSavedPlace: true,
                  ),
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(20),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text(
                        'Xóa',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                        _sectionColors[detail['section']] ??
                                        const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child:
                                      (_sectionIcons[detail['section']] ==
                                              null ||
                                          _sectionIcons[detail['section']]
                                                  ?.codePoint ==
                                              Icons.looks_one_rounded.codePoint)
                                      ? Text(
                                          '$index',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        )
                                      : Icon(
                                          _sectionIcons[detail['section']],
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                      if (extraInfo != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time_rounded,
                                              color: AppTheme.subtitleText,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                extraInfo,
                                                style: TextStyle(
                                                  color:
                                                      extraInfo
                                                          .toLowerCase()
                                                          .contains('đóng cửa')
                                                      ? Colors.red
                                                      : AppTheme.subtitleText,
                                                  fontWeight:
                                                      extraInfo
                                                          .toLowerCase()
                                                          .contains('đóng cửa')
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: _buildPlaceTags(place),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  image,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.image, size: 80),
                                ),
                              ),
                              (_isSelectionMode || !isCollapsed)
                                  ? IgnorePointer(
                                      ignoring: _isSelectionMode,
                                      child: Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: _selectedItemIds.contains(
                                            detail['id'],
                                          ),
                                          onChanged: _isSelectionMode
                                              ? (_) {}
                                              : (val) {
                                                  setState(() {
                                                    _isSelectionMode = true;
                                                    if (val == true) {
                                                      _selectedItemIds.add(
                                                        detail['id'] as int,
                                                      );
                                                    } else {
                                                      _selectedItemIds.remove(
                                                        detail['id'] as int,
                                                      );
                                                    }
                                                  });
                                                },
                                          activeColor: AppTheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                        ],
                      ),
                      if (detail['noteText'] != null &&
                          detail['noteText'].toString().trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              detail['noteText'].toString().trim(),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                        ),
                      if (!isCollapsed)
                        InlinePlaceWhiteCardExtension(
                          detail: detail,
                          isItineraryDetail: false,
                          onUpdate: () => _loadData(silent: true),
                          onShowEmojiPicker: () {
                            // Pass the current local state of reactions if needed, or get from detail
                            _showEmojiPickerSheet(
                              detail['id'],
                              detail['reactions'] is List
                                  ? detail['reactions']
                                  : (detail['reactions'] is String
                                        ? (json.decode(detail['reactions'])
                                              as List)
                                        : []),
                              false,
                            );
                          },
                        ),
                      if (!isCollapsed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.subtitleText,
                                ),
                                onPressed: () => _removePlaceDetail(
                                  detail['id'],
                                  name,
                                  isSavedPlace: true,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.drag_indicator,
                                  color: AppTheme.subtitleText,
                                ),
                                onPressed: () => _showSectionStyleSheet(
                                  context,
                                  detail['section'],
                                  initialTabIndex: 1,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: AppTheme.subtitleText,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _expandedPlaceIds.remove(id);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isCollapsed)
                  InlinePlaceBottomInfo(
                    place: place,
                    onOpenMap: () {
                      if (place['latitude'] != null &&
                          place['longitude'] != null) {
                        final lat = (place['latitude'] as num).toDouble();
                        final lon = (place['longitude'] as num).toDouble();
                        setState(() {
                          _isMapExpanded = true;
                          _selectedMapPlace = detail;
                        });
                        // Offset latitude by -0.005 so marker is in the upper visible half
                        _mapController.move(LatLng(lat - 0.005, lon), 15.0);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= TAB 1: TỔNG QUAN =================
  Widget _buildOverviewTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _sectionNames.length + 1,
            itemBuilder: (context, index) {
              if (index == _sectionNames.length) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text(
                          'Danh sách mới',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _createNewSection,
                      ),
                    ],
                  ),
                );
              }
              final section = _sectionNames[index];
              final searchController = _searchControllers[section]!;
              final searchResultsList = _searchResults[section] ?? [];

              // Filter details belonging to this section
              final sectionDetails = _savedPlaces
                  .where((d) => d['section'] == section)
                  .toList();

              // Get list of place IDs already saved in this section
              final savedPlaceIds = sectionDetails
                  .map((d) => d['placeId'] as int?)
                  .whereType<int>()
                  .toSet();

              // Filter recommended places: only show if not already saved in this section
              final availableRecommendations = _allPlaces
                  .where((place) => !savedPlaceIds.contains(place['id']))
                  .toList();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: AppTheme.premiumCardDecoration(radius: 0),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.zero,
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    controller: _expansionControllers.putIfAbsent(
                      section,
                      () => ExpansibleController(),
                    ),
                    initiallyExpanded: true,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    iconColor: AppTheme.darkText,
                    collapsedIconColor: AppTheme.subtitleText,
                    leading: _isSelectionMode
                        ? Checkbox(
                            value: _selectedSections.contains(section),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedSections.add(section);
                                  for (var place in _savedPlaces) {
                                    if (place['section'] == section &&
                                        place['id'] != null) {
                                      _selectedItemIds.add(place['id'] as int);
                                    }
                                  }
                                } else {
                                  _selectedSections.remove(section);
                                  for (var place in _savedPlaces) {
                                    if (place['section'] == section &&
                                        place['id'] != null) {
                                      _selectedItemIds.remove(
                                        place['id'] as int,
                                      );
                                    }
                                  }
                                }
                              });
                            },
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )
                        : Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.darkText,
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_itineraryData['isGuide'] == true)
                          Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                              ),
                              child: PopupMenuButton<String>(
                                offset: const Offset(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                color: Colors.white,
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _sectionTypes[section] == 'ITINERARY'
                                            ? 'Hành trình'
                                            : 'Danh sách',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.darkText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 20,
                                        color: AppTheme.darkText,
                                      ),
                                    ],
                                  ),
                                ),
                                onSelected: (value) {
                                  setState(() {
                                    _sectionTypes[section] = value;
                                  });
                                  _syncSectionsToDatabase();
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'LIST',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.format_list_bulleted_rounded,
                                          size: 20,
                                          color: AppTheme.darkText,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Danh sách',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.darkText,
                                          ),
                                        ),
                                        if (_sectionTypes[section] !=
                                            'ITINERARY')
                                          const Spacer(),
                                        if (_sectionTypes[section] !=
                                            'ITINERARY')
                                          Icon(
                                            Icons.check_rounded,
                                            size: 20,
                                            color: AppTheme.darkText,
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'ITINERARY',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 20,
                                          color: AppTheme.darkText,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Hành trình',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.darkText,
                                          ),
                                        ),
                                        if (_sectionTypes[section] ==
                                            'ITINERARY')
                                          const Spacer(),
                                        if (_sectionTypes[section] ==
                                            'ITINERARY')
                                          Icon(
                                            Icons.check_rounded,
                                            size: 20,
                                            color: AppTheme.darkText,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Theme(
                          data: Theme.of(context).copyWith(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                          ),
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: AppTheme.subtitleText,
                            ),
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: Colors.white,
                            elevation: 4,
                            onSelected: (value) {
                              if (value == 'edit') {
                                setState(() {
                                  _editingSection = section;
                                  _sectionTitleController.text = section;
                                });
                                _sectionTitleFocusNode.requestFocus();
                              } else if (value == 'color') {
                                _showSectionStyleSheet(context, section);
                              } else if (value == 'reorder') {
                                _showSectionStyleSheet(
                                  context,
                                  section,
                                  initialTabIndex: 1,
                                );
                              } else if (value == 'collapse') {
                                for (var controller
                                    in _expansionControllers.values) {
                                  if (controller.isExpanded) {
                                    controller.collapse();
                                  }
                                }
                              } else if (value == 'delete') {
                                setState(() {
                                  _sectionNames.remove(section);
                                  _sectionColors.remove(section);
                                  _sectionIcons.remove(section);
                                  _savedPlaces.removeWhere(
                                    (place) => place['section'] == section,
                                  );
                                  _expansionControllers.remove(section);
                                });
                                final itId = _itineraryData['id'] as int;
                                DatabaseService().deleteItinerarySection(
                                  itId,
                                  section,
                                );
                                DatabaseService().deleteSavedPlacesBySection(
                                  itId,
                                  section,
                                );
                                _syncSectionsToDatabase();
                              } else if (value == 'select_all') {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedSections.add(section);
                                  for (var place in _savedPlaces) {
                                    if (place['section'] == section &&
                                        place['id'] != null) {
                                      _selectedItemIds.add(place['id'] as int);
                                    }
                                  }
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tính năng đang phát triển ($value)',
                                    ),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                      size: 20,
                                      color: AppTheme.darkText,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Chỉnh sửa tiêu đề',
                                      style: TextStyle(
                                        color: AppTheme.darkText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'color',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.palette_rounded,
                                      size: 20,
                                      color: AppTheme.darkText,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Thay đổi màu sắc hoặc biểu tượng',
                                        style: TextStyle(
                                          color: AppTheme.darkText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'select_all',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_box_outlined,
                                      size: 20,
                                      color: AppTheme.darkText,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Chọn tất cả',
                                      style: TextStyle(
                                        color: AppTheme.darkText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'collapse',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.close_fullscreen_rounded,
                                      size: 20,
                                      color: AppTheme.darkText,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Thu gọn tất cả các phần',
                                        style: TextStyle(
                                          color: AppTheme.darkText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: AppTheme.darkText,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Xóa phần',
                                      style: TextStyle(
                                        color: AppTheme.darkText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'reorder',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.menu_rounded,
                                      size: 20,
                                      color: AppTheme.darkText,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Sắp xếp lại các phần',
                                      style: TextStyle(
                                        color: AppTheme.darkText,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    title: _editingSection == section
                        ? TextField(
                            controller: _sectionTitleController,
                            focusNode: _sectionTitleFocusNode,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.darkText,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (newValue) =>
                                _saveSectionTitle(section, newValue),
                            onTapOutside: (_) => _saveSectionTitle(
                              section,
                              _sectionTitleController.text,
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              setState(() {
                                _editingSection = section;
                                _sectionTitleController.text = section;
                              });
                              Future.delayed(
                                const Duration(milliseconds: 100),
                                () {
                                  if (mounted) {
                                    _sectionTitleFocusNode.requestFocus();
                                  }
                                },
                              );
                            },
                            child: Text(
                              section,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Saved places list inside this section at the top
                            if (sectionDetails.isNotEmpty) ...[
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sectionDetails.length,
                                buildDefaultDragHandles: false,
                                onReorder: (oldIndex, newIndex) async {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  if (oldIndex == newIndex) return;

                                  // Optimistic local UI update
                                  final items = List<Map<String, dynamic>>.from(
                                    sectionDetails,
                                  );
                                  final movedItem = items.removeAt(oldIndex);
                                  items.insert(newIndex, movedItem);

                                  setState(() {
                                    _savedPlaces = _savedPlaces.map((sp) {
                                      final updatedIdx = items.indexWhere(
                                        (it) => it['id'] == sp['id'],
                                      );
                                      if (updatedIdx != -1) {
                                        return {...sp, 'sortOrder': updatedIdx};
                                      }
                                      return sp;
                                    }).toList();
                                  });

                                  // DB update
                                  for (int i = 0; i < items.length; i++) {
                                    await DatabaseService()
                                        .updateSavedItemOrder(
                                          items[i]['id'] as int,
                                          i,
                                        );
                                  }
                                  await _loadData(silent: true);
                                },
                                itemBuilder: (context, sIdx) {
                                  final detail = sectionDetails[sIdx];
                                  final key = ValueKey(detail['id']);
                                  if (detail['place'] == null &&
                                      detail['noteText'] != null) {
                                    return Container(
                                      key: key,
                                      child: _buildSavedNoteCard(
                                        detail,
                                        sIdx + 1,
                                        sIdx,
                                        sectionDetails,
                                      ),
                                    );
                                  } else {
                                    int placeNumber = 0;
                                    for (int i = 0; i <= sIdx; i++) {
                                      if (sectionDetails[i]['place'] != null) {
                                        placeNumber++;
                                      }
                                    }
                                    return Container(
                                      key: key,
                                      child: _buildSavedPlaceCard(
                                        detail,
                                        placeNumber,
                                      ),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Search field & custom icon buttons
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: TextField(
                                      readOnly: true,
                                      onTap: () {
                                        _tabController.animateTo(
                                          _itineraryData['isGuide'] == true
                                              ? 1
                                              : 3,
                                        );
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Thêm địa điểm',
                                        hintStyle: TextStyle(
                                          color: AppTheme.hintText,
                                          fontSize: 13,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.location_on_outlined,
                                          color: AppTheme.subtitleText,
                                          size: 20,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _addNoteInline(section),
                                  child: Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.description_outlined,
                                      color: AppTheme.darkText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _addChecklistInline(section),
                                  child: Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.checklist_rounded,
                                      color: AppTheme.darkText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Display Local Search results inline
                            if (searchResultsList.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 150,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: searchResultsList.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, sIdx) {
                                    final p = searchResultsList[sIdx];
                                    return ListTile(
                                      leading: Icon(
                                        Icons.location_on,
                                        color: AppTheme.primary,
                                      ),
                                      title: Text(
                                        p['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        p['address'] ?? '',
                                        style: const TextStyle(fontSize: 11),
                                        maxLines: 1,
                                      ),
                                      onTap: () {
                                        searchController.clear();
                                        setState(() {
                                          _searchResults[section] = [];
                                        });
                                        _addPlace(p, section);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            Text(
                              'Địa điểm được đề xuất',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.subtitleText,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Recommendations Horizontal List
                            SizedBox(
                              height: 70,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: availableRecommendations.length + 1,
                                itemBuilder: (context, rIdx) {
                                  if (rIdx == availableRecommendations.length) {
                                    // "Khám phá" card at the end
                                    return GestureDetector(
                                      onTap: () => _tabController.animateTo(
                                        _itineraryData['isGuide'] == true
                                            ? 1
                                            : 3,
                                      ),
                                      child: Container(
                                        width: 120,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.border,
                                            style: BorderStyle.solid,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.redAccent,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Khám phá',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: AppTheme.darkText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  final place = availableRecommendations[rIdx];
                                  return GestureDetector(
                                    onTap: () => _addPlace(place, section),
                                    child: Container(
                                      width: 160,
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              place['image'] ?? '',
                                              width: 42,
                                              height: 42,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.image,
                                                    size: 42,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  place['name'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryPeach,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              size: 12,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Saved places list moved to the top of accordion content
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= TAB 2: HÀNH TRÌNH =================
  Widget _buildPopupMenuAddPlaceButton(String dayLabel, Color customColor) {
    final overviewDetails = _savedPlaces;

    if (overviewDetails.isEmpty) {
      return GestureDetector(
        onTap: () {
          _showPremiumNotification(
            title: 'Lưu ý',
            message: 'Vui lòng thêm địa điểm ở Tab Tổng quan trước!',
            icon: Icons.info_outline_rounded,
            color: AppTheme.primary,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.location_on_rounded, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'Thêm địa điểm',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final existingPlaceIds = <int>{};
    for (var d in _details) {
      if (d['placeId'] != null) {
        existingPlaceIds.add(d['placeId'] as int);
      }
    }

    final Map<int, Map<String, dynamic>> uniquePlacesMap = {};
    for (var d in overviewDetails) {
      final p = d['place'];
      if (p != null && p['id'] != null) {
        final int placeId = p['id'] as int;
        if (!existingPlaceIds.contains(placeId) &&
            !uniquePlacesMap.containsKey(placeId)) {
          final placeWithSection = Map<String, dynamic>.from(p);
          placeWithSection['section_name'] = d['section'];
          uniquePlacesMap[placeId] = placeWithSection;
        }
      }
    }
    final List<Map<String, dynamic>> savedPlaces = uniquePlacesMap.values
        .toList();

    return GestureDetector(
      onTap: () {
        _showAddPlaceBottomSheet(dayLabel, savedPlaces);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text(
              'Thêm địa điểm',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPlaceBottomSheet(
    String dayLabel,
    List<Map<String, dynamic>> savedPlaces,
  ) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredPlaces = savedPlaces.where((p) {
              final name = (p['name'] as String?)?.toLowerCase() ?? '';
              final address = (p['address'] as String?)?.toLowerCase() ?? '';
              final q = searchQuery.toLowerCase();
              return name.contains(q) || address.contains(q);
            }).toList();

            return SafeArea(
              child: Container(
                padding: const EdgeInsets.only(top: 12),
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      'Thêm địa điểm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setModalState(() {
                              searchQuery = val;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Tìm kiếm theo tên hoặc địa chỉ',
                            hintStyle: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Subtitle
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Chọn nhanh từ các danh sách của bạn',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // List
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredPlaces.length,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemBuilder: (context, index) {
                          final place = filteredPlaces[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.location_on,
                              color: AppTheme.darkText,
                            ),
                            title: Text(
                              place['name'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppTheme.darkText,
                              ),
                            ),
                            subtitle: Text(
                              place['section_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _addPlace(place, dayLabel);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppTheme.darkText, size: 20),
      ),
    );
  }

  Map<String, dynamic> _getMockTravelInfo(
    Map<String, dynamic> p1,
    Map<String, dynamic> p2,
  ) {
    final double? lat1 = (p1['latitude'] as num?)?.toDouble();
    final double? lon1 = (p1['longitude'] as num?)?.toDouble();
    final double? lat2 = (p2['latitude'] as num?)?.toDouble();
    final double? lon2 = (p2['longitude'] as num?)?.toDouble();

    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      final dx = (lon1 - lon2) * 111.0 * math.cos(lat1 * math.pi / 180.0);
      final dy = (lat1 - lat2) * 111.0;
      final dist = math.sqrt(dx * dx + dy * dy);
      final durationMinutes = (dist * 2.0).round();
      final distStr = dist.toStringAsFixed(1).replaceAll('.', ',');
      return {
        'duration': durationMinutes > 0 ? durationMinutes : 5,
        'distance': distStr,
      };
    }
    return {'duration': 8, 'distance': '3,5'};
  }

  Widget _buildTravelSeparator(
    Map<String, dynamic> p1,
    Map<String, dynamic> p2,
  ) {
    final travelInfo = _getMockTravelInfo(p1, p2);
    final duration = travelInfo['duration'];
    final distance = travelInfo['distance'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showTransportModeSheet(),
            child: Row(
              children: [
                Icon(
                  Icons.directions_run_rounded,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$duration phút • $distance km',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.grey[600],
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final lat1 = p1['latitude'];
              final lng1 = p1['longitude'];
              final lat2 = p2['latitude'];
              final lng2 = p2['longitude'];

              if (lat1 != null &&
                  lng1 != null &&
                  lat2 != null &&
                  lng2 != null) {
                final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&origin=$lat1,$lng1&destination=$lat2,$lng2',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể mở Google Maps')),
                  );
                }
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Không đủ thông tin toạ độ để chỉ đường'),
                  ),
                );
              }
            },
            child: const Text(
              'Chỉ đường',
              style: TextStyle(
                color: Color(0xFF5C5CFF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boxWidth = constraints.constrainWidth();
                const dashWidth = 4.0;
                const dashSpace = 4.0;
                final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
                return Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(dashCount, (_) {
                    return SizedBox(
                      width: dashWidth,
                      height: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.grey[300]),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransportModeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chế độ vận chuyển',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTransportModeOption(
                    icon: Icons.directions_car_filled_rounded,
                    title: 'Lái xe',
                    info: '4 phút • 2,3 km',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildTransportModeOption(
                    icon: Icons.directions_transit_rounded,
                    title: 'Phương tiện công cộng',
                    info: '32 phút • 2,3 km',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildTransportModeOption(
                    icon: Icons.directions_walk_rounded,
                    title: 'Đi bộ',
                    info: '28 phút • 2,3 km',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildTransportModeOption(
                    icon: Icons.visibility_off_outlined,
                    title: 'Ẩn chỉ đường',
                    info: null,
                    onTap: () => Navigator.pop(context),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 32),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showDefaultTransportModeSheet();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Thay đổi mặc định cho tất cả các địa điểm',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkText,
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
          ),
        );
      },
    );
  }

  void _showDefaultTransportModeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        'Chế độ vận chuyển mặc định',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDefaultModeOption(
                    title: 'Phương tiện công cộng + đi bộ khoảng cách ngắn',
                    isSelected: false,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDefaultModeOption(
                    title: 'Lái xe + đi bộ khoảng cách ngắn',
                    isSelected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransportModeOption({
    required IconData icon,
    required String title,
    String? info,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.darkText, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: AppTheme.darkText),
              ),
            ),
            if (info != null)
              Text(
                info,
                style: TextStyle(fontSize: 14, color: AppTheme.subtitleText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultModeOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: AppTheme.darkText),
              ),
            ),
            if (isSelected)
              Icon(Icons.check, color: AppTheme.darkText, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetailsColumn(
    List<Map<String, dynamic>> dayDetails,
    Color customColor,
  ) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex -= 1;
        final updated = List.from(dayDetails);
        final item = updated.removeAt(oldIndex);
        updated.insert(newIndex, item);

        for (int i = 0; i < updated.length; i++) {
          DatabaseService().updateNoteOrDetail(updated[i]['id'], {
            'sortOrder': i,
          }, true);
        }
        Future.delayed(
          const Duration(milliseconds: 100),
          () => _loadData(silent: true),
        );
      },
      children: List.generate(dayDetails.length, (idx) {
        final detail = dayDetails[idx];
        final int id = detail['id'] as int;
        final bool isCollapsed = !_expandedPlaceIds.contains(id);

        Widget childCard;
        if (detail['place'] == null && detail['noteText'] != null) {
          childCard = Container(
            key: ValueKey('note_$id'),
            child: _buildSavedNoteCard(detail, idx + 1, idx, dayDetails),
          );
        } else {
          final place = detail['place'] ?? {};
          final name = place['name'] ?? '';

          String? extraInfo;
          if (name.toLowerCase().contains('ueno') ||
              name.toLowerCase().contains('sở thú ueno')) {
            extraInfo = 'Đóng cửa T2';
          } else if (place['openingHours'] != null) {
            extraInfo = TimeUtils.getOpeningHoursText(place['openingHours']);
          }

          final card = VisibilityDetector(
            key: Key("itinerary_place_vis_${detail['id']}"),
            onVisibilityChanged: (info) {
              if (info.visibleFraction > 0.6) {
                if (_focusedPlaceId != detail['id']) {
                  setState(() {
                    _focusedPlaceId = detail['id'] as int?;
                  });
                  if (_isMapExpanded &&
                      place['latitude'] != null &&
                      place['longitude'] != null) {
                    final lat = (place['latitude'] as num).toDouble();
                    final lon = (place['longitude'] as num).toDouble();
                    // Offset latitude by -0.005 so marker is in the upper visible half
                    _mapController.move(LatLng(lat - 0.005, lon), 15.0);
                  }
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Slidable(
                key: ValueKey('itinerary_place_${detail['id']}'),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    CustomSlidableAction(
                      onPressed: (context) =>
                          _removePlaceDetail(detail['id'], place['name'] ?? ''),
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(20),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Xóa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isCollapsed) {
                        _expandedPlaceIds.add(id);
                      } else {
                        _expandedPlaceIds.remove(id);
                      }
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(8),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: customColor,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          (() {
                                            int placeNumber = 0;
                                            for (int i = 0; i <= idx; i++) {
                                              if (dayDetails[i]['place'] !=
                                                  null) {
                                                placeNumber++;
                                              }
                                            }
                                            return '$placeNumber';
                                          })(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: AppTheme.darkText,
                                              ),
                                            ),
                                            if (extraInfo != null) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    color:
                                                        AppTheme.subtitleText,
                                                    size: 12,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    extraInfo,
                                                    style: TextStyle(
                                                      color:
                                                          extraInfo
                                                              .toLowerCase()
                                                              .contains(
                                                                'đóng cửa',
                                                              )
                                                          ? Colors.red
                                                          : AppTheme
                                                                .subtitleText,
                                                      fontWeight:
                                                          extraInfo
                                                              .toLowerCase()
                                                              .contains(
                                                                'đóng cửa',
                                                              )
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: _buildPlaceTags(place),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child:
                                          (place['image'] != null &&
                                              place['image']
                                                  .toString()
                                                  .isNotEmpty)
                                          ? Image.network(
                                              place['image'],
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.image,
                                                    size: 80,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.image,
                                              size: 80,
                                              color: Colors.grey,
                                            ),
                                    ),
                                    (_isSelectionMode || !isCollapsed)
                                        ? IgnorePointer(
                                            ignoring: _isSelectionMode,
                                            child: Container(
                                              margin: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              width: 24,
                                              height: 24,
                                              child: Checkbox(
                                                value: _selectedItemIds
                                                    .contains(detail['id']),
                                                onChanged: _isSelectionMode
                                                    ? (_) {}
                                                    : (val) {
                                                        setState(() {
                                                          _isSelectionMode =
                                                              true;
                                                          if (val == true) {
                                                            _selectedItemIds
                                                                .add(
                                                                  detail['id']
                                                                      as int,
                                                                );
                                                          } else {
                                                            _selectedItemIds
                                                                .remove(
                                                                  detail['id']
                                                                      as int,
                                                                );
                                                          }
                                                        });
                                                      },
                                                activeColor: AppTheme.primary,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ],
                            ),
                            if (detail['noteText'] != null &&
                                detail['noteText'].toString().trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    detail['noteText'].toString().trim(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                ),
                              ),
                            if (!isCollapsed)
                              InlinePlaceWhiteCardExtension(
                                detail: detail,
                                isItineraryDetail: true,
                                onUpdate: () => _loadData(silent: true),
                                onShowEmojiPicker: () {
                                  _showEmojiPickerSheet(
                                    detail['id'],
                                    detail['reactions'] is List
                                        ? detail['reactions']
                                        : (detail['reactions'] is String
                                              ? (json.decode(
                                                      detail['reactions'],
                                                    )
                                                    as List)
                                              : []),
                                    true,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      if (!isCollapsed)
                        InlinePlaceBottomInfo(
                          place: place,
                          onOpenMap: () {
                            if (place['latitude'] != null &&
                                place['longitude'] != null) {
                              final lat = (place['latitude'] as num).toDouble();
                              final lon = (place['longitude'] as num)
                                  .toDouble();
                              setState(() {
                                _isMapExpanded = true;
                                _selectedMapPlace = detail;
                              });
                              // Offset latitude by -0.005 so marker is in the upper visible half
                              _mapController.move(
                                LatLng(lat - 0.005, lon),
                                15.0,
                              );
                            }
                          },
                        ),
                      if (!isCollapsed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: AppTheme.subtitleText,
                                ),
                                onPressed: () => _removePlaceDetail(
                                  detail['id'],
                                  name,
                                  isSavedPlace: false,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.drag_indicator,
                                  color: AppTheme.subtitleText,
                                ),
                                onPressed: () => _showItineraryStyleSheet(
                                  context,
                                  initialTabIndex: 1,
                                  initialDayIndex:
                                      (detail['day'] as int? ?? 1) - 1,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: AppTheme.subtitleText,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _expandedPlaceIds.remove(id);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );

          childCard = card;
        }

        Widget? travelSeparator;
        // If the NEXT item exists and is a Place, we render the travel separator at the bottom of THIS item
        if (idx + 1 < dayDetails.length &&
            dayDetails[idx + 1]['place'] != null) {
          Map<String, dynamic>? prevPlaceRaw;
          for (int j = idx; j >= 0; j--) {
            if (dayDetails[j]['place'] != null) {
              prevPlaceRaw = dayDetails[j]['place'] as Map<String, dynamic>?;
              break;
            }
          }
          if (prevPlaceRaw != null) {
            travelSeparator = _buildTravelSeparator(
              Map<String, dynamic>.from(prevPlaceRaw),
              Map<String, dynamic>.from(
                dayDetails[idx + 1]['place'] as Map<String, dynamic>,
              ),
            );
          }
        }

        bool hasPrevPlace = false;
        for (int j = idx - 1; j >= 0; j--) {
          if (dayDetails[j]['place'] != null) {
            hasPrevPlace = true;
            break;
          }
        }

        bool hasNextPlace = false;
        for (int j = idx + 1; j < dayDetails.length; j++) {
          if (dayDetails[j]['place'] != null) {
            hasNextPlace = true;
            break;
          }
        }

        return Container(
          key: ValueKey('item_$id'),
          child: Stack(
            children: [
              // Top line (for Place)
              if (detail['place'] != null && hasPrevPlace)
                Positioned(
                  top: 0,
                  height: 24,
                  left: 15,
                  child: Container(
                    width: 2,
                    color: customColor.withOpacity(0.3),
                  ),
                ),
              // Bottom line (for Place)
              if (detail['place'] != null && hasNextPlace)
                Positioned(
                  top: 36,
                  bottom: 0,
                  left: 15,
                  child: Container(
                    width: 2,
                    color: customColor.withOpacity(0.3),
                  ),
                ),
              // Dot (for Place)
              if (detail['place'] != null)
                Positioned(
                  top: 24,
                  left: 10,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: customColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              // Continuous line (for Note)
              if (detail['place'] == null && hasPrevPlace && hasNextPlace)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 15,
                  child: Container(
                    width: 2,
                    color: customColor.withOpacity(0.3),
                  ),
                ),
              // The content
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    childCard,
                    if (travelSeparator != null) travelSeparator,
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildItineraryTab() {
    final int totalDays = (_itineraryData['days'] as num?)?.toInt() ?? 1;

    // Build the horizontal chips bar
    final Widget horizontalBar = Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Edit Calendar Button
          GestureDetector(
            onTap: _changeTripStartDate,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.darkText,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Day Chips
          ...List.generate(totalDays, (index) {
            final isSelected = _activeDayIndex == index;
            final label = _getDayLabel(index);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _activeDayIndex = index;
                  });
                  final key = _dayKeys[index];
                  if (key != null && key.currentContext != null) {
                    Scrollable.ensureVisible(
                      key.currentContext!,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.darkText : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.darkText,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );

    // Build the vertical days list
    return Column(
      children: [
        horizontalBar,
        Expanded(
          child: ListView.builder(
            controller: _itineraryScrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: totalDays,
            itemBuilder: (context, index) {
              final dayLabel = 'Ngày ${index + 1}';
              final dayDetails = _details
                  .where((d) => d['day'] == (index + 1))
                  .toList();
              final daySavedItems = _savedPlaces
                  .where(
                    (d) => d['section'] == dayLabel && d['noteText'] != null,
                  )
                  .toList();
              final dayKey = _dayKeys.putIfAbsent(index, () => GlobalKey());
              final customColor = _dayColors[index] ?? AppTheme.primary;
              final subtitle = _daySubtitles[index] ?? '';
              final isCollapsed = _dayCollapsed[index] == true;

              return Container(
                key: dayKey,
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gray separator before this day card (except first)
                    if (index > 0)
                      Container(height: 10, color: Colors.grey[100]),

                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Day Header Row
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _dayCollapsed[index] = !isCollapsed;
                              });
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  isCollapsed
                                      ? Icons.keyboard_arrow_right_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.darkText,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getDayLabel(index),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _editDaySubtitle(index),
                                    child: Text(
                                      subtitle.isNotEmpty
                                          ? subtitle
                                          : 'Thêm tiêu đề phụ',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subtitle.isNotEmpty
                                            ? AppTheme.darkText
                                            : Colors.grey[400],
                                        fontWeight: subtitle.isNotEmpty
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.more_horiz_rounded,
                                    color: AppTheme.subtitleText,
                                  ),
                                  onPressed: () => _showDayOptionsSheet(index),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          if (!isCollapsed) ...[
                            Builder(
                              builder: (context) {
                                final placesOnly = dayDetails
                                    .where(
                                      (d) =>
                                          d['placeId'] != null &&
                                          d['place'] != null,
                                    )
                                    .toList();
                                final placesCount = placesOnly.length;

                                if (placesCount == 0) {
                                  return Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          _showPremiumNotification(
                                            title: 'Tự động điền',
                                            message:
                                                'Đang tạo lịch trình tự động từ AI...',
                                            icon: Icons.bolt_rounded,
                                            color: AppTheme.primary,
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bolt_rounded,
                                              size: 16,
                                              color: customColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tự động điền',
                                              style: TextStyle(
                                                color: customColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        '·',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          _showPremiumNotification(
                                            title: 'Tối ưu lộ trình',
                                            message:
                                                'Tính năng tối ưu lộ trình thông minh!',
                                            icon: Icons.alt_route_rounded,
                                            color: customColor,
                                          );
                                        },
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.alt_route_rounded,
                                              size: 16,
                                              color: customColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tối ưu lộ trình',
                                              style: TextStyle(
                                                color: customColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  String optimizeText = 'Tối ưu lộ trình';
                                  if (placesCount >= 2) {
                                    int totalDuration = 0;
                                    double totalDistance = 0;
                                    for (
                                      int i = 0;
                                      i < placesOnly.length - 1;
                                      i++
                                    ) {
                                      final p1 = Map<String, dynamic>.from(
                                        placesOnly[i]['place'] as Map,
                                      );
                                      final p2 = Map<String, dynamic>.from(
                                        placesOnly[i + 1]['place'] as Map,
                                      );
                                      final info = _getMockTravelInfo(p1, p2);
                                      totalDuration += info['duration'] as int;
                                      final dist =
                                          double.tryParse(
                                            (info['distance'] as String)
                                                .replaceAll(',', '.'),
                                          ) ??
                                          0.0;
                                      totalDistance += dist;
                                    }
                                    optimizeText =
                                        'Tối ưu lộ trình · $totalDuration phút, ${totalDistance.toStringAsFixed(1).replaceAll('.', ',')} km';
                                  }

                                  return GestureDetector(
                                    onTap: () {
                                      _showPremiumNotification(
                                        title: 'Tối ưu lộ trình',
                                        message:
                                            'Tính năng tối ưu lộ trình thông minh!',
                                        icon: Icons.route_outlined,
                                        color: const Color(0xFF0284C7),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.route_outlined,
                                          color: Color(0xFF0284C7),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          optimizeText,
                                          style: const TextStyle(
                                            color: Color(0xFF0284C7),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 16),

                            // Day details Column (replaces _buildDayListView)
                            if (dayDetails.isNotEmpty) ...[
                              _buildDayDetailsColumn(dayDetails, customColor),
                              const SizedBox(height: 16),
                            ],

                            // Day notes and checklists
                            if (daySavedItems.isNotEmpty) ...[
                              ...List.generate(daySavedItems.length, (sIdx) {
                                final detail = daySavedItems[sIdx];
                                return _buildSavedNoteCard(
                                  detail,
                                  sIdx + 1,
                                  sIdx,
                                  daySavedItems,
                                );
                              }),
                              const SizedBox(height: 16),
                            ],

                            // Search & Options Input Row (Moved to bottom)
                            Row(
                              children: [
                                // Input Box (Add Location button)
                                Expanded(
                                  child: _buildPopupMenuAddPlaceButton(
                                    dayLabel,
                                    customColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Notes button
                                _buildDayIconButton(
                                  icon: Icons.description_outlined,
                                  onPressed: () => _addNoteInline(dayLabel),
                                ),
                                const SizedBox(width: 8),
                                // List View button
                                _buildDayIconButton(
                                  icon: Icons.checklist_rounded,
                                  onPressed: () =>
                                      _addChecklistInline(dayLabel),
                                ),
                              ],
                            ),
                          ],
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
    );
  }

  // ================= TAB 3: KHÁM PHÁ =================
  Widget _buildExploreTab() {
    if (_isLoadingExplore) {
      return const Center(child: CircularProgressIndicator());
    }

    final destination = _itineraryData['destination'] ?? 'Cần Thơ';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: destination,
                            border: InputBorder.none,
                            hintStyle: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Posts List
        if (_explorePosts.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('Không tìm thấy bài viết khám phá nào.'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final post = _explorePosts[index];
                return ExplorePostCard(
                  post: post,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExplorePostDetailScreen(
                          postId: post['id'] as int,
                          title: post['title'] ?? 'Chi tiết',
                        ),
                      ),
                    ).then((_) {
                      _fetchExplorePosts();
                    });
                  },
                );
              }, childCount: _explorePosts.length),
            ),
          ),
      ],
    );
  }

  // ================= TAB 4: CHI PHÍ ($) =================
  Widget _buildExpensesTab() {
    // Determine target budget
    final budgetLimit = (_itineraryData['budget'] as num?)?.toInt() ?? 3000000;

    // Calculate sum of place costs if they have prices (mocked/parsed)
    int placeCosts = 0;
    for (var detail in _details) {
      final p = detail['place'] ?? {};
      final priceStr = p['price']?.toString() ?? '';
      if (priceStr.contains('Miễn phí') || priceStr.isEmpty) {
        placeCosts += 0;
      } else {
        placeCosts += 50000; // Mock admission fee if not free
      }
    }

    int customSpent = 0;
    for (var exp in _customExpenses) {
      customSpent += (exp['amount'] as num).toInt();
    }

    final totalSpent = placeCosts + customSpent;
    final progress = totalSpent / budgetLimit;
    final percent = (progress * 100).clamp(0.0, 100.0).toStringAsFixed(0);

    String formatDong(int amount) {
      if (amount >= 1000000) {
        double m = amount / 1000000.0;
        return '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)} Tr';
      }
      return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng chi tiêu',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ngân sách: ${formatDong(budgetLimit)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  formatDong(totalSpent),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: progress > 1.0
                              ? Colors.redAccent
                              : AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progress > 1.0
                          ? 'Vượt quá ngân sách!'
                          : 'Đã sử dụng $percent% ngân sách',
                      style: TextStyle(
                        color: progress > 1.0
                            ? Colors.redAccent
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Còn lại: ${formatDong((budgetLimit - totalSpent).clamp(0, 999999999))}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chi tiết chi tiêu', style: AppTheme.sectionTitleStyle),
              TextButton.icon(
                icon: Icon(Icons.add, size: 16, color: AppTheme.primary),
                label: Text(
                  'Thêm chi phí',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _showAddExpenseDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Places cost section
          if (placeCosts > 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'VÉ THAM QUAN / DỊCH VỤ ĐỊA ĐIỂM',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: AppTheme.subtitleText,
                ),
              ),
            ),
            ..._details
                .where((d) {
                  final p = d['place'] ?? {};
                  final priceStr = p['price']?.toString() ?? '';
                  return !priceStr.contains('Miễn phí') && priceStr.isNotEmpty;
                })
                .map((d) {
                  final p = d['place'] ?? {};
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: AppTheme.premiumCardDecoration(radius: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p['name'] ?? 'Vé tham quan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatDong(50000),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.darkText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            const SizedBox(height: 16),
          ],

          // Custom Expenses Section
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'CHI PHÍ TỰ THÊM',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: AppTheme.subtitleText,
              ),
            ),
          ),
          if (_customExpenses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              alignment: Alignment.center,
              child: Text(
                'Chưa có chi tiêu tự thêm nào. Hãy nhấn "+ Thêm chi phí"!',
                style: TextStyle(fontSize: 12, color: AppTheme.subtitleText),
              ),
            )
          else
            ...List.generate(_customExpenses.length, (idx) {
              final item = _customExpenses[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: AppTheme.premiumCardDecoration(radius: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['date'] ?? '',
                            style: TextStyle(
                              color: AppTheme.subtitleText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatDong(item['amount']),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkText,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _customExpenses.removeAt(idx);
                        });
                        _saveExpensesToPrefs();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Bottom sheet widget for picking from pre-made checklist templates
class _ChecklistTemplateSheet extends StatefulWidget {
  final int checklistId;
  final List<dynamic> currentItems;
  final void Function(List<String> newItems) onAddItems;

  const _ChecklistTemplateSheet({
    required this.checklistId,
    required this.currentItems,
    required this.onAddItems,
  });

  @override
  State<_ChecklistTemplateSheet> createState() =>
      _ChecklistTemplateSheetState();
}

class _ChecklistTemplateSheetState extends State<_ChecklistTemplateSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _templates = [];
  // Selected category ids
  final Set<int> _selectedCategories = {};
  // Expanded category ids
  final Set<int> _expandedCategories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final data = await DatabaseService().fetchChecklistTemplates();
    if (mounted) {
      setState(() {
        _templates = data;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getForTab(String tabType) {
    return _templates
        .where((t) => t['tabType'] == tabType || t['tabtype'] == tabType)
        .toList();
  }

  void _addSelected() {
    final List<String> newItems = [];
    for (final cat in _templates) {
      final catId = cat['id'] as int;
      if (_selectedCategories.contains(catId)) {
        final items = cat['items'] as List? ?? [];
        for (final item in items) {
          newItems.add(item['name'] as String);
        }
      }
    }
    widget.onAddItems(newItems);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Thêm từ một mẫu',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: _addSelected,
                  child: Text(
                    'Thêm',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Chọn các mục để thêm vào danh sách kiểm tra của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Danh sách đóng gói'),
                Tab(text: 'Nhiệm vụ trước'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCategoryList('packing'),
                      _buildCategoryList('todo'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(String tabType) {
    final cats = _getForTab(tabType);
    if (cats.isEmpty) {
      return const Center(
        child: Text('Không có mẫu nào', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cats.length,
      itemBuilder: (context, idx) {
        final cat = cats[idx];
        final catId = cat['id'] as int;
        final catName = cat['name'] as String;
        final items = cat['items'] as List? ?? [];
        final isSelected = _selectedCategories.contains(catId);
        final isExpanded = _expandedCategories.contains(catId);

        return Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCategories.remove(catId);
                  } else {
                    _expandedCategories.add(catId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.black54,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        catName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedCategories.remove(catId);
                          } else {
                            _selectedCategories.add(catId);
                          }
                        });
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected ? AppTheme.primary : Colors.grey,
                            width: isSelected ? 0 : 1.5,
                          ),
                          color: isSelected
                              ? AppTheme.primary
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ...items.map((item) {
                final itemName = item['name'] as String;
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 48,
                    right: 20,
                    bottom: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        itemName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const Divider(height: 1, indent: 20, endIndent: 20),
          ],
        );
      },
    );
  }
}
