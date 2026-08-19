import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_notifications.dart';
import '../../auth/providers/auth_provider.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      body: SafeArea(
        child: Column(
          children: [
            const _SupportTopBar(),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                children: const [
                  _SupportIntroCard(),
                  SizedBox(height: 18),
                  _SectionTitle(title: 'بيانات التواصل'),
                  SizedBox(height: 12),
                  _SupportContactCard(),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'كيف نقدر نساعدك؟'),
                  SizedBox(height: 12),
                  _SupportTopicGrid(),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'قبل التواصل مع الدعم'),
                  SizedBox(height: 12),
                  _SupportChecklistCard(),
                  SizedBox(height: 22),
                  _SectionTitle(title: 'أسئلة سريعة'),
                  SizedBox(height: 12),
                  _FaqCard(),
                  SizedBox(height: 22),
                  _CopySupportMessageCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportTopBar extends StatelessWidget {
  const _SupportTopBar();

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
            'الدعم',
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

class _SupportIntroCard extends StatelessWidget {
  const _SupportIntroCard();

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
              AppIcons.headset_mic_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'مركز مساعدة ${AppConstants.appName}',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر نوع المشكلة، راجع الإجابات السريعة، أو انسخ نموذج رسالة مرتب ليساعد فريق الدعم في فهم طلبك بسرعة.',
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportContactCard extends StatelessWidget {
  const _SupportContactCard();

  static const String contactPhone = '0912884731';
  static const String whatsappPhone = '0914363102';
  static const String supportEmail = 'support@aila.ly';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE3E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          _ContactRow(
            icon: AppIcons.phone_rounded,
            title: 'رقم الاتصال',
            value: contactPhone,
          ),
          _ContactDivider(),
          _ContactRow(
            icon: AppIcons.phone_iphone_rounded,
            title: 'رقم الواتساب',
            value: whatsappPhone,
          ),
          _ContactDivider(),
          _ContactRow(
            icon: AppIcons.email_outlined,
            title: 'البريد الإلكتروني',
            value: supportEmail,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryUltraLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => _copyContactValue(context),
            icon: const Icon(AppIcons.copy_rounded, size: 20),
            color: AppColors.primary,
            tooltip: 'نسخ',
          ),
        ],
      ),
    );
  }

  void _copyContactValue(BuildContext context) {
    Clipboard.setData(ClipboardData(text: value));
    AppNotifications.showSuccess(context, 'تم نسخ $title');
  }
}

class _ContactDivider extends StatelessWidget {
  const _ContactDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFEFE3E6));
  }
}

class _SupportTopicGrid extends StatelessWidget {
  const _SupportTopicGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SupportTopicCard(
                icon: AppIcons.receipt_long_outlined,
                title: 'الطلبات',
                subtitle: 'تتبع، تعديل، أو مشكلة في حالة الطلب',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _SupportTopicCard(
                icon: AppIcons.payment_rounded,
                title: 'الدفع',
                subtitle: 'بطاقة، حوالة، محفظة، أو تأكيد عملية',
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SupportTopicCard(
                icon: AppIcons.local_shipping_rounded,
                title: 'التوصيل',
                subtitle: 'العنوان، المدينة، أو موعد الاستلام',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _SupportTopicCard(
                icon: AppIcons.person_outline_rounded,
                title: 'الحساب',
                subtitle: 'تسجيل الدخول، البيانات، أو كلمة المرور',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SupportTopicCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SupportTopicCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE3E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 25),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportChecklistCard extends StatelessWidget {
  const _SupportChecklistCard();

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
          _ChecklistRow(text: 'رقم الطلب إذا كانت المشكلة مرتبطة بشراء معين'),
          _ChecklistRow(text: 'صورة الإيصال عند الدفع بالحوالة أو التحويل'),
          _ChecklistRow(text: 'رقم الهاتف والعنوان عند مشاكل التوصيل'),
          _ChecklistRow(text: 'لقطة شاشة للخطأ إذا ظهرت رسالة داخل التطبيق'),
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

class _FaqCard extends StatelessWidget {
  const _FaqCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEFE3E6)),
      ),
      child: const Column(
        children: [
          _FaqTile(
            question: 'كيف أعرف حالة طلبي؟',
            answer:
                'من صفحة طلباتي يمكنك فتح الطلب ومتابعة حالته وتفاصيل الدفع والتوصيل.',
          ),
          _FaqDivider(),
          _FaqTile(
            question: 'ماذا أفعل إذا لم يتم تأكيد الدفع؟',
            answer:
                'تأكد من اكتمال العملية، ثم جهز رقم الطلب وصورة الإيصال أو رسالة البنك قبل التواصل مع الدعم.',
          ),
          _FaqDivider(),
          _FaqTile(
            question: 'هل يمكن تعديل العنوان بعد إنشاء الطلب؟',
            answer:
                'إذا لم يبدأ تجهيز الطلب بعد، تواصل مع الدعم مبكراً مع رقم الطلب والعنوان الجديد.',
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textHint,
        title: Text(
          question,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              answer,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqDivider extends StatelessWidget {
  const _FaqDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: Color(0xFFEFE3E6));
  }
}

class _CopySupportMessageCard extends StatelessWidget {
  const _CopySupportMessageCard();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نموذج رسالة جاهز',
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'انسخ النموذج وأرسله لقناة الدعم التي تعتمدها الإدارة.',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _copySupportMessage(context),
              icon: const Icon(AppIcons.copy_rounded, size: 19),
              label: Text(
                'نسخ نموذج الرسالة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copySupportMessage(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final name = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'غير محدد';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : 'غير محدد';
    final phone = user?.phone?.trim().isNotEmpty == true
        ? user!.phone!.trim()
        : 'غير محدد';

    final message =
        '''
مرحباً فريق ${AppConstants.appName}

أحتاج مساعدة بخصوص:
رقم الطلب:
وصف المشكلة:

بياناتي:
الاسم: $name
البريد: $email
الهاتف: $phone
''';

    Clipboard.setData(ClipboardData(text: message.trim()));
    AppNotifications.showSuccess(context, 'تم نسخ نموذج الرسالة');
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
