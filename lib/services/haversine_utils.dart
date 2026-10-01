import 'dart:math';

class HaversineUtils {
  static const double _earthRadiusKm = 6371.0;
  
  /// Calculate distance in meters between two coordinates using Haversine formula
  static double distanceInMeters(double lat1, double lng1, double lat2, double lng2) {
    var dLat = _degreesToRadians(lat2 - lat1);
    var dLon = _degreesToRadians(lng2 - lng1);
    
    var a = sin(dLat / 2) * sin(dLat / 2) +
            cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
            
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return _earthRadiusKm * c * 1000.0;
  }
  
  /// Format distance for display (< 1000m shows meters, >= 1000m shows km)
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
}
