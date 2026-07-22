import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex_housing/models/models.dart';
import 'package:apex_housing/models/user_role.dart';
import 'package:apex_housing/widgets/property_card.dart';

void main() {
  group('PropertyCard', () {
    Property makeProperty({
      String? distanceKm,
      String id = '1',
      String title = 'Test Property',
      String type = 'apartment',
      int rentAmount = 500000,
    }) {
      return Property(
        id: id,
        title: title,
        description: 'A nice place',
        type: type,
        city: 'Lagos',
        state: 'Lagos',
        address: '123 Main St',
        rentAmount: rentAmount,
        securityDeposit: 100000,
        serviceFee: 25000,
        tenantPrice: 525000,
        images: [],
        agentName: 'Agent',
        agentAgency: 'APEX',
      );
    }

    testWidgets('renders property title', (tester) async {
      final property = makeProperty(title: 'Luxury Apartment');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(
              property: property,
              onTap: () {},
              onFavorite: () {},
            ),
          ),
        ),
      );
      expect(find.text('Luxury Apartment'), findsOneWidget);
    });

    testWidgets('renders without crashing', (tester) async {
      final property = makeProperty();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(
              property: property,
              onTap: () {},
              onFavorite: () {},
            ),
          ),
        ),
      );
      expect(find.byType(PropertyCard), findsOneWidget);
    });

    testWidgets('onTap callback fires', (tester) async {
      bool tapped = false;
      final property = makeProperty();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(
              property: property,
              onTap: () => tapped = true,
              onFavorite: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PropertyCard));
      expect(tapped, true);
    });
  });

  group('UserRole', () {
    test('role provider builds correctly', () {
      expect(UserRole.tenant, isNotNull);
      expect(UserRole.landlord, isNotNull);
    });
  });

  group('PropertyCard with distance', () {
    testWidgets('shows distance badge when distanceKm is set', (tester) async {
      final property = Property(
        id: '1', title: 'Nearby', description: 'Desc', type: 'apartment',
        city: 'Lagos', state: 'Lagos', address: '123 St',
        rentAmount: 500000, securityDeposit: 100000, serviceFee: 0,
        tenantPrice: 500000, images: [], agentName: 'A', agentAgency: 'APEX',
        distanceKm: 2.5,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PropertyCard(
              property: property,
              onTap: () {},
              onFavorite: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('km'), findsOneWidget);
    });
  });
}
