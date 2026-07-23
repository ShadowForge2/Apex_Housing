import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/app_colors.dart';
import 'theme/theme_provider.dart';
import 'theme/text_scale_provider.dart';
import 'models/user_role.dart';
import 'navigation/main_shell.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/property/property_detail_screen.dart';
import 'screens/map/map_explore_screen.dart';
import 'screens/landlord/add_property_screen.dart';
import 'screens/landlord/edit_property_screen.dart';
import 'screens/landlord/earnings_screen.dart';
import 'screens/landlord/tenant_detail_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/profile/bank_account_screen.dart';
import 'screens/profile/signature_screen.dart';
import 'services/token_storage.dart';
import 'services/api_client.dart';
import 'services/user_service.dart';
import 'services/deep_link_service.dart';
import 'services/locale_service.dart';
import 'services/security_service.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
final ThemeProvider _themeProvider = ThemeProvider();
final TextScaleProvider _textScaleProvider = TextScaleProvider();
final LocaleService _localeService = LocaleService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiClient.instance.init();
  ApiClient.instance.setNavigatorKey(_navKey);

  // Run security checks (non-blocking, logs warnings)
  SecurityService.instance.runChecks().then((_) {
    final report = SecurityService.instance.getReport();
    if (report['compromised'] == true) {
      debugPrint('[SECURITY] Device compromise detected: $report');
    }
  });

  // Restore persisted preferences before first frame
  await Future.wait([
    _themeProvider.init(),
    _textScaleProvider.init(),
    _localeService.init(),
  ]);

  // Request notification permission (non-blocking)
  _requestNotificationPermission();

  runApp(const ApexHousingApp());
}

void _requestNotificationPermission() async {
  try {
    final permission = await Permission.notification.status;
    if (permission.isDenied || permission.isPermanentlyDenied) {
      await Permission.notification.request();
    }
  } catch (_) {}
}

class ApexHousingApp extends StatefulWidget {
  const ApexHousingApp({super.key});

  @override
  State<ApexHousingApp> createState() => _ApexHousingAppState();
}

class _ApexHousingAppState extends State<ApexHousingApp> {
  UserRole _currentRole = UserRole.tenant;
  bool _roleLoaded = false;
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    _loadPersistedRole();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _deepLinkService.init();
    _deepLinkService.propertySlugStream.listen((slug) {
      final nav = _navKey.currentState;
      if (nav != null) {
        nav.pushNamed('/property-detail', arguments: 'slug:$slug');
      }
    });
    _deepLinkService.checkInitialLink();
  }

  Future<void> _loadPersistedRole() async {
    final storage = TokenStorage();
    final loggedIn = await storage.isLoggedIn();
    if (loggedIn) {
      final lastRole = await storage.getLastActiveRole();
      if (lastRole != null) {
        final role = lastRole.toUpperCase() == 'LANDLORD' ? UserRole.landlord : UserRole.tenant;
        if (mounted) setState(() { _currentRole = role; _roleLoaded = true; });
        _syncRoleFromServer();
        return;
      }
    }
    if (mounted) setState(() => _roleLoaded = true);
  }

  Future<void> _syncRoleFromServer() async {
    try {
      final profile = await UserService().getMyProfile();
      final serverRole = profile.role?.toUpperCase();
      if (serverRole == null) return;
      final correctRole = serverRole == 'LANDLORD' ? UserRole.landlord : UserRole.tenant;
      if (mounted && _currentRole != correctRole) {
        setState(() => _currentRole = correctRole);
        await TokenStorage().saveLastActiveRole(serverRole);
      }
    } catch (_) {}
  }

  void _switchRole() {
    final newRole = _currentRole == UserRole.tenant ? UserRole.landlord : UserRole.tenant;
    setState(() => _currentRole = newRole);
    TokenStorage().saveLastActiveRole(newRole == UserRole.landlord ? 'LANDLORD' : 'TENANT');
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      model: _themeProvider,
      child: ListenableBuilder(
        listenable: Listenable.merge([_themeProvider, _textScaleProvider, _localeService]),
        builder: (context, _) {
          return TextScaleScope(
            model: _textScaleProvider,
            child: RoleProvider(
              role: _currentRole,
              switchRole: _switchRole,
              child: DefaultTextStyle(
                style: const TextStyle(decoration: TextDecoration.none),
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(_textScaleProvider.scaleFactor),
                  ),
                  child: MaterialApp(
                    title: 'APEX Housing',
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    darkTheme: AppTheme.dark,
                    themeMode: _themeProvider.themeMode,
                    locale: _localeService.locale,
                    supportedLocales: const [
                      Locale('en'),
                      Locale('yo'),
                      Locale('pcm'),
                    ],
                    navigatorKey: _navKey,
                    initialRoute: '/splash',
                    onGenerateRoute: (settings) {
                      final nav = _navKey.currentState!;
                      switch (settings.name) {
                        case '/splash':
                          return MaterialPageRoute(
                            builder: (_) => SplashScreen(
                              onComplete: () async {
                                final storage = TokenStorage();
                                final loggedIn = await storage.isLoggedIn();
                                if (loggedIn) {
                                  final lastRole = await storage.getLastActiveRole();
                                  if (lastRole != null) {
                                    final role = lastRole.toUpperCase() == 'LANDLORD' ? UserRole.landlord : UserRole.tenant;
                                    if (_currentRole != role) {
                                      setState(() => _currentRole = role);
                                    }
                                  }
                                  nav.pushReplacementNamed('/home');
                                } else {
                                  nav.pushReplacementNamed('/login');
                                }
                              },
                            ),
                          );
                        case '/login':
                          return MaterialPageRoute(
                            builder: (_) => LoginScreen(
                              onLogin: () async {
                                final storage = TokenStorage();
                                final initialRole = await storage.getInitialRole();
                                if (initialRole != null) {
                                  final role = initialRole.toUpperCase() == 'LANDLORD' ? UserRole.landlord : UserRole.tenant;
                                  setState(() => _currentRole = role);
                                  await storage.saveLastActiveRole(initialRole);
                                }
                                nav.pushNamedAndRemoveUntil('/home', (_) => false);
                              },
                              onGoToRegister: () => nav.pushNamed('/register'),
                            ),
                          );
                        case '/register':
                          return MaterialPageRoute(
                            builder: (_) => RegisterScreen(
                              onRegister: (email) => nav.pushNamed('/otp', arguments: email),
                              onGoToLogin: () => nav.pop(),
                            ),
                          );
                        case '/otp':
                          final email = settings.arguments as String?;
                          return MaterialPageRoute(
                            builder: (_) => OTPScreen(
                              onVerified: () => nav.pushNamedAndRemoveUntil('/home', (_) => false),
                              email: email,
                            ),
                          );
                        case '/home':
                          return MaterialPageRoute(builder: (_) => const MainShell());
                        case '/property-detail':
                          final args = settings.arguments;
                          if (args is String) {
                            if (args.startsWith('slug:')) {
                              final slug = args.substring(5);
                              return MaterialPageRoute(
                                builder: (_) => PropertyDetailScreen.fromSlug(slug: slug),
                              );
                            }
                            return MaterialPageRoute(
                              builder: (_) => PropertyDetailScreen.fromPropertyId(id: args),
                            );
                          }
                          final id = args;
                          if (id == null) return MaterialPageRoute(builder: (_) => const Scaffold());
                          return MaterialPageRoute(
                            builder: (_) => PropertyDetailScreen.fromPropertyId(id: id.toString()),
                          );
                        case '/map':
                          return MaterialPageRoute(
                            builder: (_) => MapExploreScreen(
                              onPropertyDetail: (propertyId) => nav.pushNamed('/property-detail', arguments: propertyId),
                            ),
                          );
                        case '/add-property':
                          return MaterialPageRoute(builder: (_) => const AddPropertyScreen());
                        case '/edit-property':
                          return MaterialPageRoute(builder: (_) => const EditPropertyScreen());
                        case '/notifications':
                          return MaterialPageRoute(builder: (_) => const NotificationsScreen());
                        case '/settings':
                          return MaterialPageRoute(builder: (_) => const SettingsScreen());
                        case '/earnings':
                          return MaterialPageRoute(builder: (_) => const EarningsScreen());
                        case '/bank-account':
                          final isPostSignup = settings.arguments as bool? ?? false;
                          return MaterialPageRoute(
                            builder: (_) => BankAccountScreen(isPostSignup: isPostSignup),
                          );
                        case '/signature':
                          final isPostSignup = settings.arguments as bool? ?? false;
                          return MaterialPageRoute(
                            builder: (_) => SignatureScreen(isPostSignup: isPostSignup),
                          );
                        case '/tenant-detail':
                          final args = settings.arguments as Map<String, dynamic>? ?? {};
                          return MaterialPageRoute(
                            builder: (_) => TenantDetailScreen(
                              name: args['name'] ?? 'Tenant',
                              property: args['property'] ?? '',
                              rent: args['rent'] ?? 0,
                              leaseEnd: args['leaseEnd'] ?? '',
                              status: args['status'] ?? 'active',
                              avatar: args['avatar'] ?? 'T',
                            ),
                          );
                        default:
                          return MaterialPageRoute(
                            builder: (_) => const Scaffold(body: Center(child: Text('404'))),
                          );
                      }
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
