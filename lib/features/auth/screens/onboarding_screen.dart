import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

/// AILA Beauty Boutique — onboarding carousel.
///
/// Mirrors the Lovable onboarding design: a tall image stage (58vh) with a
/// softly rounded base that fades into pearl, a quiet "Skip" pill, then an
/// eyebrow · display title · body block, page dots, and a rose-gradient CTA
/// that reads "التالي" until the final slide, where it becomes "إنشاء حساب".
class OnboardingScreen extends StatefulWidget {
  /// Called when the user skips the welcome (continue browsing as guest).
  final VoidCallback onSkip;

  /// Called from the final CTA (create an account → proceed to auth).
  final VoidCallback onCreateAccount;

  const OnboardingScreen({
    super.key,
    required this.onSkip,
    required this.onCreateAccount,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_1.jpg',
      eyebrow: 'طقوس منتقاة',
      title: 'جمالٌ راقٍ.',
      body:
          'اكتشفي تشكيلة مختارة بعناية من العناية بالبشرة والمكياج الفاخر، مصمّمة للمرأة العصرية.',
    ),
    _OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_2.jpg',
      eyebrow: 'دار AILA',
      title: 'فخامة ناعمة تصلكِ.',
      body:
          'من السيرومات المخمليّة إلى أحمر الشفاه الساتان — كل تفصيلة محسوبة، وكل منتج محبوب.',
    ),
    _OnboardingSlide(
      image: 'assets/images/onboarding/onboarding_3.jpg',
      eyebrow: 'روتينكِ',
      title: 'بوتيك في يدكِ.',
      body:
          'اختيارات تناسبكِ، وعروض حصريّة، ودفع سلس. قصّة جمالكِ تبدأ من هنا.',
    ),
  ];

  final PageController _pageController = PageController();
  int _index = 0;

  bool get _isLastSlide => _index == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPrimaryTap() {
    if (_isLastSlide) {
      widget.onCreateAccount();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight = (MediaQuery.sizeOf(context).height * 0.58).clamp(
      360.0,
      560.0,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.pearl,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Column(
            children: [
              // ── Image stage (swipeable) with rounded base + pearl fade ──
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(40),
                        ),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _slides.length,
                          onPageChanged: (i) => setState(() => _index = i),
                          itemBuilder: (context, i) {
                            return _SlideImage(assetPath: _slides[i].image);
                          },
                        ),
                      ),
                    ),

                    // Bottom fade into the pearl content area.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 128,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00FFF8F7), AppColors.pearl],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Skip pill (trailing top corner).
                    SafeArea(
                      bottom: false,
                      child: Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: _SkipPill(onTap: widget.onSkip),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Eyebrow · title · body (cross-fades with the slide).
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        child: _SlideText(
                          key: ValueKey<int>(_index),
                          slide: _slides[_index],
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PageDots(count: _slides.length, index: _index),
                          const SizedBox(height: 24),
                          _RoseButton(
                            label: _isLastSlide ? 'إنشاء حساب' : 'التالي',
                            onTap: _onPrimaryTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String image;
  final String eyebrow;
  final String title;
  final String body;

  const _OnboardingSlide({
    required this.image,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
}

/// Full-bleed slide photo on a blush ground, with a soft brand fallback.
class _SlideImage extends StatelessWidget {
  final String assetPath;

  const _SlideImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.blushGradient),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'AILA',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
              color: AppColors.roseGold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Eyebrow · display title · body — the text block for a slide.
class _SlideText extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideText({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          slide.eyebrow,
          style: GoogleFonts.cairo(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.roseGold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          slide.title,
          style: GoogleFonts.cairo(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.mauve,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          slide.body,
          style: GoogleFonts.cairo(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: AppColors.taupe,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

/// Animated page indicator — active dot widens into a rose-gradient bar.
class _PageDots extends StatelessWidget {
  final int count;
  final int index;

  const _PageDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.roseGradient : null,
            color: isActive ? null : AppColors.blush,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}

/// Full-width rose-gradient pill CTA.
class _RoseButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RoseButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: AppColors.roseGradient,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: AppColors.roseGold.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: AppColors.pearl,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quiet frosted "Skip" pill in the image corner.
class _SkipPill extends StatelessWidget {
  final VoidCallback onTap;

  const _SkipPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'تخطّي',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.taupe,
            ),
          ),
        ),
      ),
    );
  }
}
