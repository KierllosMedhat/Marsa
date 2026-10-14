class StaffUser {
  final String staffId;
  final String role;
  final String nameAr;
  final String? nameEn;
  final String email;
  final String? phone;
  final bool mfaEnabled;

  StaffUser({
    required this.staffId,
    required this.role,
    required this.nameAr,
    this.nameEn,
    required this.email,
    this.phone,
    required this.mfaEnabled,
  });

  bool get isDoctor => role == 'doctor';
  bool get isReceptionist => role == 'receptionist';
  bool get isAdmin => role == 'admin';

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      staffId: json['staff_id'] ?? json['sub'] ?? '',
      role: json['role'] ?? 'doctor',
      nameAr: json['name_ar'] ?? 'د. الطبيب',
      nameEn: json['name_en'],
      email: json['email'] ?? '',
      phone: json['phone'],
      mfaEnabled: json['mfa_enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'staff_id': staffId,
      'role': role,
      'name_ar': nameAr,
      'name_en': nameEn,
      'email': email,
      'phone': phone,
      'mfa_enabled': mfaEnabled,
    };
  }
}
