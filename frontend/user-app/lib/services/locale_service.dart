import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// APEX Housing locale service — manages language, theme, text scale,
/// and screen state persistence across app restarts and minimize.
class LocaleService extends ChangeNotifier {
  static const _langKey = 'app_language';
  static const _themeKey = 'app_theme';
  static const _textScaleKey = 'app_text_scale';
  static const _lastScreenKey = 'last_screen';
  static const _lastScrollKey = 'last_scroll_position';
  static const _draftDataKey = 'draft_data';

  String _languageCode = 'en';
  String get languageCode => _languageCode;

  Locale get locale {
    switch (_languageCode) {
      case 'yo':
        return const Locale('yo');
      case 'pcm':
        return const Locale('pcm');
      default:
        return const Locale('en');
    }
  }

  static final LocaleService _instance = LocaleService._();
  factory LocaleService() => _instance;
  LocaleService._();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString(_langKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (!['en', 'yo', 'pcm'].contains(code)) return;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, code);
    notifyListeners();
  }

  // ─── Theme persistence ───
  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? false;
  }

  Future<void> setDarkMode(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, dark);
  }

  // ─── Text scale persistence ───
  Future<bool> getLargeText() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_textScaleKey) ?? false;
  }

  Future<void> setLargeText(bool large) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_textScaleKey, large);
  }

  // ─── Screen state restoration (for app minimize) ───
  Future<void> saveScreenState(String screen, {int? scrollPosition, Map<String, dynamic>? draftData}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScreenKey, screen);
    if (scrollPosition != null) {
      await prefs.setInt(_lastScrollKey, scrollPosition);
    }
    if (draftData != null) {
      await prefs.setString(_draftDataKey, jsonEncode(draftData));
    }
  }

  Future<String?> getLastScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastScreenKey);
  }

  Future<int?> getLastScrollPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastScrollKey);
  }

  Future<Map<String, dynamic>?> getDraftData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftDataKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearDraftData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftDataKey);
    await prefs.remove(_lastScrollKey);
  }

  // ─── Translation helper ───
  String tr(String key) {
    return translations[_languageCode]?[key] ?? translations['en']?[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────
// Translation maps: English, Yoruba, Pidgin
// ─────────────────────────────────────────────────────────
const Map<String, Map<String, String>> translations = {
  'en': _english,
  'yo': _yoruba,
  'pcm': _pidgin,
};

const Map<String, String> _english = {
  // Navigation
  'nav_home': 'Home',
  'nav_search': 'Search',
  'nav_bookings': 'Bookings',
  'nav_messages': 'Messages',
  'nav_profile': 'Profile',

  // Settings
  'settings': 'Settings',
  'notifications': 'Notifications',
  'push_notifications': 'Push Notifications',
  'email_notifications': 'Email Notifications',
  'sms_notifications': 'SMS Notifications',
  'appearance': 'Appearance',
  'dark_mode': 'Dark Mode',
  'dark_mode_enabled': 'Dark mode enabled',
  'light_mode_enabled': 'Light mode enabled',
  'large_text': 'Large Text',
  'text_size_default': 'Text size: Default (1.0x)',
  'text_size_large': 'Text size: Large (1.3x)',
  'large_text_enabled': 'Large text enabled',
  'large_text_disabled': 'Large text disabled',
  'language': 'Language',
  'privacy': 'Privacy',
  'change_password': 'Change Password',
  'biometric_login': 'Biometric Login',
  'profile_visibility': 'Profile Visibility',
  'support': 'Support',
  'help_center': 'Help Center',
  'contact_support': 'Contact Support',
  'report_bug': 'Report a Bug',
  'my_reports': 'My Reports',
  'about': 'About',
  'terms_of_service': 'Terms of Service',
  'privacy_policy': 'Privacy Policy',
  'app_version': 'App Version 1.0.0',

  // Auth
  'login': 'Login',
  'register': 'Register',
  'email': 'Email',
  'password': 'Password',
  'forgot_password': 'Forgot Password?',
  'no_account': "Don't have an account?",
  'has_account': 'Already have an account?',
  'sign_up': 'Sign Up',
  'log_in': 'Log In',
  'verify_email': 'Verify Email',
  'otp_sent': 'We sent a code to',
  'enter_otp': 'Enter the 6-digit code',
  'verify': 'Verify',
  'resend_code': 'Resend Code',
  'didnt_receive': "Didn't receive the code?",
  'create_password': 'Create Password',
  'confirm_password': 'Confirm Password',
  'reset_password': 'Reset Password',
  'send_reset_link': 'Send Reset Link',

  // Home
  'featured_properties': 'Featured Properties',
  'nearby': 'Nearby',
  'see_all': 'See All',
  'per_month': '/month',
  'bedrooms': 'Bedrooms',
  'bathrooms': 'Bathrooms',

  // Property
  'property_details': 'Property Details',
  'about_property': 'About this property',
  'amenities': 'Amenities',
  'location': 'Location',
  'reviews': 'Reviews',
  'book_now': 'Book Now',
  'contact_agent': 'Contact Agent',
  'add_to_favorites': 'Add to Favorites',
  'monthly_rent': 'Monthly Rent',
  'security_deposit': 'Security Deposit',
  'service_fee': 'Service Fee',
  'total_amount': 'Total Amount',

  // Bookings
  'my_bookings': 'My Bookings',
  'active_bookings': 'Active',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'pending': 'Pending',
  'booking_reference': 'Booking Reference',
  'booking_date': 'Booking Date',
  'move_in_date': 'Move-In Date',
  'confirm_booking': 'Confirm Booking',
  'cancel_booking': 'Cancel Booking',
  'mark_satisfied': 'Mark as Satisfied',
  'raise_dispute': 'Raise Dispute',
  'view_receipt': 'View Receipt',

  // Messages
  'conversations': 'Conversations',
  'no_messages': 'No messages yet',
  'type_message': 'Type a message...',
  'send': 'Send',

  // Profile
  'my_profile': 'My Profile',
  'edit_profile': 'Edit Profile',
  'first_name': 'First Name',
  'last_name': 'Last Name',
  'phone': 'Phone',
  'bio': 'Bio',
  'save_changes': 'Save Changes',
  'sign_out': 'Sign Out',
  'delete_account': 'Delete Account',

  // Notifications
  'no_notifications': 'No notifications',
  'mark_all_read': 'Mark all as read',
  'new_booking_request': 'New Booking Request',
  'payment_confirmed': 'Payment Confirmed',
  'booking_completed': 'Booking Completed',
  'funds_released': 'Funds Released',
  'dispute_opened': 'Dispute Opened',

  // General
  'loading': 'Loading...',
  'error': 'Error',
  'retry': 'Retry',
  'cancel': 'Cancel',
  'confirm': 'Confirm',
  'yes': 'Yes',
  'no': 'No',
  'ok': 'OK',
  'success': 'Success',
  'failed': 'Failed',
  'saved': 'Saved',
  'deleted': 'Deleted',
  'updated': 'Updated',
  'currency_symbol': '₦',
  'ngn': 'NGN',
};

const Map<String, String> _yoruba = {
  // Navigation
  'nav_home': 'Ile',
  'nav_search': 'Wa',
  'nav_bookings': 'Iforọwọle',
  'nav_messages': 'Ifiranṣẹ',
  'nav_profile': 'Profaili',

  // Settings
  'settings': 'Eto',
  'notifications': 'Ifiranṣẹ',
  'push_notifications': 'Ifiranṣẹ Push',
  'email_notifications': 'Ifiranṣẹ Imel',
  'sms_notifications': 'Ifiranṣẹ SMS',
  'appearance': 'Irin-ajo',
  'dark_mode': 'Ipo Okunkun',
  'dark_mode_enabled': 'Ipo okunkun ti mo si',
  'light_mode_enabled': 'Ipo imọlẹ ti mo si',
  'large_text': 'Ọrọ Nla',
  'text_size_default': 'Ipo ọrọ: Apapọ (1.0x)',
  'text_size_large': 'Ipo ọrọ: Nla (1.3x)',
  'large_text_enabled': 'Ọrọ nla ti mo si',
  'large_text_disabled': 'Ọrọ nla ti mo pa',
  'language': 'Ede',
  'privacy': 'Ipiliti',
  'change_password': 'Yi Okọwọle',
  'biometric_login': 'Wọle Nipa Ara',
  'profile_visibility': 'Irin-ajo Profaili',
  'support': 'Atilẹyin',
  'help_center': 'Ile Iraisi',
  'contact_support': 'Ba Atilẹyin Sọrọ',
  'report_bug': 'Fi Bug Ji',
  'my_reports': 'Awọn Ijiroro Mi',
  'about': 'Nipa',
  'terms_of_service': 'Ohun Iṣe Esi',
  'privacy_policy': 'Eto Ipiliti',
  'app_version': 'Iye Apo 1.0.0',

  // Auth
  'login': 'Wọle',
  'register': 'Forọwọle',
  'email': 'Imel',
  'password': 'Ọọmọ',
  'forgot_password': 'Gbagbọ Ọọmọ?',
  'no_account': 'Ko ni akọnti?',
  'has_account': 'Ni akọnti tan?',
  'sign_up': 'Forọwọle',
  'log_in': 'Wọle',
  'verify_email': 'Jẹrisi Imel',
  'otp_sent': 'A ti fi code ranṣẹ si',
  'enter_otp': 'Tẹ code mejeji',
  'verify': 'Jẹrisi',
  'resend_code': 'Tun fi Code Ranṣẹ',
  'didnt_receive': 'Ko ri code naa?',
  'create_password': 'Ṣẹda Ọọmọ',
  'confirm_password': 'Jẹrisi Ọọmọ',
  'reset_password': 'Tun Ọọmọ',
  'send_reset_link': 'Fi Akọsile Ranṣẹ',

  // Home
  'featured_properties': 'Ile Ti A Fi Han',
  'nearby': 'Nisosinsin',
  'see_all': 'Wo Gbogbo',
  'per_month': '/oṣù',
  'bedrooms': 'Yara Sùn',
  'bathrooms': 'Igbámi',

  // Property
  'property_details': 'Alaye Ile',
  'about_property': 'Nipa ile yii',
  'amenities': 'Ohun Iṣọra',
  'location': 'Ibi',
  'reviews': 'Àtúnṣe',
  'book_now': 'Fi Sọtẹlẹ',
  'contact_agent': 'Ba Ajeji Sọrọ',
  'add_to_favorites': 'Fi Si Awọn Ti O Fẹ',
  'monthly_rent': 'Owó Oṣù',
  'security_deposit': 'Idogba Aabo',
  'service_fee': 'Owó Iṣẹ',
  'total_amount': 'Lapapọ',

  // Bookings
  'my_bookings': 'Awọn Iforọwọle Mi',
  'active_bookings': 'Ti Iṣẹ',
  'completed': 'Ti Parí',
  'cancelled': 'Ti Fagile',
  'pending': 'N Duro',
  'booking_reference': 'Ifiranṣẹ Iforọwọle',
  'booking_date': 'Ọjọ Iforọwọle',
  'move_in_date': 'Ọjọ Ibúgbé',
  'confirm_booking': 'Jẹrisi Iforọwọle',
  'cancel_booking': 'Fagile Iforọwọle',
  'mark_satisfied': 'Wi Pe O Ku Iwọ',
  'raise_dispute': 'Fi Arọ Si',
  'view_receipt': 'Wo Iwọ',

  // Messages
  'conversations': 'Ijiroro',
  'no_messages': 'Ko si ifiranṣẹ keji',
  'type_message': 'Kọ ifiranṣẹ...',
  'send': 'Fi Ranṣẹ',

  // Profile
  'my_profile': 'Profaili Mi',
  'edit_profile': 'Ṣe Profaili',
  'first_name': 'Orúkọ',
  'last_name': 'Orílẹ̀-èdè',
  'phone': 'Fóònù',
  'bio': 'Ìtàn',
  'save_changes': 'Fi Iyọ Nu',
  'sign_out': 'Jáde',
  'delete_account': 'Pa Akọntì',

  // Notifications
  'no_notifications': 'Ko si ifiranṣẹ keji',
  'mark_all_read': 'Jẹrisi Gbogbo',
  'new_booking_request': 'Ifọwọlẹ Tuntun',
  'payment_confirmed': 'Owó Ti Jẹrisi',
  'booking_completed': 'Iforọwọle Ti Parí',
  'funds_released': 'Owó Ti Kọjá',
  'dispute_opened': 'Arọ Ti Si',

  // General
  'loading': 'N Ṣiṣẹ...',
  'error': 'Àṣìṣe',
  'retry': 'Tun Try',
  'cancel': 'Fagile',
  'confirm': 'Jẹrisi',
  'yes': 'Bẹẹni',
  'no': 'Rara',
  'ok': 'Ó Dára',
  'success': 'Àṣeyọrí',
  'failed': 'Kùnà',
  'saved': 'Ti Fi Ipọ',
  'deleted': 'Ti Pa',
  'updated': 'Ti Ṣe Tuntun',
  'currency_symbol': '₦',
  'ngn': 'NGN',
};

const Map<String, String> _pidgin = {
  // Navigation
  'nav_home': 'House',
  'nav_search': 'Search',
  'nav_bookings': 'Booking',
  'nav_messages': 'Message',
  'nav_profile': 'Your Profile',

  // Settings
  'settings': 'Setting',
  'notifications': 'Notification',
  'push_notifications': 'Push Notification',
  'email_notifications': 'Email Notification',
  'sms_notifications': 'SMS Notification',
  'appearance': 'How E Look',
  'dark_mode': 'Dark Mode',
  'dark_mode_enabled': 'Dark mode don set',
  'light_mode_enabled': 'Light mode don set',
  'large_text': 'Big Text',
  'text_size_default': 'Text size: Normal (1.0x)',
  'text_size_large': 'Text size: Big (1.3x)',
  'large_text_enabled': 'Big text don set',
  'large_text_disabled': 'Big text don off',
  'language': 'Wetin You Sabi Talk',
  'privacy': 'Your Privacy',
  'change_password': 'Change Password',
  'biometric_login': 'Use Your Finger',
  'profile_visibility': 'Who Fit See You',
  'support': 'We Dey Help You',
  'help_center': 'Help Center',
  'contact_support': 'Talk To Us',
  'report_bug': 'Report Problem',
  'my_reports': 'My Report',
  'about': 'About Us',
  'terms_of_service': 'How We Dey Work',
  'privacy_policy': 'Privacy Rule',
  'app_version': 'App Version 1.0.0',

  // Auth
  'login': 'Login',
  'register': 'Register',
  'email': 'Email',
  'password': 'Password',
  'forgot_password': 'You Forget Password?',
  'no_account': 'You no get account?',
  'has_account': 'You get account already?',
  'sign_up': 'Sign Up',
  'log_in': 'Log In',
  'verify_email': 'Confirm Your Email',
  'otp_sent': 'We don send code go',
  'enter_otp': 'Put the 6 number code',
  'verify': 'Confirm',
  'resend_code': 'Send Code Again',
  'didnt_receive': 'You no see the code?',
  'create_password': 'Create Password',
  'confirm_password': 'Confirm Password',
  'reset_password': 'Reset Password',
  'send_reset_link': 'Send Reset Link',

  // Home
  'featured_properties': 'Fine House Wey We Pick',
  'nearby': 'Near You',
  'see_all': 'See All',
  'per_month': '/month',
  'bedrooms': 'Room',
  'bathrooms': 'Bathroom',

  // Property
  'property_details': 'How The House Be',
  'about_property': 'About this house',
  'amenities': 'Things Wey Dey Inside',
  'location': 'Where E Dey',
  'reviews': 'What People Talk',
  'book_now': 'Book Now',
  'contact_agent': 'Talk To Agent',
  'add_to_favorites': 'Add To Your List',
  'monthly_rent': 'Rent Per Month',
  'security_deposit': 'Deposit',
  'service_fee': 'Service Money',
  'total_amount': 'Total Money',

  // Bookings
  'my_bookings': 'My Booking',
  'active_bookings': 'Active',
  'completed': 'Don Finish',
  'cancelled': 'Don Cancel',
  'pending': 'Dey Wait',
  'booking_reference': 'Booking Number',
  'booking_date': 'When You Book',
  'move_in_date': 'When You Go Move In',
  'confirm_booking': 'Confirm Booking',
  'cancel_booking': 'Cancel Booking',
  'mark_satisfied': 'Say You Don Satisfied',
  'raise_dispute': 'Raise Problem',
  'view_receipt': 'See Your Receipt',

  // Messages
  'conversations': 'Chat',
  'no_messages': 'No message yet',
  'type_message': 'Type your message...',
  'send': 'Send',

  // Profile
  'my_profile': 'My Profile',
  'edit_profile': 'Edit Profile',
  'first_name': 'Your Name',
  'last_name': 'Your Surname',
  'phone': 'Phone Number',
  'bio': 'About You',
  'save_changes': 'Save',
  'sign_out': 'Comot',
  'delete_account': 'Delete Account',

  // Notifications
  'no_notifications': 'No notification yet',
  'mark_all_read': 'Mark All',
  'new_booking_request': 'New Booking',
  'payment_confirmed': 'Money Don Enter',
  'booking_completed': 'Booking Don Finish',
  'funds_released': 'Money Don Release',
  'dispute_opened': 'Problem Don Open',

  // General
  'loading': 'E Dey Load...',
  'error': 'Something Happen',
  'retry': 'Try Again',
  'cancel': 'Cancel',
  'confirm': 'Confirm',
  'yes': 'Na So',
  'no': 'No',
  'ok': 'OK',
  'success': 'E Work!',
  'failed': 'E No Work',
  'saved': 'Dem Don Save',
  'deleted': 'Dem Don Delete',
  'updated': 'Dem Don Update',
  'currency_symbol': '₦',
  'ngn': 'NGN',
};
