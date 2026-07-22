enum BookingStatus { active, completed, disputed, cancelled }

enum TransactionType { rent, deposit, fee, withdrawal, dispute }

enum TransactionStatus { completed, pending, failed, refunded }

enum KycStatus { pending, verified, rejected }

enum UserRole { tenant, landlord, agent }

enum ReportStatus { open, investigating, resolved }

enum ReportType { harassment, noise, propertyDamage, safety, discrimination, other }

enum ReportSeverity { low, medium, high }

class AdminBooking {
  final String reference;
  final String tenantName;
  final String landlordName;
  final String property;
  final double amount;
  final BookingStatus status;
  final String date;
  final String escrowStatus;

  const AdminBooking({
    required this.reference,
    required this.tenantName,
    required this.landlordName,
    required this.property,
    required this.amount,
    required this.status,
    required this.date,
    required this.escrowStatus,
  });
}

class AdminTransaction {
  final String reference;
  final TransactionType type;
  final double amount;
  final bool isCredit;
  final String fromName;
  final String toName;
  final String date;
  final TransactionStatus status;

  const AdminTransaction({
    required this.reference,
    required this.type,
    required this.amount,
    required this.isCredit,
    required this.fromName,
    required this.toName,
    required this.date,
    required this.status,
  });
}

class AdminKycEntry {
  final String name;
  final String userId;
  final UserRole role;
  final String documentType;
  final String submittedDate;
  final KycStatus status;
  final String avatarUrl;

  const AdminKycEntry({
    required this.name,
    required this.userId,
    required this.role,
    required this.documentType,
    required this.submittedDate,
    required this.status,
    required this.avatarUrl,
  });
}

class AdminUser {
  final String name;
  final String email;
  final String id;
  final String role;
  final String status;
  final String phone;
  final String city;
  final String joinDate;
  final int totalBookings;
  final String avatar;
  final bool isSuperAdmin;

  const AdminUser({
    required this.name,
    required this.email,
    required this.id,
    required this.role,
    required this.status,
    required this.phone,
    required this.city,
    required this.joinDate,
    required this.totalBookings,
    required this.avatar,
    this.isSuperAdmin = false,
  });
}

class AdminProperty {
  final String title;
  final String id;
  final String landlord;
  final String city;
  final String type;
  final String status;
  final int rent;
  final int views;
  final int bookings;

  const AdminProperty({
    required this.title,
    required this.id,
    required this.landlord,
    required this.city,
    required this.type,
    required this.status,
    required this.rent,
    required this.views,
    required this.bookings,
  });
}

class AdminReport {
  final String id;
  final ReportType type;
  final ReportSeverity severity;
  final ReportStatus status;
  final String reportedBy;
  final String reportedAgainst;
  final String description;
  final DateTime date;
  final String? assignedTo;

  const AdminReport({
    required this.id,
    required this.type,
    required this.severity,
    required this.status,
    required this.reportedBy,
    required this.reportedAgainst,
    required this.description,
    required this.date,
    this.assignedTo,
  });
}
