/// Add New Resident Modal (Simplified - No Unit Number)
/// 
/// A centered overlay modal for adding new residents to the society.
/// Matches the admin app visual system with blue primary colors and rounded cards.
/// Includes auto-generated password feature.
library;


// ============================================================================
// RESIDENT MODEL
// ============================================================================

class ResidentModel {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final int membersCount;
  final String generatedP