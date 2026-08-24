
/// ParkingStatisticsService - Service for calculating dynamic parking statistics
/// 
/// This service provides real-time calculations for parking metrics
/// Features:
/// - Dynamic slot counting
/// - Occupancy rate calculations
/// - Visitor parking statistics
/// - Unauthorized vehicle tracking
/// - Revenue calculations
class ParkingStatisticsService {
  /// Calculate parking statistics from slot data
  static ParkingStatistics calculateStatistics(
    List<ParkingSlot> allSlots,
    List<VisitorVehicle> visitorVehicles,
    List<ResidentVehicle> residentVehicles,
  ) {
    // Basic slot statistics
    final totalSlots = allSlots.length;
    final occupiedSlots = allSlots.where((slot) => slot.isOccupied).length;
    final vacantSlots = totalSlots - occupiedSlots;
    final unauthorizedSlots = allSlots.where((slot) => slot.isUnauthorized).length;
    
    // Visitor statistics
    final visitorSlots = allSlots.where((slot) => 
      slot.isOccupied && slot.vehicleType == 'Visitor'
    ).length;
    final activeVisitors = visitorVehicles.length;
    
    // Vehicle type breakdown
    final carSlots = allSlots.where((slot) => slot.vehicleType == 'Car').length;
    final bikeSlots = allSlots.where((slot) => slot.vehicleType == 'Bike').length;
    final occupiedCarSlots = allSlots.where((slot) => 
      slot.vehicleType == 'Car' && slot.isOccupied
    ).length;
    final occupiedBikeSlots = allSlots.where((slot) => 
      slot.vehicleType == 'Bike' && slot.isOccupied
    ).length;
    
    // Occupancy rates
    final overallOccupancyRate = totalSlots > 0 ? (occupiedSlots / totalSlots) * 100 : 0.0;
    final carOccupancyRate = carSlots > 0 ? (occupiedCarSlots / carSlots) * 100 : 0.0;
    final bikeOccupancyRate = bikeSlots > 0 ? (occupiedBikeSlots / bikeSlots) * 100 : 0.0;
    
    // Revenue calculations (sample rates)
    final monthlyCarRate = 1500.0; // ₹1500 per month for car
    final monthlyBikeRate = 500.0;  // ₹500 per month for bike
    final dailyVisitorRate = 50.0;  // ₹50 per day for visitor
    
    final monthlyRevenue = (occupiedCarSlots * monthlyCarRate) + 
                          (occupiedBikeSlots * monthlyBikeRate);
    final dailyVisitorRevenue = activeVisitors * dailyVisitorRate;
    
    return ParkingStatistics(
      totalSlots: totalSlots,
      occupiedSlots: occupiedSlots,
      vacantSlots: vacantSlots,
      visitorSlots: visitorSlots,
      unauthorizedSlots: unauthorizedSlots,
      activeVisitors: activeVisitors,
      carSlots: carSlots,
      bikeSlots: bikeSlots,
      occupiedCarSlots: occupiedCarSlots,
      occupiedBikeSlots: occupiedBikeSlots,
      overallOccupancyRate: overallOccupancyRate,
      carOccupancyRate: carOccupancyRate,
      bikeOccupancyRate: bikeOccupancyRate,
      monthlyRevenue: monthlyRevenue,
      dailyVisitorRevenue: dailyVisitorRevenue,
      registeredVehicles: residentVehicles.length,
    );
  }
  
  /// Get occupancy trend data (sample implementation)
  static List<OccupancyTrend> getOccupancyTrend() {
    return [
      OccupancyTrend(hour: 6, occupancyRate: 45.0),
      OccupancyTrend(hour: 8, occupancyRate: 85.0),
      OccupancyTrend(hour: 10, occupancyRate: 65.0),
      OccupancyTrend(hour: 12, occupancyRate: 70.0),
      OccupancyTrend(hour: 14, occupancyRate: 60.0),
      OccupancyTrend(hour: 16, occupancyRate: 75.0),
      OccupancyTrend(hour: 18, occupancyRate: 90.0),
      OccupancyTrend(hour: 20, occupancyRate: 95.0),
      OccupancyTrend(hour: 22, occupancyRate: 85.0),
    ];
  }
  
  /// Get peak hours analysis
  static PeakHoursAnalysis getPeakHoursAnalysis(List<ParkingSlot> allSlots) {
    final currentHour = DateTime.now().hour;
    
    // Sample peak hours logic
    final isPeakHour = (currentHour >= 8 && currentHour <= 10) || 
                      (currentHour >= 18 && currentHour <= 20);
    
    final peakOccupancy = isPeakHour ? 90.0 : 65.0;
    final nextPeakHour = currentHour < 8 ? 8 : 
                        currentHour < 18 ? 18 : 8; // Next day
    
    return PeakHoursAnalysis(
      isPeakHour: isPeakHour,
      currentOccupancy: peakOccupancy,
      nextPeakHour: nextPeakHour,
      peakHours: ['8:00-10:00 AM', '6:00-8:00 PM'],
    );
  }
  
  /// Calculate parking violations summary
  static ViolationsSummary getViolationsSummary(List<ParkingSlot> allSlots) {
    final unauthorizedCount = allSlots.where((slot) => slot.isUnauthorized).length;
    
    // Sample violation data
    return ViolationsSummary(
      totalViolations: unauthorizedCount + 3, // +3 for other violations
      unauthorizedParking: unauthorizedCount,
      expiredPermits: 2,
      blockingAccess: 1,
      totalFinesIssued: 5,
      totalFineAmount: 2500.0, // ₹2500 in fines
    );
  }
}

/// Parking Statistics Data Model
class ParkingStatistics {
  final int totalSlots;
  final int occupiedSlots;
  final int vacantSlots;
  final int visitorSlots;
  final int unauthorizedSlots;
  final int activeVisitors;
  final int carSlots;
  final int bikeSlots;
  final int occupiedCarSlots;
  final int occupiedBikeSlots;
  final double overallOccupancyRate;
  final double carOccupancyRate;
  final double bikeOccupancyRate;
  final double monthlyRevenue;
  final double dailyVisitorRevenue;
  final int registeredVehicles;

  ParkingStatistics({
    required this.totalSlots,
    required this.occupiedSlots,
    required this.vacantSlots,
    required this.visitorSlots,
    required this.unauthorizedSlots,
    required this.activeVisitors,
    required this.carSlots,
    required this.bikeSlots,
    required this.occupiedCarSlots,
    required this.occupiedBikeSlots,
    required this.overallOccupancyRate,
    required this.carOccupancyRate,
    required this.bikeOccupancyRate,
    required this.monthlyRevenue,
    required this.dailyVisitorRevenue,
    required this.registeredVehicles,
  });
}

/// Occupancy Trend Data Model
class OccupancyTrend {
  final int hour;
  final double occupancyRate;

  OccupancyTrend({
    required this.hour,
    required this.occupancyRate,
  });
}

/// Peak Hours Analysis Data Model
class PeakHoursAnalysis {
  final bool isPeakHour;
  final double currentOccupancy;
  final int nextPeakHour;
  final List<String> peakHours;

  PeakHoursAnalysis({
    required this.isPeakHour,
    required this.currentOccupancy,
    required this.nextPeakHour,
    required this.peakHours,
  });
}

/// Violations Summary Data Model
class ViolationsSummary {
  final int totalViolations;
  final int unauthorizedParking;
  final int expiredPermits;
  final int blockingAccess;
  final int totalFinesIssued;
  final double totalFineAmount;

  ViolationsSummary({
    required this.totalViolations,
    required this.unauthorizedParking,
    required this.expiredPermits,
    required this.blockingAccess,
    required this.totalFinesIssued,
    required this.totalFineAmount,
  });
}

