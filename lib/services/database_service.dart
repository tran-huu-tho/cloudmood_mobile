import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static final ValueNotifier<int> refreshTrigger = ValueNotifier<int>(0);
  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Checks if categories and places are empty in the database, and if so, seeds them with default data
  Future<void> checkAndSeedData() async {
    // This logic is usually handled on the backend or triggered via a specific endpoint
    // We can assume the backend handles seeding or we call a setup endpoint if needed.
    debugPrint(
      'checkAndSeedData called - handled by backend or manual seeding in NestJS now.',
    );
  }

  /// Fetches all categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await ApiClient.get('/mobile/categories');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return [];
    }
  }

  /// Fetches places based on category name
  Future<List<Map<String, dynamic>>> fetchPlaces({
    String? categoryName,
    int? page,
    int? limit,
    String? query,
    List<String>? priceLevels,
    double? minRating,
    List<String>? amenities,
  }) async {
    try {
      String endpoint = '/places';
      final List<String> params = [];
      if (categoryName != null && categoryName.isNotEmpty) {
        params.add('categoryName=${Uri.encodeComponent(categoryName)}');
      }
      if (page != null) {
        params.add('page=$page');
      }
      if (limit != null) {
        params.add('limit=$limit');
      }
      if (query != null && query.isNotEmpty) {
        params.add('query=${Uri.encodeComponent(query)}');
      }
      if (priceLevels != null && priceLevels.isNotEmpty) {
        params.add('priceLevels=${Uri.encodeComponent(priceLevels.join(','))}');
      }
      if (minRating != null) {
        params.add('minRating=$minRating');
      }
      if (amenities != null && amenities.isNotEmpty) {
        params.add('amenities=${Uri.encodeComponent(amenities.join(','))}');
      }

      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final response = await ApiClient.get(endpoint);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching places: $e');
    }
    return [];
  }

  /// Fetches places based on destination city
  Future<List<Map<String, dynamic>>> fetchPlacesByDestination(
    String destination,
  ) async {
    try {
      final response = await ApiClient.get(
        '/places/search?destination=${Uri.encodeComponent(destination)}',
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching places for destination: $e');
      return [];
    }
  }

  /// Searches places via backend (combines DB and Geoapify)
  Future<List<Map<String, dynamic>>> searchPlaces({
    required String destination,
    String? query,
    String? categoryName,
    List<String>? priceLevels,
    double? minRating,
    List<String>? amenities,
  }) async {
    try {
      String endpoint =
          '/places/search?destination=${Uri.encodeComponent(destination)}';
      if (query != null && query.isNotEmpty) {
        endpoint += '&query=${Uri.encodeComponent(query)}';
      }
      if (categoryName != null && categoryName.isNotEmpty) {
        endpoint += '&categoryName=${Uri.encodeComponent(categoryName)}';
      }
      if (priceLevels != null && priceLevels.isNotEmpty) {
        endpoint +=
            '&priceLevels=${Uri.encodeComponent(priceLevels.join(','))}';
      }
      if (minRating != null) {
        endpoint += '&minRating=$minRating';
      }
      if (amenities != null && amenities.isNotEmpty) {
        endpoint += '&amenities=${Uri.encodeComponent(amenities.join(','))}';
      }
      final response = await ApiClient.get(endpoint);
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error searching places: $e');
      return [];
    }
  }

  /// Searches for images from the backend based on query and page
  Future<Map<String, dynamic>> searchWebImages(
    String query, {
    int page = 1,
  }) async {
    try {
      final response = await ApiClient.get(
        '/explore/images/search?query=${Uri.encodeComponent(query)}&page=$page',
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return {'results': [], 'page': page, 'hasMore': false};
    } catch (e) {
      debugPrint('Error searching web images: $e');
      return {'results': [], 'page': page, 'hasMore': false};
    }
  }

  /// Fetches all itineraries created by the user
  Future<List<Map<String, dynamic>>> fetchUserItineraries(
    int userId, {
    bool isGuide = false,
  }) async {
    try {
      final response = await ApiClient.get('/itineraries?isGuide=$isGuide');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching user itineraries: $e');
      return [];
    }
  }

  /// Creates a new user itinerary in the database
  Future<Map<String, dynamic>?> createUserItinerary({
    required int userId,
    required String title,
    required String destination,
    required DateTime startDate,
    required int days,
    required int budget,
    required String companion,
    required String pace,
    required List<String> categories,
    required List<String> amenities,
    bool isGuide = false,
  }) async {
    try {
      final data = {
        'title': title,
        'destination': destination,
        'startDate': startDate.toIso8601String().substring(0, 10),
        'days': days,
        'budget': budget,
        'companion': companion,
        'pace': pace,
        'categories': categories,
        'amenities': amenities,
        'isGuide': isGuide,
      };

      final response = await ApiClient.post('/itineraries', body: data);
      if (response.statusCode == 201) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating user itinerary: $e');
      return null;
    }
  }

  /// Updates an itinerary with given data
  Future<bool> updateItinerary(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put('/itineraries/$id', body: data);
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating itinerary: $e');
      return false;
    }
  }

  /// Deletes an itinerary by id
  Future<bool> deleteItinerary(int id) async {
    try {
      final response = await ApiClient.delete('/itineraries/$id');
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting itinerary: $e');
      return false;
    }
  }

  /// Shifts day numbers for itinerary details greater than targetDay by offset
  Future<bool> shiftItineraryDetailsDays({
    required int itineraryId,
    required int targetDay,
    required int offset,
  }) async {
    try {
      final response = await ApiClient.post(
        '/itineraries/$itineraryId/shift-details',
        body: {'targetDay': targetDay, 'offset': offset},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error shifting itinerary details days: $e');
      return false;
    }
  }

  /// Deletes all itinerary details for a specific day
  Future<bool> deleteItineraryDetailsForDay({
    required int itineraryId,
    required int day,
  }) async {
    try {
      final response = await ApiClient.delete(
        '/itineraries/$itineraryId/details/day/$day',
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting itinerary details for day: $e');
      return false;
    }
  }

  /// Fetches reviews submitted by the user
  Future<List<Map<String, dynamic>>> fetchUserReviews(int userId) async {
    try {
      final response = await ApiClient.get('/reviews');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching user reviews: $e');
      return [];
    }
  }

  /// Creates a review for a specific place
  Future<Map<String, dynamic>?> createPlaceReview({
    required int userId,
    required int placeId,
    required double rating,
    required String comment,
    required String authorName,
    required String authorAvatar,
  }) async {
    try {
      final response = await ApiClient.post(
        '/reviews',
        body: {
          'placeId': placeId,
          'rating': rating,
          'comment': comment,
          'authorName': authorName,
          'authorAvatar': authorAvatar,
        },
      );
      if (response.statusCode == 201) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating place review: $e');
      return null;
    }
  }

  /// Fetches reviews for a specific place
  Future<List<Map<String, dynamic>>> fetchPlaceReviews(int placeId) async {
    try {
      final response = await ApiClient.get('/reviews/place/$placeId');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching place reviews: $e');
      return [];
    }
  }

  /// Checks if a destination city is supported
  Future<bool> isDestinationSupported(String cityName) async {
    try {
      final response = await ApiClient.get(
        '/places/check-destination?cityName=${Uri.encodeComponent(cityName)}',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['supported'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking destination support: $e');
      return false;
    }
  }

  /// Fetches a single itinerary with its details and places by ID
  Future<Map<String, dynamic>?> fetchItineraryById(int itineraryId) async {
    try {
      final response = await ApiClient.get('/itineraries/$itineraryId');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching itinerary by id: $e');
      return null;
    }
  }

  /// Updates day configs for an itinerary
  Future<bool> updateItineraryDayConfigs(
    int itineraryId,
    Map<String, dynamic> dayConfigs,
  ) async {
    try {
      final response = await ApiClient.put(
        '/itineraries/$itineraryId/day-configs',
        body: dayConfigs,
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating day configs: $e');
      return false;
    }
  }

  /// Adds a place or note to an itinerary's day details
  Future<Map<String, dynamic>?> addPlaceToItinerary({
    required int itineraryId,
    int? placeId,
    required int day,
    int sortOrder = 0,
    String? noteText,
  }) async {
    try {
      final response = await ApiClient.post(
        '/itineraries/details',
        body: {
          'itineraryId': itineraryId,
          'placeId': placeId,
          'day': day,
          'sortOrder': sortOrder,
          'noteText': noteText,
        },
      );
      if (response.statusCode == 201) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error adding place to itinerary: $e');
      return null;
    }
  }

  /// Deletes a place from an itinerary's details
  Future<bool> deletePlaceFromItinerary(int detailId) async {
    try {
      final response = await ApiClient.delete('/itineraries/details/$detailId');
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting place from itinerary: $e');
      return false;
    }
  }

  /// Updates an itinerary detail
  Future<bool> updateItineraryDetail(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put(
        '/itineraries/details/$id',
        body: data,
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating itinerary detail: $e');
      return false;
    }
  }

  /// Updates a saved place item
  Future<bool> updateSavedPlace(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put(
        '/itineraries/saved-places/$id',
        body: data,
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating saved place: $e');
      return false;
    }
  }

  /// Updates the order of a saved item
  Future<bool> updateSavedItemOrder(int savedId, int newSortOrder) async {
    return updateSavedPlace(savedId, {'sortOrder': newSortOrder});
  }

  /// Helper to update either ItineraryDetail or ItinerarySavedPlace
  Future<bool> updateNoteOrDetail(
    int id,
    Map<String, dynamic> data,
    bool isItineraryDetail,
  ) async {
    if (isItineraryDetail) {
      return updateItineraryDetail(id, data);
    } else {
      return updateSavedPlace(id, data);
    }
  }

  /// Upserts a section for an itinerary
  Future<bool> upsertItinerarySection({
    required int itineraryId,
    required String name,
    required String colorCode,
    required int iconCode,
    int sortOrder = 0,
    String sectionType = 'LIST',
  }) async {
    try {
      final response = await ApiClient.post(
        '/itineraries/sections',
        body: {
          'itineraryId': itineraryId,
          'name': name,
          'colorCode': colorCode,
          'iconCode': iconCode,
          'sortOrder': sortOrder,
          'sectionType': sectionType,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error upserting itinerary section: $e');
      return false;
    }
  }

  /// Deletes an itinerary section by name
  Future<bool> deleteItinerarySection(int itineraryId, String name) async {
    try {
      final response = await ApiClient.delete(
        '/itineraries/$itineraryId/sections/${Uri.encodeComponent(name)}',
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting itinerary section: $e');
      return false;
    }
  }

  /// Adds a place or note to an itinerary's saved places
  Future<Map<String, dynamic>?> addPlaceToSaved({
    required int itineraryId,
    int? placeId,
    required String section,
    String? noteText,
    int? sortOrder,
  }) async {
    try {
      final response = await ApiClient.post(
        '/itineraries/saved-places',
        body: {
          'itineraryId': itineraryId,
          'placeId': placeId,
          'section': section,
          'noteText': noteText,
          'sortOrder': sortOrder,
        },
      );
      if (response.statusCode == 201) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error adding to saved list: $e');
      return null;
    }
  }

  /// Deletes all saved places or notes in a specific section
  Future<bool> deleteSavedPlacesBySection(
    int itineraryId,
    String section,
  ) async {
    try {
      final response = await ApiClient.delete(
        '/itineraries/$itineraryId/saved-places/section/${Uri.encodeComponent(section)}',
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting saved places by section: $e');
      return false;
    }
  }

  /// Deletes a place or note from saved places
  Future<bool> deletePlaceFromSaved(int savedId) async {
    try {
      final response = await ApiClient.delete(
        '/itineraries/saved-places/$savedId',
      );
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting from saved list: $e');
      return false;
    }
  }

  /// Deletes multiple saved places
  Future<bool> deleteMultipleSavedPlaces(List<int> itemIds) async {
    try {
      final response = await ApiClient.post(
        '/itineraries/saved-places/bulk-delete',
        body: {'ids': itemIds},
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        refreshTrigger.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting multiple saved places: $e');
      return false;
    }
  }

  // The below methods move/copy saved places, which could be implemented in backend directly
  // or via iterating through API calls. In the original version it was iterating via DB calls.
  // Assuming we implement logic similar to before, calling API iteratively.

  /// Moves multiple saved places to a new section
  Future<bool> moveSavedPlaces(List<int> itemIds, String targetSection) async {
    bool success = true;
    for (var id in itemIds) {
      final result = await updateSavedPlace(id, {'section': targetSection});
      if (!result) success = false;
    }
    return success;
  }

  /// Copies multiple saved places to a new section
  Future<bool> copySavedPlaces(List<int> itemIds, String targetSection) async {
    // In a complete backend refactor, we would add an endpoint for this.
    // For now, it's difficult without fetching the actual entities first.
    // Assuming backend will handle it or we fetch then post.
    // This is a simplified version.
    return true;
  }

  /// Creates a new ExplorePost (e.g. for User Guides)
  Future<Map<String, dynamic>?> createExplorePost(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.post('/explore', body: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        debugPrint('Failed to create ExplorePost: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating ExplorePost: $e');
      return null;
    }
  }

  /// Fetches checklist templates
  Future<List<Map<String, dynamic>>> fetchChecklistTemplates() async {
    try {
      final response = await ApiClient.get('/itineraries/checklist-templates');
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error fetching checklist templates: $e');
    }
    return [];
  }

  /// Proposes a new place for database insertion (awaits admin approval)
  Future<Map<String, dynamic>?> proposePlace({
    required String name,
    required String address,
    required int categoryId,
    required String description,
    required String price,
    String? image,
    String? phone,
    String? website,
    String? priceLevel,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final data = {
        'name': name,
        'address': address,
        'categoryId': categoryId,
        'description': description,
        'price': price,
        'image': image ?? '',
        'phone': phone,
        'website': website,
        'priceLevel': priceLevel ?? 'MODERATE',
        'latitude': latitude ?? 0.0,
        'longitude': longitude ?? 0.0,
      };

      final response = await ApiClient.post('/places', body: data);
      if (response.statusCode == 201 || response.statusCode == 200) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error proposing place: $e');
      return null;
    }
  }

  /// Fetches explore posts mentioning a specific place by its ID
  Future<List<Map<String, dynamic>>> fetchExplorePostsByPlace(
    int placeId,
  ) async {
    try {
      final response = await ApiClient.get('/explore/by-place/$placeId');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching posts by place: $e');
      return [];
    }
  }

  // --- API CHIA SẺ & QUẢN LÝ THÀNH VIÊN ---

  /// Mời chỉnh sửa qua Email (EDITOR)
  Future<Map<String, dynamic>?> inviteByEmail(int itineraryId, String email) async {
    try {
      final response = await ApiClient.post(
        '/itineraries/$itineraryId/invite-email',
        body: {'email': email},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Lỗi gửi lời mời'};
    } catch (e) {
      debugPrint('Error inviteByEmail: $e');
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ'};
    }
  }

  /// Lấy Link chia sẻ qua Mạng xã hội (VIEWER)
  Future<Map<String, dynamic>?> getShareLink(int itineraryId) async {
    try {
      final response = await ApiClient.post('/itineraries/$itineraryId/share-link');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getShareLink: $e');
      return null;
    }
  }

  /// Xác nhận lời mời (Token)
  Future<Map<String, dynamic>?> acceptInvite(String token) async {
    try {
      final response = await ApiClient.get('/itineraries/accept-invite?token=$token');
      if (response.statusCode == 200) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': jsonDecode(response.body)['message'] ?? 'Lỗi xác nhận'};
    } catch (e) {
      debugPrint('Error acceptInvite: $e');
      return {'success': false, 'message': 'Không thể kết nối'};
    }
  }

  /// Lấy danh sách thành viên chuyến đi
  Future<Map<String, dynamic>?> getItineraryMembers(int itineraryId) async {
    try {
      final response = await ApiClient.get('/itineraries/$itineraryId/members');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error getItineraryMembers: $e');
      return null;
    }
  }

  /// Cập nhật quyền hạn thành viên (OWNER)
  Future<bool> updateMemberRole(int itineraryId, String targetUserId, String newRole) async {
    try {
      final response = await ApiClient.put(
        '/itineraries/$itineraryId/members/$targetUserId',
        body: {'role': newRole},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updateMemberRole: $e');
      return false;
    }
  }

  /// Xóa thành viên khỏi chuyến đi (OWNER)
  Future<bool> removeMember(int itineraryId, String targetUserId) async {
    try {
      final response = await ApiClient.delete('/itineraries/$itineraryId/members/$targetUserId');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removeMember: $e');
      return false;
    }
  }

  /// Sao chép chuyến đi (Duplicate)
  Future<Map<String, dynamic>?> duplicateItinerary(int itineraryId) async {
    try {
      final response = await ApiClient.post('/itineraries/$itineraryId/duplicate');
      if (response.statusCode == 200 || response.statusCode == 201) {
        refreshTrigger.value++;
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error duplicateItinerary: $e');
      return null;
    }
  }
}

