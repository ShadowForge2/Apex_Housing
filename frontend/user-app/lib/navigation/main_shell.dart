import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';
import '../models/user_role.dart';
import '../screens/home/home_screen.dart';
import '../screens/bookings/bookings_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/landlord/landlord_dashboard_screen.dart';
import '../screens/landlord/my_listings_screen.dart';
import '../screens/landlord/tenants_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  UserRole? _lastRole;
  DateTime? _lastBackPress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final role = RoleProvider.of(context).role;
    if (_lastRole != null && _lastRole != role) {
      setState(() => _currentIndex = 0);
    }
    _lastRole = role;
  }

  void _openPropertyDetail(int index) {
    Navigator.pushNamed(context, '/property-detail', arguments: index);
  }

  void _openMap() {
    Navigator.pushNamed(context, '/map');
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final role = RoleProvider.of(context).role;
    final isLandlord = role == UserRole.landlord;
    final tc = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: tc.background,
        body: IndexedStack(
          index: _currentIndex,
          children: isLandlord ? _landlordScreens() : _tenantScreens(),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: tc.background,
            border: Border(top: BorderSide(color: tc.border, width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            items: isLandlord ? _landlordItems() : _tenantItems(),
          ),
        ),
      ),
    );
  }

  List<Widget> _tenantScreens() {
    return [
      HomeScreen(
        onPropertyTap: () => Navigator.pushNamed(context, '/property-detail'),
        onPropertyDetail: _openPropertyDetail,
        onMapTap: _openMap,
      ),
      const BookingsScreen(),
      const MessagesScreen(),
      FavoritesScreen(
        onPropertyTap: () => Navigator.pushNamed(context, '/property-detail'),
        onPropertyDetail: _openPropertyDetail,
      ),
      const ProfileScreen(),
    ];
  }

  List<Widget> _landlordScreens() {
    return [
      const LandlordDashboardScreen(),
      const MyListingsScreen(),
      const TenantsScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];
  }

  List<BottomNavigationBarItem> _tenantItems() {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_today_rounded), label: 'Bookings'),
      BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
      BottomNavigationBarItem(icon: Icon(Icons.favorite_outline_rounded), activeIcon: Icon(Icons.favorite_rounded), label: 'Favorites'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ];
  }

  List<BottomNavigationBarItem> _landlordItems() {
    return const [
      BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
      BottomNavigationBarItem(icon: Icon(Icons.home_work_outlined), activeIcon: Icon(Icons.home_work_rounded), label: 'Listings'),
      BottomNavigationBarItem(icon: Icon(Icons.people_outline_rounded), activeIcon: Icon(Icons.people_rounded), label: 'Tenants'),
      BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), activeIcon: Icon(Icons.chat_bubble_rounded), label: 'Chat'),
      BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
    ];
  }
}
