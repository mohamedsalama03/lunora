import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class ReturnExchangePolicyScreen extends StatelessWidget {
  const ReturnExchangePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      body: SafeArea(
        child: Column(
          children: [
            const _PolicyTopBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: const [
                  _PolicyHeroCard(),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'متى يمكن طلب الاسترجاع أو الاستبدال؟'),
                  SizedBox(height: 12),
                  _PolicyCard(
                    children: [
                      _PolicyPoint(
                        icon: AppIcons.check_circle_outline_rounded,
                        title: 'وجود خلل أو عيب واضح',
                        description:
                            'إذا وصل المنتج بحالة غير سليمة أو ظهر به عيب واضح عند الاستلام.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.inventory_2_outlined,
                        title: 'استلام منتج مختلف',
                        description:
                            'إذا كان المنتج المستلم مختلفاً عن المنتج الذي تم طلبه من التطبيق.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.receipt_long_outlined,
                        title: 'عدم مطابقة المواصفات',
                        description:
                            'إذا كان المنتج لا يطابق الوصف أو المواصفات المعروضة عند الشراء.',
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'الشروط العامة'),
                  SizedBox(height: 12),
                  _PolicyCard(
                    children: [
                      _PolicyPoint(
                        icon: AppIcons.verified_user_rounded,
                        title: 'حالة المنتج',
                        description:
                            'يجب أن يكون المنتج بحالته الأصلية قدر الإمكان، مع كامل الملحقات والتغليف إن وجدت.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.access_time_rounded,
                        title: 'سرعة التواصل',
                        description:
                            'يرجى التواصل مع الدعم فور ملاحظة المشكلة حتى تتم مراجعتها قبل إغلاق الطلب.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.image_outlined,
                        title: 'توفر بيانات الطلب والإثبات',
                        description:
                            'قد يطلب فريق الدعم رقم الطلب أو صورة للمنتج أو الإيصال أو رسالة الدفع لتأكيد الحالة.',
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'حالات قد لا تقبل'),
                  SizedBox(height: 12),
                  _PolicyCard(
                    children: [
                      _PolicyPoint(
                        icon: AppIcons.warning_amber_rounded,
                        title: 'استخدام المنتج أو تلفه بعد الاستلام',
                        description:
                            'قد لا يتم قبول الطلب إذا تغيرت حالة المنتج بسبب الاستخدام أو سوء الحفظ.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.close_rounded,
                        title: 'نقص الملحقات أو التغليف',
                        description:
                            'قد تتأثر الموافقة إذا كانت ملحقات المنتج أو التغليف الأساسي غير متوفرة.',
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'خطوات تقديم الطلب'),
                  SizedBox(height: 12),
                  _StepsCard(),
                  SizedBox(height: 22),
                  _SupportNoticeCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyTopBar extends StatelessWidget {
  const _PolicyTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          _CircleActionButton(
            icon: AppIcons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            'الاسترجاع والاستبدال',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 42, height: 42),
        ],
      ),
    );
  }
}

class _PolicyHeroCard extends StatelessWidget {
  const _PolicyHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFE3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primaryUltraLight.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              AppIcons.refresh_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'سياسة الاسترجاع والاستبدال',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نهدف في ${AppConstants.appName} إلى أن تكون تجربة الشراء واضحة ومطمئنة. هذه الصفحة توضّح الإرشادات العامة لمراجعة طلبات الاسترجاع والاستبدال.',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final List<Widget> children;

  const _PolicyCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE3E6)),
      ),
      child: Column(children: children),
    );
  }
}

class _PolicyPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PolicyPoint({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryUltraLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE3E6)),
      ),
      child: const Column(
        children: [
          _StepRow(number: '1', text: 'افتح صفحة الدعم من الملف الشخصي.'),
          _StepRow(number: '2', text: 'جهّز رقم الطلب وصورة توضّح المشكلة.'),
          _StepRow(number: '3', text: 'أرسل وصفاً مختصراً للحالة لفريق الدعم.'),
          _StepRow(
            number: '4',
            text: 'انتظر مراجعة الطلب وتأكيد الإجراء المناسب.',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;

  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportNoticeCard extends StatelessWidget {
  const _SupportNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            AppIcons.headset_mic_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'لأي حالة غير واضحة، تواصل مع الدعم وسيتم توجيهك حسب حالة الطلب والمنتج.',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyDivider extends StatelessWidget {
  const _PolicyDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFEFE3E6));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEFE3E6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
