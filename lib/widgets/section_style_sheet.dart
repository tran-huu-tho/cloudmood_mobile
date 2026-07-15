import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionStyleSheet extends StatefulWidget {
  final List<String> sections;
  final List<Map<String, dynamic>> savedPlaces;
  final String initialSection;
  final Map<String, Color> sectionColors;
  final Map<String, IconData> sectionIcons;
  final int initialTabIndex;
  final Function(
    List<String> newSections,
    List<Map<String, dynamic>> newPlaces,
    Map<String, Color> newColors,
    Map<String, IconData> newIcons,
  )
  onSaved;

  const SectionStyleSheet({
    super.key,
    required this.sections,
    required this.savedPlaces,
    required this.initialSection,
    required this.sectionColors,
    required this.sectionIcons,
    this.initialTabIndex = 0,
    required this.onSaved,
  });

  @override
  State<SectionStyleSheet> createState() => _SectionStyleSheetState();
}

class _SectionStyleSheetState extends State<SectionStyleSheet> {
  int _selectedTabIndex = 0;

  late List<String> _sections;
  late List<Map<String, dynamic>> _savedPlaces;
  late String _activeSection;
  late Map<String, Color> _sectionColors;
  late Map<String, IconData> _sectionIcons;
  final List<Map<String, dynamic>> _flattenedItems = [];

  final List<Color> _colors = [
    Colors.green,
    Colors.tealAccent,
    Colors.lightBlue,
    Colors.blue,
    Colors.deepPurple,
    Colors.pinkAccent,
    Colors.orange,
    Colors.orangeAccent,
    Colors.green[800]!,
    Colors.teal[800]!,
    Colors.blue[800]!,
    Colors.indigo[800]!,
    Colors.purple[800]!,
    Colors.pink[800]!,
    Colors.brown,
    Colors.brown[700]!,
  ];

  final List<IconData> _icons = [
    Icons.looks_one_rounded,
    Icons.push_pin,
    Icons.directions_car,
    Icons.local_cafe,
    Icons.train,
    Icons.directions_bus,
    Icons.directions_boat,
    Icons.location_on,
    Icons.camera_alt,
    Icons.coffee,
    Icons.shopping_bag,
    Icons.restaurant,
    Icons.wine_bar,
    Icons.landscape,
    Icons.sailing,
    Icons.check,
  ];

  Color _selectedColor = Colors.indigoAccent;
  IconData _selectedIcon = Icons.palette;

  @override
  void initState() {
    super.initState();
    _sections = List.from(widget.sections);
    _savedPlaces = List.from(widget.savedPlaces);
    _sectionColors = Map.from(widget.sectionColors);
    _sectionIcons = Map.from(widget.sectionIcons);
    _activeSection = widget.initialSection;
    _selectedTabIndex = widget.initialTabIndex;

    // Ensure the active section has a color/icon
    _selectedColor = _sectionColors[_activeSection] ?? Colors.indigoAccent;
    _selectedIcon = _sectionIcons[_activeSection] ?? Icons.looks_one_rounded;

    _buildFlattenedItems();
  }

  void _updateActiveStyle() {
    setState(() {
      _selectedColor = _sectionColors[_activeSection] ?? Colors.indigoAccent;
      _selectedIcon = _sectionIcons[_activeSection] ?? Icons.looks_one_rounded;
    });
  }

  void _buildFlattenedItems() {
    _flattenedItems.clear();
    for (var section in _sections) {
      _flattenedItems.add({'type': 'header', 'data': section});
      final places = _savedPlaces
          .where((p) => p['section'] == section)
          .toList();
      for (var p in places) {
        _flattenedItems.add({'type': 'place', 'data': p});
      }
    }
  }

  void _handleReorderTab1(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;

      final movedItem = _flattenedItems.removeAt(oldIndex);
      _flattenedItems.insert(newIndex, movedItem);

      List<String> newSections = [];
      List<Map<String, dynamic>> newPlaces = [];
      String? currentSection;

      for (var item in _flattenedItems) {
        if (item['type'] == 'header') {
          currentSection = item['data'] as String;
          newSections.add(currentSection);
        } else if (item['type'] == 'place') {
          final placeData = item['data'] as Map<String, dynamic>;
          if (currentSection != null) {
            placeData['section'] = currentSection;
            newPlaces.add(placeData);
          } else if (_sections.isNotEmpty) {
            placeData['section'] = _sections.first;
            newPlaces.add(placeData);
          }
        }
      }

      _sections = newSections;
      _savedPlaces = newPlaces;
      _buildFlattenedItems();
    });
  }

  void _handleSave() {
    widget.onSaved(_sections, _savedPlaces, _sectionColors, _sectionIcons);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 80), // spacer for balance
              Text(
                _selectedTabIndex == 0 ? 'Sắp xếp & màu sắc' : 'Sắp xếp lại',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              TextButton(
                onPressed: _handleSave,
                child: const Text(
                  'Hoàn thành',
                  style: TextStyle(
                    color: AppTheme.subtitleText,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented Control Custom
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 0
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _selectedTabIndex == 0
                            ? [
                                const BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Các phần',
                        style: TextStyle(
                          fontWeight: _selectedTabIndex == 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _selectedTabIndex == 1
                            ? [
                                const BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Địa điểm',
                        style: TextStyle(
                          fontWeight: _selectedTabIndex == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: AppTheme.darkText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content
          if (_selectedTabIndex == 0) ...[
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (oldIndex < newIndex) newIndex -= 1;
                          final item = _sections.removeAt(oldIndex);
                          _sections.insert(newIndex, item);
                          _buildFlattenedItems();
                        });
                      },
                      children: _sections.asMap().entries.map((entry) {
                        final index = entry.key;
                        final section = entry.value;
                        final isSelected = section == _activeSection;
                        return GestureDetector(
                          key: ValueKey('tab0_$section'),
                          onTap: () {
                            setState(() {
                              _activeSection = section;
                              _selectedColor =
                                  _sectionColors[section] ??
                                  Colors.indigoAccent;
                              _selectedIcon =
                                  _sectionIcons[section] ??
                                  Icons.looks_one_rounded;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _selectedColor.withValues(alpha: 0.1)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _selectedColor.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isSelected
                                      ? _selectedColor
                                      : (_sectionColors[section] ??
                                            Colors.grey[300]),
                                  child: Icon(
                                    isSelected
                                        ? _selectedIcon
                                        : (_sectionIcons[section] ??
                                              Icons.looks_one_rounded),
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    section,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 16,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(
                                    Icons.drag_indicator,
                                    color: AppTheme.subtitleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Màu sắc',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colors
                          .map(
                            (c) => GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = c;
                                  _sectionColors[_activeSection] = c;
                                });
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: c,
                                child: _selectedColor == c
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Biểu tượng',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _icons
                          .map(
                            (i) => GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedIcon = i;
                                  _sectionIcons[_activeSection] = i;
                                });
                              },
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: _selectedIcon == i
                                    ? _selectedColor
                                    : Colors.grey[200],
                                child: Icon(
                                  i,
                                  color: _selectedIcon == i
                                      ? Colors.white
                                      : AppTheme.darkText,
                                  size: 20,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ] else ...[
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: _handleReorderTab1,
                children: _flattenedItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;

                  if (item['type'] == 'header') {
                    final section = item['data'] as String;
                    return Container(
                      key: ValueKey('header_$section'),
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        section,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.darkText,
                        ),
                      ),
                    );
                  } else {
                    final place = item['data'] as Map<String, dynamic>;

                    String placeName = 'Địa điểm';
                    if (place['place'] != null &&
                        place['place']['name'] != null) {
                      placeName = place['place']['name'];
                    } else if (place['noteText'] != null) {
                      final String text = place['noteText'];
                      if (text.startsWith('[TODO] ')) {
                        final title = text.substring(7).trim();
                        placeName = title.isEmpty
                            ? 'Danh sách công việc'
                            : title;
                      } else {
                        placeName = text.isEmpty ? 'Ghi chú' : text;
                      }
                    }

                    return Container(
                      key: ValueKey('place_${place['id']}'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              placeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.darkText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(
                              Icons.drag_indicator,
                              color: AppTheme.subtitleText,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
