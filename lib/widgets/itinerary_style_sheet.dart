import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ItineraryStyleSheet extends StatefulWidget {
  final int daysCount;
  final List<Map<String, dynamic>> details;
  final Map<int, Color> dayColors;
  final int initialTabIndex;
  final int initialDayIndex;
  final Function(
    List<Map<String, dynamic>> newDetails,
    Map<int, Color> newColors,
  ) onSaved;

  const ItineraryStyleSheet({
    super.key,
    required this.daysCount,
    required this.details,
    required this.dayColors,
    this.initialTabIndex = 0,
    this.initialDayIndex = 0,
    required this.onSaved,
  });

  @override
  State<ItineraryStyleSheet> createState() => _ItineraryStyleSheetState();
}

class ItineraryFlatItem {
  final String id;
  final String type; // 'header', 'place', 'note'
  final String title;
  final String dayLabel;
  final Map<String, dynamic> rawData;

  ItineraryFlatItem({
    required this.id,
    required this.type,
    required this.title,
    required this.dayLabel,
    required this.rawData,
  });
}

class _ItineraryStyleSheetState extends State<ItineraryStyleSheet> {
  int _selectedTabIndex = 0;

  late List<String> _daysList;
  late List<Map<String, dynamic>> _details;
  late Map<int, Color> _dayColors;
  late String _activeDayLabel;
  List<ItineraryFlatItem> _flattenedItems = [];

  final List<Color> _colors = [
    Colors.green, Colors.tealAccent, Colors.lightBlue, Colors.blue, Colors.deepPurple, Colors.pinkAccent, Colors.orange, Colors.orangeAccent,
    Colors.green[800]!, Colors.teal[800]!, Colors.blue[800]!, Colors.indigo[800]!, Colors.purple[800]!, Colors.pink[800]!, Colors.brown, Colors.brown[700]!,
  ];

  Color _selectedColor = Colors.indigoAccent;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    _daysList = List.generate(widget.daysCount, (i) => 'Ngày ${i + 1}');
    _details = List.from(widget.details);
    _dayColors = Map.from(widget.dayColors);
    
    if (widget.initialDayIndex >= 0 && widget.initialDayIndex < _daysList.length) {
      _activeDayLabel = _daysList[widget.initialDayIndex];
    } else {
      _activeDayLabel = _daysList.isNotEmpty ? _daysList.first : 'Ngày 1';
    }

    final activeDayIdx = _daysList.indexOf(_activeDayLabel);
    _selectedColor = _dayColors[activeDayIdx] ?? AppTheme.primary;

    _buildFlattenedItems();
  }

  void _buildFlattenedItems() {
    _flattenedItems.clear();
    for (var dayLabel in _daysList) {
      _flattenedItems.add(ItineraryFlatItem(
        id: 'header_$dayLabel',
        type: 'header',
        title: dayLabel,
        dayLabel: dayLabel,
        rawData: {},
      ));

      final int dayIdx = int.parse(dayLabel.replaceAll('Ngày ', ''));
      
      // Items for this day (from _details)
      final items = _details.where((d) => d['day'] == dayIdx).toList();
      for (var d in items) {
        if (d['placeId'] == null && d['noteText'] != null) {
          final String text = d['noteText'] ?? '';
          String displayTitle = 'Ghi chú';
          if (text.startsWith('[TODO] ')) {
            final t = text.substring(7).trim();
            displayTitle = t.isEmpty ? 'Danh sách công việc' : t;
          } else {
            displayTitle = text.isEmpty ? 'Ghi chú' : text;
          }
          _flattenedItems.add(ItineraryFlatItem(
            id: 'note_${d['id']}',
            type: 'note',
            title: displayTitle,
            dayLabel: dayLabel,
            rawData: d,
          ));
        } else {
          final pName = d['place']?['name'] ?? 'Địa điểm';
          _flattenedItems.add(ItineraryFlatItem(
            id: 'place_${d['id']}',
            type: 'place',
            title: pName,
            dayLabel: dayLabel,
            rawData: d,
          ));
        }
      }
    }
  }

  void _handleReorderTab1(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;

      final movedItem = _flattenedItems.removeAt(oldIndex);
      _flattenedItems.insert(newIndex, movedItem);

      List<Map<String, dynamic>> newDetails = [];

      String? currentDayLabel;
      int currentSortOrder = 0;

      for (var item in _flattenedItems) {
        if (item.type == 'header') {
          currentDayLabel = item.dayLabel;
          currentSortOrder = 0;
        } else {
          if (currentDayLabel != null) {
            final int dayIdx = int.parse(currentDayLabel.replaceAll('Ngày ', ''));
            final raw = Map<String, dynamic>.from(item.rawData);
            raw['sortOrder'] = currentSortOrder++;
            raw['day'] = dayIdx; // Works for both places and notes since both use 'day' column now!
            newDetails.add(raw);
          }
        }
      }

      _details = newDetails;
      _buildFlattenedItems();
    });
  }

  void _handleSave() {
    // If days were reordered in Tab 0, we must reconstruct the day mappings!
    // We map day indices based on their order in _daysList.
    final Map<int, Color> updatedColors = {};
    for (int i = 0; i < _daysList.length; i++) {
      final oldDayLabel = _daysList[i];
      final oldDayIdx = int.parse(oldDayLabel.replaceAll('Ngày ', '')) - 1;
      updatedColors[i] = _dayColors[oldDayIdx] ?? AppTheme.primary;
    }

    // Remap places and notes to match the index of their day headers
    List<Map<String, dynamic>> finalDetails = [];

    for (int i = 0; i < _daysList.length; i++) {
      final oldDayLabel = _daysList[i];
      final oldDayIdx = int.parse(oldDayLabel.replaceAll('Ngày ', ''));
      final newDayIdx = i + 1;

      // Remap details day
      final dayPlaces = _details.where((d) => d['day'] == oldDayIdx).toList();
      for (var p in dayPlaces) {
        final pCopy = Map<String, dynamic>.from(p);
        pCopy['day'] = newDayIdx;
        finalDetails.add(pCopy);
      }
    }

    widget.onSaved(finalDetails, updatedColors);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 80),
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
                child: const Text('Hoàn thành', style: TextStyle(color: AppTheme.subtitleText, fontWeight: FontWeight.normal)),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                        color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _selectedTabIndex == 0
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('Ngày', style: TextStyle(
                        fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.darkText,
                      )),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _selectedTabIndex == 1
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('Địa điểm', style: TextStyle(
                        fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                        color: AppTheme.darkText,
                      )),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                          final item = _daysList.removeAt(oldIndex);
                          _daysList.insert(newIndex, item);
                          _buildFlattenedItems();
                        });
                      },
                      children: _daysList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final dayLabel = entry.value;
                        final isSelected = dayLabel == _activeDayLabel;
                        
                        final oldDayIdx = int.parse(dayLabel.replaceAll('Ngày ', '')) - 1;
                        final displayColor = _dayColors[oldDayIdx] ?? AppTheme.primary;

                        return GestureDetector(
                          key: ValueKey('tab0_$dayLabel'),
                          onTap: () {
                            setState(() {
                              _activeDayLabel = dayLabel;
                              _selectedColor = displayColor;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? _selectedColor.withOpacity(0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? _selectedColor.withOpacity(0.3) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: displayColor,
                                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    dayLabel,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 16,
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_indicator, color: AppTheme.subtitleText),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Màu sắc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colors.map((c) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedColor = c;
                            final activeDayIdx = int.parse(_activeDayLabel.replaceAll('Ngày ', '')) - 1;
                            _dayColors[activeDayIdx] = c;
                          });
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: c,
                          child: _selectedColor.value == c.value ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                        ),
                      )).toList(),
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

                  if (item.type == 'header') {
                    return Container(
                      key: ValueKey(item.id),
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.darkText),
                      ),
                    );
                  } else {
                    return Container(
                      key: ValueKey(item.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.type == 'place' ? Icons.location_on_rounded : Icons.description_outlined,
                            color: AppTheme.subtitleText,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: AppTheme.darkText, fontWeight: FontWeight.w500),
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_indicator, color: AppTheme.subtitleText, size: 20),
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
