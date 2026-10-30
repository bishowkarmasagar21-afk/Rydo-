class RrydProfile {
  const RrydProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isVerified,
    required this.isSuspended,
    required this.isOnline,
  });

  final String id;
  final String fullName;
  final String phone;
  final String role;
  final bool isVerified;
  final bool isSuspended;
  final bool isOnline;

  factory RrydProfile.fromMap(Map<String, dynamic> row) {
    return RrydProfile(
      id: (row['id'] ?? '').toString(),
      fullName: (row['full_name'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      role: (row['role'] ?? '').toString().toLowerCase(),
      isVerified: row['is_verified'] == true,
      isSuspended: row['is_suspended'] == true,
      isOnline: row['is_online'] == true,
    );
  }
}
