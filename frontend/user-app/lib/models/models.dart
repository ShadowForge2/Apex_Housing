class Property {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String type;
  final String city;
  final String state;
  final String address;
  final int rentAmount;
  final int securityDeposit;
  final int serviceFee;
  final int tenantPrice;
  final String currency;
  final int bedrooms;
  final int bathrooms;
  final List<String> images;
  final String? videoUrl;
  final List<String> features;
  final List<String> amenities;
  final double rating;
  final int reviewCount;
  final String agentName;
  final String agentAgency;
  final double agentRating;
  final int agentListings;
  final String availabilityFrom;
  final String availabilityUntil;
  final String planType;
  final bool isAvailable;
  final bool isBooked;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final String? landlordId;

  const Property({
    required this.id,
    required this.title,
    this.slug = '',
    required this.description,
    required this.type,
    required this.city,
    required this.state,
    required this.address,
    required this.rentAmount,
    required this.securityDeposit,
    required this.serviceFee,
    required this.tenantPrice,
    this.currency = 'NGN',
    this.bedrooms = 1,
    this.bathrooms = 1,
    required this.images,
    this.videoUrl,
    this.features = const [],
    this.amenities = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.agentName,
    required this.agentAgency,
    this.agentRating = 0.0,
    this.agentListings = 0,
    this.availabilityFrom = '',
    this.availabilityUntil = '',
    this.planType = 'Monthly',
    this.isAvailable = true,
    this.isBooked = false,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.landlordId,
  });

  String get priceFormatted => '₦${_formatNumber(rentAmount)}';
  String get depositFormatted => '₦${_formatNumber(securityDeposit)}';
  String get feeFormatted => '₦${_formatNumber(serviceFee)}';
  String get tenantPriceFormatted => '₦${_formatNumber(tenantPrice)}';

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toString();
  }
}

class Booking {
  final String id;
  final String? propertyId;
  final String reference;
  final String propertyTitle;
  final String propertyImage;
  final String status;
  final int totalAmount;
  final String moveInDate;
  final String createdAt;
  final String? cancellationReason;
  final String escrowStatus;
  final int? inspectionHoursLeft;

  const Booking({
    required this.id,
    this.propertyId,
    required this.reference,
    required this.propertyTitle,
    required this.propertyImage,
    required this.status,
    required this.totalAmount,
    required this.moveInDate,
    required this.createdAt,
    this.cancellationReason,
    required this.escrowStatus,
    this.inspectionHoursLeft,
  });

  String get amountFormatted => '₦${totalAmount.toString().replaceAll(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), ',')}';
}

class Conversation {
  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String? propertyTitle;
  final bool isOnline;
  final String userId;
  final String role;

  const Conversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.propertyTitle,
    this.isOnline = false,
    this.userId = '',
    this.role = '',
  });
}

class Message {
  final String id;
  final String text;
  final bool isMe;
  final String time;
  final bool isEdited;
  final String? attachmentUrl;

  const Message({
    required this.id,
    required this.text,
    required this.isMe,
    required this.time,
    this.isEdited = false,
    this.attachmentUrl,
  });
}
