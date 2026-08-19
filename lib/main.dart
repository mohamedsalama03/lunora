import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api/api_client.dart';
import 'core/api/auth_repository.dart';
import 'core/constants/api_constants.dart';
import 'core/constants/app_constants.dart';
import 'core/navigation/app_navigator.dart';
import 'core/navigation/app_shell_controller.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_icons.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_notifications.dart';
import 'core/utils/debug_performance_logger.dart';
import 'features/addresses/models/address_model.dart';
import 'features/addresses/providers/address_provider.dart';
import 'features/addresses/repositories/address_repository.dart';
import 'features/addresses/screens/address_map_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/widgets/auth_required_dialog.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/cart/screens/cart_screen.dart';
import 'features/home/providers/home_provider.dart';
import 'features/home/repositories/app_banners_repository.dart';
import 'features/home/repositories/products_repository.dart';
import 'features/home/screens/home_screen.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'features/notifications/repositories/notifications_api_repository.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/orders/repositories/orders_repository.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/search/providers/search_provider.dart';
import 'features/search/screens/search_screen.dart';
import 'features/wallet/providers/wallet_provider.dart';
import 'features/wallet/repositories/wallet_repository.dart';
import 'features/wishlist/providers/wishlist_provider.dart';
import 'features/wishlist/screens/wishlist_screen.dart';
import 'shared/widgets/custom_navbar.dart';

Future<void> main() async {
  final startupStopwatch = Stopwatch()..start();
  DebugPerformanceLogger.log('startup', 'main() started');

  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final apiClient = ApiClient();
  apiClient.primeStoredTokenRead();
  final firebaseReady =
      await PushNotificationService.ensureFirebaseInitialized();
  DebugPerformanceLogger.log(
    'startup',
    'Firebase bootstrap finished | ready=$firebaseReady | elapsed=${startupStopwatch.elapsedMilliseconds}ms',
  );
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final publicDio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final appShellController = AppShellController();
  final notificationsProvider = NotificationsProvider();

  final authRepository = AuthRepository(apiClient: apiClient);
  final productsRepository = ProductsRepository(dio: publicDio);
  final appBannersRepository = AppBannersRepository(dio: publicDio);
  final walletRepository = WalletRepository(dio: apiClient.dio);
  final ordersRepository = OrdersRepository(dio: apiClient.dio);
  final notificationsApiRepository = NotificationsApiRepository(
    dio: apiClient.dio,
  );
  final addressRepository = AddressRepository(apiClient);

  final pushNotificationService = PushNotificationService(
    notificationsApiRepository: notificationsApiRepository,
    notificationsProvider: notificationsProvider,
    shellController: appShellController,
  );
  DebugPerformanceLogger.log(
    'startup',
    'Dependencies wired | elapsed=${startupStopwatch.elapsedMilliseconds}ms',
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<PushNotificationService>.value(value: pushNotificationService),
        ChangeNotifierProvider<AppShellController>.value(
          value: appShellController,
        ),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: notificationsProvider,
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authRepository: authRepository,
            pushNotificationService: pushNotificationService,
          )..initAuth(),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(
          create: (_) => HomeProvider(
            repository: productsRepository,
            appBannersRepository: appBannersRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SearchProvider(repository: productsRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => WalletProvider(repository: walletRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider(repository: ordersRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AddressProvider(addressRepository),
        ),
      ],
      child: const TasameemApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    startupStopwatch.stop();
    DebugPerformanceLogger.logElapsed(
      'startup',
      'First frame rendered',
      startupStopwatch,
    );
    DebugPerformanceLogger.log(
      'startup',
      'Scheduling PushNotificationService.initialize after idle delay',
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1200)).then((_) {
        DebugPerformanceLogger.log(
          'startup',
          'Running delayed PushNotificationService.initialize',
        );
        return pushNotificationService.initialize();
      }),
    );
  });
}

class TasameemApp extends StatelessWidget {
  const TasameemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _AuthScopedDataResetter(
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigator.navigatorKey,
        theme: AppTheme.lightTheme,
        home: const AppStartupGate(),
        builder: _buildDirectionalApp,
      ),
    );
  }
}

Widget _buildDirectionalApp(BuildContext context, Widget? child) {
  return Directionality(
    textDirection: TextDirection.rtl,
    child: child ?? const SizedBox.shrink(),
  );
}

class _AuthScopedDataResetter extends StatefulWidget {
  final Widget child;

  const _AuthScopedDataResetter({required this.child});

  @override
  State<_AuthScopedDataResetter> createState() =>
      _AuthScopedDataResetterState();
}

class _AuthScopedDataResetterState extends State<_AuthScopedDataResetter> {
  AuthProvider? _authProvider;
  String? _lastAuthScopeKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextAuthProvider = context.read<AuthProvider>();
    if (_authProvider == nextAuthProvider) {
      return;
    }

    _authProvider?.removeListener(_handleAuthScopeChanged);
    _authProvider = nextAuthProvider;
    _lastAuthScopeKey = _authScopeKey(nextAuthProvider);
    _authProvider?.addListener(_handleAuthScopeChanged);
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_handleAuthScopeChanged);
    super.dispose();
  }

  void _handleAuthScopeChanged() {
    final authProvider = _authProvider;
    if (authProvider == null || !mounted) {
      return;
    }

    final nextScopeKey = _authScopeKey(authProvider);
    if (nextScopeKey == _lastAuthScopeKey) {
      return;
    }

    _lastAuthScopeKey = nextScopeKey;
    context.read<OrdersProvider>().clearUserScopedData();
    context.read<AddressProvider>().clearUserScopedData();
    context.read<WalletProvider>().clearUserScopedData();
  }

  String _authScopeKey(AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      return 'guest';
    }

    return 'user:${authProvider.user?.id ?? 'pending'}';
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppStartupGate extends StatefulWidget {
  const AppStartupGate({super.key});

  @override
  State<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<AppStartupGate> {
  static const String _onboardingSeenKey = 'aila_onboarding_seen_v1';

  bool _isReady = false;
  bool _showOnboarding = false;
  bool _startWithAuthPrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapApp());
    });
  }

  Future<void> _bootstrapApp() async {
    final auth = context.read<AuthProvider>();
    final home = context.read<HomeProvider>();

    await auth.waitForInitialization();
    if (!mounted) {
      return;
    }

    if (!auth.isAuthenticated) {
      await _completeAsGuest();
      return;
    }

    await auth.waitForCurrentUserRefresh();
    if (!mounted) {
      return;
    }

    if (!auth.isAuthenticated) {
      await _completeAsGuest();
      return;
    }

    await home.ensureInitialDataLoaded();
    if (!mounted) {
      return;
    }

    // Authenticated users skip onboarding.
    _complete();
  }

  /// Guests see the AILA onboarding on first launch only.
  Future<void> _completeAsGuest() async {
    var seen = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      seen = prefs.getBool(_onboardingSeenKey) ?? false;
    } catch (_) {
      seen = true;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showOnboarding = !seen;
      _isReady = true;
    });
  }

  Future<void> _finishOnboarding({required bool authPrompt}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingSeenKey, true);
    } catch (_) {
      // Ignore persistence failures; just proceed into the app.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showOnboarding = false;
      _startWithAuthPrompt = authPrompt;
    });
  }

  void _complete() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const _StartupLoadingView();
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onSkip: () => _finishOnboarding(authPrompt: false),
        onCreateAccount: () => _finishOnboarding(authPrompt: true),
      );
    }

    return MainShell(showAuthPromptOnStart: _startWithAuthPrompt);
  }
}

class _StartupLoadingView extends StatefulWidget {
  const _StartupLoadingView();

  @override
  State<_StartupLoadingView> createState() => _StartupLoadingViewState();
}

class _StartupLoadingViewState extends State<_StartupLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _splashController;

  @override
  void initState() {
    super.initState();
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _splashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFFFF7F7),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF7F7),
        body: AnimatedBuilder(
          animation: _splashController,
          builder: (context, _) => CustomPaint(
            painter: _LovableSplashBackdropPainter(
              progress: _splashController.value,
            ),
            child: SafeArea(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 54),
                      child: Text(
                        'SOFT LUXURY BEAUTY',
                        style: TextStyle(
                          color: Color(0xFFD98A9A),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 5.2,
                        ),
                      ),
                    ),
                  ),
                  const _SplashDiamond(alignment: Alignment(0.59, -0.39)),
                  const _SplashDiamond(alignment: Alignment(-0.52, 0.49)),
                  Align(
                    alignment: const Alignment(0, -0.02),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _RitualHalo(progress: _splashController.value),
                        const SizedBox(height: 42),
                        _AnimatedAilaLogo(progress: _splashController.value),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _RitualProgress(progress: _splashController.value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LovableSplashBackdropPainter extends CustomPainter {
  final double progress;

  const _LovableSplashBackdropPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8F8), Color(0xFFFFF2F4), Color(0xFFFDE8EB)],
          stops: [0, 0.52, 1],
        ).createShader(bounds),
    );

    final breath = 0.94 + math.sin(progress * math.pi * 2) * 0.06;
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.12, size.height * 0.05),
      radius: size.width * 0.68 * breath,
      color: const Color(0x18D98A9A),
    );
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.91, size.height * 0.43),
      radius: size.width * 0.55,
      color: const Color(0x10B76E79),
    );
    _drawBloom(
      canvas,
      center: Offset(size.width * 0.77, size.height * 1.02),
      radius: size.width * 0.63 * breath,
      color: const Color(0x35D98A9A),
    );
  }

  void _drawBloom(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _LovableSplashBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SplashDiamond extends StatelessWidget {
  final Alignment alignment;

  const _SplashDiamond({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD98A9A), width: 0.8),
          ),
        ),
      ),
    );
  }
}

class _RitualHalo extends StatelessWidget {
  final double progress;

  const _RitualHalo({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 96,
      child: CustomPaint(painter: _RitualHaloPainter(progress)),
    );
  }
}

class _RitualHaloPainter extends CustomPainter {
  final double progress;

  const _RitualHaloPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
    final outerRect = Rect.fromCircle(center: center, radius: 44 + pulse * 2);

    canvas.drawCircle(
      center,
      43,
      Paint()
        ..color = const Color(0x18D98A9A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );
    canvas.drawArc(
      outerRect,
      progress * math.pi * 2,
      math.pi * 1.62,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4
        ..shader = const SweepGradient(
          colors: [Color(0x22D98A9A), Color(0x88D98A9A), Color(0xFFF2C7CF)],
        ).createShader(outerRect),
    );
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD98A9A), Color(0xFFB76E79)],
        ).createShader(Rect.fromCircle(center: center, radius: 6)),
    );
  }

  @override
  bool shouldRepaint(covariant _RitualHaloPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AnimatedAilaLogo extends StatelessWidget {
  final double progress;

  const _AnimatedAilaLogo({required this.progress});

  @override
  Widget build(BuildContext context) {
    final wave = 0.5 + math.sin(progress * math.pi * 2) * 0.5;
    final logoWidth = (MediaQuery.sizeOf(context).width * 0.62).clamp(
      230.0,
      300.0,
    );

    return Transform.translate(
      offset: Offset(0, (wave - 0.5) * 1.4),
      child: Transform.scale(
        scale: 0.992 + wave * 0.008,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: (1 - wave) * 0.35,
            sigmaY: (1 - wave) * 0.35,
          ),
          child: Image.asset(
            'assets/images/splash_page.png',
            width: logoWidth,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _RitualProgress extends StatelessWidget {
  final double progress;

  const _RitualProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final widthFactor =
        0.18 +
        Curves.easeInOutCubic.transform(
              0.5 + math.sin(progress * math.pi * 2) * 0.5,
            ) *
            0.64;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 2,
          child: Stack(
            children: [
              const Align(
                alignment: Alignment.center,
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x55D9A6B0),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: widthFactor,
                  child: Container(
                    height: 1.4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00B76E79),
                          Color(0xFFB76E79),
                          Color(0x00B76E79),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'PREPARING YOUR RITUAL',
          style: TextStyle(
            color: Color(0xFF8B6F73),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 4.2,
          ),
        ),
      ],
    );
  }
}

class MainShell extends StatefulWidget {
  final bool showAuthPromptOnStart;
  final bool showAddressMapOnStart;

  const MainShell({
    super.key,
    this.showAuthPromptOnStart = false,
    this.showAddressMapOnStart = false,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static final List<WidgetBuilder> _screenBuilders = <WidgetBuilder>[
    (_) => const HomeScreen(),
    (_) => const SearchScreen(),
    (_) => const WishlistScreen(),
    (_) => const ProfileScreen(),
    (_) => const CartScreen(),
  ];

  late final AppShellController _shellController;
  late final Set<int> _visitedIndices;
  bool _didShowAuthPrompt = false;
  bool _didShowAddressMapOnStart = false;

  @override
  void initState() {
    super.initState();
    _shellController = context.read<AppShellController>();
    _visitedIndices = <int>{_shellController.currentIndex};
    _shellController.addListener(_handleShellIndexChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      DebugPerformanceLogger.log('startup', 'MainShell first post-frame ready');
      context.read<PushNotificationService>().onShellReady();
      unawaited(context.read<HomeProvider>().ensureInitialDataLoaded());
      unawaited(_maybeShowInitialAuthPrompt());
      unawaited(_maybeShowAddressMapOnStart());
    });
  }

  @override
  void dispose() {
    _shellController.removeListener(_handleShellIndexChanged);
    super.dispose();
  }

  void _handleShellIndexChanged() {
    final currentIndex = _shellController.currentIndex;
    if (_visitedIndices.contains(currentIndex)) {
      return;
    }

    setState(() {
      _visitedIndices.add(currentIndex);
    });
  }

  Future<void> _maybeShowInitialAuthPrompt() async {
    if (_didShowAuthPrompt || !widget.showAuthPromptOnStart) {
      return;
    }

    _didShowAuthPrompt = true;

    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated || !mounted) {
      return;
    }

    final action = await showAuthRequiredDialog(
      context,
      barrierDismissible: false,
      badge: 'ابدأ كتصفح ضيف أو سجّل الآن',
      title: 'هل تريد تسجيل الدخول الآن؟',
      message:
          'يمكنك متابعة التصفح الآن كضيف، وعند الوصول إلى الدفع أو صفحة حسابك سنطلب منك تسجيل الدخول لإكمال التجربة بأمان.',
      primaryLabel: 'تسجيل الدخول',
      secondaryLabel: 'لاحقاً',
      icon: AppIcons.person_rounded,
    );

    if (!mounted || action != AuthPromptAction.login) {
      return;
    }

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(returnAfterAuth: true),
      ),
    );
  }

  Future<void> _maybeShowAddressMapOnStart() async {
    if (_didShowAddressMapOnStart || !widget.showAddressMapOnStart) {
      return;
    }

    _didShowAddressMapOnStart = true;

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || !mounted) {
      return;
    }

    final result = await Navigator.of(context).push<AddressModel>(
      MaterialPageRoute(builder: (_) => const AddressMapScreen()),
    );

    if (!mounted || result == null) {
      return;
    }

    AppNotifications.showSuccess(context, 'تم حفظ موقعك بنجاح');
  }

  Future<void> _handleNavigationTap(int index) async {
    final auth = context.read<AuthProvider>();
    final isProfileDestination = index == AppShellController.profileIndex;

    if (isProfileDestination && !auth.isAuthenticated) {
      final action = await showAuthRequiredDialog(
        context,
        badge: 'هذه الصفحة تحتاج حساباً',
        title: 'سجّل دخولك للوصول إلى حسابك',
        message:
            'صفحة حسابك تحتوي على طلباتك وعناوينك وبياناتك الشخصية، لذلك نحتاج إلى تسجيل الدخول قبل فتحها.',
        primaryLabel: 'تسجيل الدخول',
        secondaryLabel: 'لاحقاً',
        icon: AppIcons.person_rounded,
      );

      if (!mounted || action != AuthPromptAction.login) {
        return;
      }

      final didAuthenticate = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(returnAfterAuth: true),
        ),
      );

      if (!mounted || didAuthenticate != true) {
        return;
      }
    }

    _shellController.setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShellController>(
      builder: (context, shell, _) {
        final screens = List<Widget>.generate(_screenBuilders.length, (index) {
          if (!_visitedIndices.contains(index)) {
            return const SizedBox.shrink();
          }

          return _screenBuilders[index](context);
        });

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: IndexedStack(index: shell.currentIndex, children: screens),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: CustomNavBar(
              currentIndex: shell.currentIndex,
              onTap: _handleNavigationTap,
            ),
          ),
        );
      },
    );
  }
}
