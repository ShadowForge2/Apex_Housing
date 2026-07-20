import 'package:flutter_test/flutter_test.dart';
import 'package:apex_housing/models/models.dart';
import 'package:apex_housing/services/escrow_service.dart';
import 'package:apex_housing/services/booking_service.dart';
import 'package:apex_housing/services/search_service.dart';
import 'package:apex_housing/services/exceptions.dart';
import 'package:apex_housing/services/property_service.dart';

void main() {
  group('Property Model', () {
    test('priceFormatted formats correctly', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '123 Main St',
        rentAmount: 500000, securityDeposit: 100000, serviceFee: 25000,
        tenantPrice: 525000, images: [], agentName: 'Agent', agentAgency: 'APEX',
      );
      expect(p.priceFormatted, '₦500k');
    });

    test('priceFormatted handles millions', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'villa',
        city: 'Lagos', state: 'Lagos', address: '123 Main St',
        rentAmount: 2000000, securityDeposit: 500000, serviceFee: 0,
        tenantPrice: 2000000, images: [], agentName: 'Agent', agentAgency: 'APEX',
      );
      expect(p.priceFormatted, '₦2.0M');
    });

    test('priceFormatted handles small amounts', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'room',
        city: 'Lagos', state: 'Lagos', address: '123 Main St',
        rentAmount: 50000, securityDeposit: 10000, serviceFee: 0,
        tenantPrice: 50000, images: [], agentName: 'Agent', agentAgency: 'APEX',
      );
      expect(p.priceFormatted, '₦50k');
    });

    test('depositFormatted works', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '',
        rentAmount: 100000, securityDeposit: 200000, serviceFee: 0,
        tenantPrice: 100000, images: [], agentName: 'A', agentAgency: 'APEX',
      );
      expect(p.depositFormatted, '₦200k');
    });

    test('feeFormatted works', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '',
        rentAmount: 100000, securityDeposit: 50000, serviceFee: 15000,
        tenantPrice: 115000, images: [], agentName: 'A', agentAgency: 'APEX',
      );
      expect(p.feeFormatted, '₦15k');
    });

    test('tenantPriceFormatted works', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '',
        rentAmount: 100000, securityDeposit: 50000, serviceFee: 0,
        tenantPrice: 100000, images: [], agentName: 'A', agentAgency: 'APEX',
      );
      expect(p.tenantPriceFormatted, '₦100k');
    });

    test('with distanceKm', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '',
        rentAmount: 100000, securityDeposit: 50000, serviceFee: 0,
        tenantPrice: 100000, images: [], agentName: 'A', agentAgency: 'APEX',
        distanceKm: 2.5,
      );
      expect(p.distanceKm, 2.5);
    });

    test('defaults', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '',
        rentAmount: 100000, securityDeposit: 50000, serviceFee: 0,
        tenantPrice: 100000, images: [], agentName: 'A', agentAgency: 'APEX',
      );
      expect(p.isAvailable, true);
      expect(p.isBooked, false);
      expect(p.bedrooms, 1);
      expect(p.bathrooms, 1);
      expect(p.currency, 'NGN');
      expect(p.planType, 'Monthly');
      expect(p.latitude, isNull);
      expect(p.longitude, isNull);
      expect(p.distanceKm, isNull);
      expect(p.landlordId, isNull);
      expect(p.slug, '');
      expect(p.features, isEmpty);
      expect(p.amenities, isEmpty);
    });

    test('with landlordId', () {
      const p = Property(
        id: '1', title: 'Test', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '',
        rentAmount: 100000, securityDeposit: 50000, serviceFee: 0,
        tenantPrice: 100000, images: [], agentName: 'A', agentAgency: 'APEX',
        landlordId: 'user-123',
      );
      expect(p.landlordId, 'user-123');
    });
  });

  group('PropertyListResponse', () {
    test('parses properties key from backend', () {
      final response = PropertyListResponse.fromJson({
        'data': {
          'total': 2,
          'properties': [
            {
              'id': '1', 'title': 'Test', 'slug': 'test',
              'description': 'Desc', 'property_type': 'apartment',
              'status': 'active', 'images': [], 'features': [],
              'amenities': [], 'created_at': '2026-01-01T00:00:00',
            },
            {
              'id': '2', 'title': 'Another', 'slug': 'another',
              'description': 'Desc', 'property_type': 'villa',
              'status': 'active', 'images': [], 'features': [],
              'amenities': [], 'created_at': '2026-01-02T00:00:00',
            },
          ],
          'page': 1, 'page_size': 20,
        },
      });
      expect(response.total, 2);
      expect(response.items.length, 2);
      expect(response.items[0].title, 'Test');
      expect(response.items[1].title, 'Another');
    });

    test('parses items key (legacy)', () {
      final response = PropertyListResponse.fromJson({
        'data': {
          'total': 1,
          'items': [
            {
              'id': '1', 'title': 'Legacy', 'slug': 'legacy',
              'property_type': 'apartment', 'images': [], 'features': [],
              'amenities': [], 'created_at': '2026-01-01T00:00:00',
            },
          ],
          'page': 1, 'page_size': 20,
        },
      });
      expect(response.items.length, 1);
      expect(response.items[0].title, 'Legacy');
    });

    test('parses search result format (flat fields)', () {
      final response = PropertyListResponse.fromJson({
        'data': {
          'total': 1,
          'properties': [
            {
              'id': '1', 'title': 'Search Result', 'slug': 'search-result',
              'description': 'Found', 'property_type': 'apartment',
              'front_image': 'https://example.com/img.jpg',
              'rent_amount': 100000.0, 'security_deposit': 50000.0,
              'currency': 'NGN', 'city': 'Lagos', 'state': 'Lagos',
              'latitude': 6.5, 'longitude': 3.3, 'distance_km': 2.5,
              'is_available': true, 'created_at': '2026-01-01T00:00:00',
            },
          ],
          'page': 1, 'page_size': 20,
        },
      });
      expect(response.items.length, 1);
      final p = response.items[0];
      expect(p.title, 'Search Result');
      expect(p.images.length, 1);
      expect(p.images[0].url, 'https://example.com/img.jpg');
      expect(p.location?.city, 'Lagos');
      expect(p.location?.latitude, 6.5);
      expect(p.pricing?.rentAmount, 100000.0);
    });

    test('handles empty data gracefully', () {
      final response = PropertyListResponse.fromJson({'data': {}});
      expect(response.items.isEmpty, true);
      expect(response.total, 0);
    });

    test('handles list data format', () {
      final response = PropertyListResponse.fromJson({
        'data': [
          {
            'id': '1', 'title': 'List', 'slug': 'list',
            'property_type': 'apartment', 'images': [], 'features': [],
            'amenities': [], 'created_at': '2026-01-01T00:00:00',
          },
        ],
      });
      expect(response.items.length, 1);
      expect(response.total, 1);
    });

    test('handles null data', () {
      final response = PropertyListResponse.fromJson({});
      expect(response.items.isEmpty, true);
      expect(response.total, 0);
    });
  });

  group('PropertyModel.fromJson', () {
    test('parses nested format (from /properties/)', () {
      final model = PropertyModel.fromJson({
        'id': '1', 'title': 'Nested', 'slug': 'nested', 'description': 'Desc',
        'property_type': 'apartment', 'status': 'active',
        'images': [
          {'id': 'img1', 'url': 'https://example.com/1.jpg', 'label': 'front', 'is_primary': true, 'sort_order': 0},
        ],
        'location': {
          'id': 'loc1', 'city': 'Lagos', 'state': 'Lagos',
          'latitude': 6.5, 'longitude': 3.3,
        },
        'pricing': {
          'id': 'pr1', 'rent_amount': 200000.0, 'security_deposit': 100000.0,
          'service_fee': 10000.0, 'currency': 'NGN',
        },
        'availability': {
          'id': 'av1', 'is_available': true, 'is_booked': false, 'plan_type': 'Monthly',
        },
        'features': [
          {'id': 'f1', 'feature_name': 'bedrooms', 'feature_value': '3'},
          {'id': 'f2', 'feature_name': 'bathrooms', 'feature_value': '2'},
        ],
        'amenities': [],
        'created_at': '2026-01-01T00:00:00',
      });
      expect(model.title, 'Nested');
      expect(model.images.length, 1);
      expect(model.location?.city, 'Lagos');
      expect(model.pricing?.rentAmount, 200000.0);
      expect(model.availability?.isAvailable, true);
      expect(model.features.length, 2);
    });

    test('parses flat format (from /search/properties)', () {
      final model = PropertyModel.fromJson({
        'id': '1', 'title': 'Flat', 'slug': 'flat', 'description': 'Desc',
        'property_type': 'villa',
        'front_image': 'https://example.com/1.jpg',
        'rent_amount': 300000.0, 'security_deposit': 150000.0,
        'currency': 'NGN', 'city': 'Ikeja', 'state': 'Lagos',
        'latitude': 6.6, 'longitude': 3.4, 'distance_km': 1.2,
        'is_available': true, 'created_at': '2026-01-01T00:00:00',
      });
      expect(model.title, 'Flat');
      expect(model.images.length, 1);
      expect(model.location?.city, 'Ikeja');
      expect(model.pricing?.rentAmount, 300000.0);
      expect(model.distanceKm, 1.2);
      expect(model.availability, isNull);
    });

    test('handles missing fields gracefully', () {
      final model = PropertyModel.fromJson({
        'id': '1', 'title': 'Minimal', 'slug': 'minimal',
      });
      expect(model.title, 'Minimal');
      expect(model.images, isEmpty);
      expect(model.location, isNull);
      expect(model.pricing, isNull);
      expect(model.availability, isNull);
      expect(model.features, isEmpty);
      expect(model.amenities, isEmpty);
      expect(model.distanceKm, isNull);
    });
  });

  group('PropertyModel.toProperty', () {
    test('converts nested model to Property', () {
      final model = PropertyModel(
        id: '1', title: 'Test', slug: 'test', description: 'Desc',
        propertyType: 'apartment', status: 'active',
        images: [
          PropertyImage(id: '1', url: 'https://example.com/1.jpg', label: 'front', isPrimary: true),
        ],
        location: PropertyLocation(id: '1', city: 'Lagos', state: 'Lagos', address: '123 St'),
        pricing: PropertyPricing(id: '1', rentAmount: 200000, securityDeposit: 100000, serviceFee: 10000, currency: 'NGN'),
        availability: PropertyAvailability(id: '1', isAvailable: true, isBooked: false, planType: 'Monthly'),
        features: [
          PropertyFeature(id: '1', featureName: 'bedrooms', featureValue: '3'),
          PropertyFeature(id: '2', featureName: 'bathrooms', featureValue: '2'),
        ],
        amenities: [PropertyAmenity(id: '1', name: 'WiFi')],
      );
      final p = model.toProperty();
      expect(p.id, '1');
      expect(p.title, 'Test');
      expect(p.rentAmount, 200000);
      expect(p.securityDeposit, 100000);
      expect(p.serviceFee, 10000);
      expect(p.bedrooms, 3);
      expect(p.bathrooms, 2);
      expect(p.images.length, 1);
      expect(p.amenities, contains('WiFi'));
      expect(p.isAvailable, true);
      expect(p.isBooked, false);
    });

    test('handles flat search result model', () {
      final model = PropertyModel(
        id: '1', title: 'Flat', slug: 'flat',
        propertyType: 'villa',
        images: [PropertyImage(id: '0', url: 'https://example.com/img.jpg', label: 'front')],
        location: PropertyLocation(id: '', city: 'Ikeja', state: 'Lagos'),
        pricing: PropertyPricing(id: '', rentAmount: 300000, securityDeposit: 150000, serviceFee: 0, currency: 'NGN'),
      );
      final p = model.toProperty();
      expect(p.title, 'Flat');
      expect(p.type, 'villa');
      expect(p.city, 'Ikeja');
      expect(p.state, 'Lagos');
      expect(p.rentAmount, 300000);
      expect(p.bedrooms, 0);
      expect(p.bathrooms, 0);
    });
  });

  group('Booking Model', () {
    test('amountFormatted with commas', () {
      const b = Booking(
        id: '1', reference: 'REF-001', propertyTitle: 'Test',
        propertyImage: '', status: 'active', totalAmount: 1500000,
        moveInDate: '2026-08-01', createdAt: '2026-07-01', escrowStatus: 'FUNDS_HELD',
      );
      expect(b.amountFormatted, '₦1,500,000');
    });

    test('amountFormatted small amount', () {
      const b = Booking(
        id: '1', reference: 'REF-001', propertyTitle: 'Test',
        propertyImage: '', status: 'active', totalAmount: 50000,
        moveInDate: '2026-08-01', createdAt: '2026-07-01', escrowStatus: 'PENDING',
      );
      expect(b.amountFormatted, '₦50,000');
    });

    test('cancellationReason nullable', () {
      const b = Booking(
        id: '1', reference: 'REF-001', propertyTitle: 'Test',
        propertyImage: '', status: 'cancelled', totalAmount: 0,
        moveInDate: '2026-08-01', createdAt: '2026-07-01', escrowStatus: 'REFUNDED',
      );
      expect(b.cancellationReason, isNull);
    });

    test('inspectionHoursLeft nullable', () {
      const b = Booking(
        id: '1', reference: 'REF-001', propertyTitle: 'Test',
        propertyImage: '', status: 'active', totalAmount: 0,
        moveInDate: '2026-08-01', createdAt: '2026-07-01', escrowStatus: 'TIMER_RUNNING',
      );
      expect(b.inspectionHoursLeft, isNull);
    });
  });

  group('Conversation Model', () {
    test('defaults', () {
      const c = Conversation(
        id: '1', name: 'Agent', lastMessage: 'Hi', time: '10:00',
      );
      expect(c.unreadCount, 0);
      expect(c.propertyTitle, isNull);
      expect(c.isOnline, false);
      expect(c.userId, '');
      expect(c.role, '');
    });

    test('with all fields', () {
      const c = Conversation(
        id: '1', name: 'Agent', lastMessage: 'Hi', time: '10:00',
        unreadCount: 3, propertyTitle: '2BR Apartment', isOnline: true,
        userId: 'user-123', role: 'LANDLORD',
      );
      expect(c.unreadCount, 3);
      expect(c.propertyTitle, '2BR Apartment');
      expect(c.isOnline, true);
      expect(c.userId, 'user-123');
      expect(c.role, 'LANDLORD');
    });
  });

  group('Message Model', () {
    test('defaults', () {
      const m = Message(id: '1', text: 'Hello', isMe: true, time: '10:00');
      expect(m.isEdited, false);
      expect(m.attachmentUrl, isNull);
    });

    test('with optional fields', () {
      const m = Message(
        id: '1', text: 'Hello', isMe: false, time: '10:00',
        isEdited: true, attachmentUrl: 'https://example.com/file.pdf',
      );
      expect(m.isEdited, true);
      expect(m.attachmentUrl, 'https://example.com/file.pdf');
    });
  });

  group('EscrowModel', () {
    test('fromJson parses correctly', () {
      final e = EscrowModel.fromJson({
        'id': 'esc-1', 'booking_id': 'bk-1', 'status': 'FUNDS_HELD',
        'amount': 500000.0, 'currency': 'NGN', 'funded_at': '2026-07-01T00:00:00',
        'created_at': '2026-07-01T00:00:00',
      });
      expect(e.id, 'esc-1');
      expect(e.bookingId, 'bk-1');
      expect(e.status, 'FUNDS_HELD');
      expect(e.amount, 500000.0);
      expect(e.currency, 'NGN');
      expect(e.fundedAt, isNotNull);
      expect(e.releasedAt, isNull);
    });

    test('fromJson with nulls', () {
      final e = EscrowModel.fromJson({'id': 'esc-1'});
      expect(e.id, 'esc-1');
      expect(e.bookingId, isNull);
      expect(e.status, isNull);
      expect(e.amount, isNull);
    });
  });

  group('BookingModel', () {
    test('fromJson parses correctly', () {
      final b = BookingModel.fromJson({
        'id': 'bk-1', 'property_id': 'prop-1', 'user_id': 'user-1',
        'status': 'PENDING', 'move_in_date': '2026-08-01',
        'notes': 'Please call before arriving', 'terms_agreed': true,
        'created_at': '2026-07-01T00:00:00', 'total_amount': 500000,
      });
      expect(b.id, 'bk-1');
      expect(b.propertyId, 'prop-1');
      expect(b.userId, 'user-1');
      expect(b.status, 'PENDING');
      expect(b.moveInDate, '2026-08-01');
      expect(b.notes, 'Please call before arriving');
      expect(b.termsAgreed, true);
      expect(b.totalAmount, 500000);
    });

    test('fromJson with nulls', () {
      final b = BookingModel.fromJson({'id': 'bk-1'});
      expect(b.id, 'bk-1');
      expect(b.propertyId, isNull);
      expect(b.status, isNull);
      expect(b.totalAmount, 0);
    });
  });

  group('LocationModel', () {
    test('fromJson parses correctly', () {
      final l = LocationModel.fromJson({
        'id': 'loc-1', 'city': 'Lagos', 'state': 'Lagos',
        'country': 'Nigeria', 'property_count': 42,
      });
      expect(l.id, 'loc-1');
      expect(l.city, 'Lagos');
      expect(l.state, 'Lagos');
      expect(l.country, 'Nigeria');
      expect(l.propertyCount, 42);
    });

    test('fromJson with nulls', () {
      final l = LocationModel.fromJson({'id': 'loc-1'});
      expect(l.id, 'loc-1');
      expect(l.city, isNull);
      expect(l.state, isNull);
      expect(l.propertyCount, isNull);
    });
  });

  group('PriceRange', () {
    test('fromJson parses correctly', () {
      final r = PriceRange.fromJson({
        'label': 'Budget', 'min': 0, 'max': 100000,
      });
      expect(r.label, 'Budget');
      expect(r.min, 0);
      expect(r.max, 100000);
    });

    test('fromJson with nulls', () {
      final r = PriceRange.fromJson({'label': 'Any'});
      expect(r.label, 'Any');
      expect(r.min, isNull);
      expect(r.max, isNull);
    });
  });

  group('ApiException', () {
    test('toString returns message', () {
      final e = ApiException(message: 'Not found');
      expect(e.toString(), 'Not found');
    });

    test('statusCode nullable', () {
      final e = ApiException(message: 'Error');
      expect(e.statusCode, isNull);
    });

    test('errors nullable', () {
      final e = ApiException(message: 'Error');
      expect(e.errors, isNull);
    });

    test('with all fields', () {
      final e = ApiException(
        statusCode: 422,
        message: 'Validation failed',
        errors: {'email': 'Already exists'},
      );
      expect(e.statusCode, 422);
      expect(e.message, 'Validation failed');
      expect(e.errors?['email'], 'Already exists');
    });
  });
}
