class StringUtils {
  /// Clean up address strings by removing 5-digit or 6-digit postal zip codes (e.g. 92000)
  /// and correcting formatting artifacts like duplicate commas or double spaces.
  static String cleanAddress(String address) {
    if (address.isEmpty) return address;
    
    // Remove 5-digit or 6-digit postal zip codes
    String cleaned = address.replaceAll(RegExp(r'\b\d{5,6}\b'), '');
    
    // Clean up spacing and duplicate punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    cleaned = cleaned.replaceAll(' ,', ',');
    cleaned = cleaned.replaceAll(',,', ',');
    cleaned = cleaned.trim();
    
    if (cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1).trim();
    }
    
    return cleaned;
  }
}
