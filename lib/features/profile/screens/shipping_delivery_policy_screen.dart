import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class ShippingDeliveryPolicyScreen extends StatelessWidget {
  const ShippingDeliveryPolicyScreen({super.key});

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
                  _SectionTitle(title: 'نطاق التوصيل'),
                  SizedBox(height: 12),
                  _PolicyCard(
                    children: [
                      _PolicyPoint(
                        icon: AppIcons.location_on_outlined,
                        title: 'المدن المدعومة',
                        description:
                            'التوصيل متاح للمدن والمناطق التي تظهر داخل التطبيق عند إضافة العنوان أو إتمام الطلب.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.location_city_rounded,
                        title: 'خارج حدود مصراتة',
                        description:
                            'إذا كان العنوان خارج حدود مصراتة، يجب اختيار مدينة من القائمة المعتمدة حتى يتم قبول العنوان.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.my_location_rounded,
                        title: 'داخل مصراتة',
                        description:
                            'قد يتم احتساب رسوم التوصيل داخل مصراتة حسب الموقع والمسافة عند مراجعة الطلب.',
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'رسوم التوصيل'),
                  SizedBox(height: 12),
                  _PolicyCard(
                    children: [
                      _PolicyPoint(
                        icon: AppIcons.payment_rounded,
                        title: 'تظهر قبل تأكيد الطلب',
                        description:
                            'يعرض التطبيق رسوم التوصيل المتاحة قبل إكمال عملية الشراء حسب العنوان المختار.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.refresh_rounded,
                        title: 'قد تختلف حسب العنوان',
                        description:
                            'تُحسب الرسوم بناءً على المدينة أو موقع التوصيل، لذلك قد تختلف من عنوان لآخر.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.info_outline_rounded,
                        title: 'السعر النهائي في الطلب',
                        description:
                            'رسوم التوصيل المعتمدة هي التي تظهر في ملخص الطلب قبل الدفع أو تأكيد الطلب.',
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'تجهيز وتسليم الطلب'),
                  SizedBox(height: 12),
                  _PolicyCard(
                    children: [
                      _PolicyPoint(
                        icon: AppIcons.inventory_2_outlined,
                        title: 'تجهيز الطلب',
                        description:
                            'يبدأ تجهيز الطلب بعد تأكيد بيانات الشراء والدفع حسب طريقة الدفع المختارة.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.local_shipping_rounded,
                        title: 'متابعة الحالة',
                        description:
                            'يمكنك متابعة حالة الطلب من صفحة طلباتي، من التجهيز وحتى الشحن أو التوصيل.',
                      ),
                      _PolicyDivider(),
                      _PolicyPoint(
                        icon: AppIcons.phone_rounded,
                        title: 'التواصل عند الحاجة',
                        description:
                            'قد يتواصل معك فريق التوصيل أو الدعم عند الحاجة لتأكيد العنوان أو رقم الهاتف.',
                      ),
                    ],
                  ),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'قبل تأكيد الطلب'),
                  SizedBox(height: 12),
                  _ChecklistCard(),
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
            'الشحن والتوصيل',
            style: GoogleFonts.cairo(
              fontSize: 18,
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
              AppIcons.local_shipping_rounded,
              color: AppColors.primary,
              size: 28,
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'سياسة الشحن والتوصيل',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'توضح هذه الصفحة طريقة تعامل ${AppConstants.appName} مع العناوين، رسوم التوصيل، ومتابعة الطلب حتى وصوله إليك.',
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

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard();

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
          _ChecklistRow(text: 'تأكد من اختيار عنوان توصيل محفوظ وصحيح.'),
          _ChecklistRow(
            text: 'راجع رقم الهاتف حتى يتمكن فريق التوصيل من التواصل.',
          ),
          _ChecklistRow(text: 'تأكد أن المدينة ضمن المدن المدعومة في التطبيق.'),
          _ChecklistRow(text: 'راجع رسوم التوصيل في ملخص الطلب قبل التأكيد.'),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String text;

  const _ChecklistRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryUltraLight.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.check_rounded,
              color: AppColors.primary,
              size: 14,
              textDirection: TextDirection.ltr,
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
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'إذا كان عنوانك غير مدعوم أو ظهرت رسوم غير متوقعة، تواصل مع الدعم قبل تأكيد الطلب.',
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
