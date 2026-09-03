import 'package:app_aila/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

enum LegalPolicyTab { privacy, terms }

class LegalPoliciesScreen extends StatefulWidget {
  const LegalPoliciesScreen({
    super.key,
    this.initialTab = LegalPolicyTab.privacy,
  });

  final LegalPolicyTab initialTab;

  @override
  State<LegalPoliciesScreen> createState() => _LegalPoliciesScreenState();
}

class _LegalPoliciesScreenState extends State<LegalPoliciesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == LegalPolicyTab.privacy ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            Container(
              margin: const EdgeInsets.fromLTRB(24, 10, 24, 12),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.025),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                labelColor: AppColors.surface,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'سياسة الخصوصية'),
                  Tab(text: 'الشروط والأحكام'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: const [
                  _PolicyDocumentView(document: _privacyDocument),
                  _PolicyDocumentView(document: _termsDocument),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Row(
        children: [
          _CircleActionButton(
            icon: AppIcons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            'السياسة والشروط',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w600,
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

class _PolicyDocumentView extends StatelessWidget {
  final _PolicyDocument document;

  const _PolicyDocumentView({required this.document});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      children: [
        _PolicyHeroCard(document: document),
        const SizedBox(height: 22),
        ...document.sections.expand(
          (section) => [
            _SectionTitle(title: section.title),
            const SizedBox(height: 12),
            _PolicyCard(section: section),
            const SizedBox(height: 22),
          ],
        ),
        const _PolicyNoticeCard(),
      ],
    );
  }
}

class _PolicyHeroCard extends StatelessWidget {
  final _PolicyDocument document;

  const _PolicyHeroCard({required this.document});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.035),
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              document.icon,
              color: AppColors.primary,
              size: 28,
              textDirection: TextDirection.ltr,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            document.title,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            document.summary,
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
  final _PolicySection section;

  const _PolicyCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < section.points.length; i++) ...[
            _PolicyPoint(text: section.points[i]),
            if (i != section.points.length - 1) const _PolicyDivider(),
          ],
        ],
      ),
    );
  }
}

class _PolicyPoint extends StatelessWidget {
  final String text;

  const _PolicyPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 3),
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
            child: SelectableText(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyNoticeCard extends StatelessWidget {
  const _PolicyNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
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
            color: AppColors.surface,
            size: 24,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'للاستفسار عن أي بند، يرجى التواصل مع دعم ${AppConstants.appName} عبر صفحة الدعم داخل التطبيق.',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.surface,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
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
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PolicyDivider extends StatelessWidget {
  const _PolicyDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.divider);
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
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.035),
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

class _PolicyDocument {
  final String title;
  final String summary;
  final IconData icon;
  final List<_PolicySection> sections;

  const _PolicyDocument({
    required this.title,
    required this.summary,
    required this.icon,
    required this.sections,
  });
}

class _PolicySection {
  final String title;
  final List<String> points;

  const _PolicySection({required this.title, required this.points});
}

const _privacyDocument = _PolicyDocument(
  title: 'سياسة الخصوصية',
  icon: AppIcons.privacy_tip_rounded,
  summary:
      'توضح هذه السياسة كيف يجمع ${AppConstants.appName} بياناتك ويستخدمها ويحميها، والخيارات المتاحة لك لإدارتها أو حذفها. آخر تحديث: 11 يوليو 2026.',
  sections: [
    _PolicySection(
      title: 'البيانات التي نجمعها',
      points: [
        'بيانات الحساب مثل الاسم، رقم الهاتف، البريد الإلكتروني، وبيانات تسجيل الدخول اللازمة لإنشاء الحساب وحمايته.',
        'بيانات العناوين والتوصيل مثل المدينة، تفاصيل العنوان، رقم الهاتف، والموقع الذي تختاره عند استخدام الخريطة لإضافة عنوان.',
        'بيانات الطلبات مثل المنتجات، الكميات، إجمالي الطلب، رسوم التوصيل، حالة الطلب، وطريقة الدفع المختارة.',
        'بيانات المحفظة وعمليات الدفع مثل الرصيد، طلبات الشحن، الإيصالات المرفقة، وحالة المعاملة.',
        'بيانات الدعم التي ترسلها لنا، مثل وصف المشكلة ورقم الطلب والمرفقات اللازمة لمراجعة طلبك.',
        'بيانات تقنية ضرورية مثل نوع الجهاز، إصدار التطبيق، رموز الإشعارات، وسجلات محدودة تساعدنا على تشغيل الخدمة ومعالجة الأعطال.',
      ],
    ),
    _PolicySection(
      title: 'الأذونات واختيارات الجهاز',
      points: [
        'الوصول إلى الموقع اختياري، ولا نطلبه إلا عند استخدام ميزة تحديد عنوان التوصيل على الخريطة.',
        'يمكنك رفض إذن الموقع أو سحبه لاحقاً من إعدادات الجهاز، وقد تتوقف عندها الميزات التي تعتمد على تحديد الموقع تلقائياً.',
        'الإشعارات اختيارية، ويمكنك تعطيلها من إعدادات الجهاز دون منعك من استخدام بقية وظائف التطبيق.',
        'لا نصل إلى ملف أو إيصال إلا عندما تختاره بنفسك لرفعه ضمن عملية دفع أو طلب دعم.',
      ],
    ),
    _PolicySection(
      title: 'كيف نستخدم البيانات',
      points: [
        'إنشاء حسابك وتسجيل الدخول وحماية الوصول إلى بياناتك.',
        'تنفيذ الطلبات، حساب رسوم التوصيل، حفظ العناوين، وإظهار حالة الطلب داخل التطبيق.',
        'معالجة عمليات الدفع أو شحن المحفظة حسب الطريقة التي تختارها.',
        'إرسال إشعارات مهمة عن الطلبات، الدفع، المحفظة، أو التحديثات المرتبطة بالخدمة.',
        'تحسين تجربة الاستخدام، حل المشاكل التقنية، والرد على طلبات الدعم.',
      ],
    ),
    _PolicySection(
      title: 'مشاركة البيانات ومزودو الخدمة',
      points: [
        'نشارك الحد الضروري من بيانات الطلب والعنوان ورقم التواصل مع جهات التوصيل لإتمام التسليم.',
        'قد تتم معالجة بيانات الدفع اللازمة بواسطة مزودي خدمات الدفع لإتمام العملية والتحقق منها، ولا نبيع بياناتك المالية.',
        'نستخدم خدمات تقنية مساعدة مثل Firebase للإشعارات وGoogle Maps للخرائط والموقع عند اختيارك لهذه الميزات، وتخضع معالجة هذه الجهات لسياساتها وشروطها.',
        'قد نشارك بيانات محدودة مع مقدمي الاستضافة أو الدعم الفني بقدر ما يلزم لتشغيل الخدمة وحمايتها، مع إلزامهم بحماية البيانات وعدم استخدامها لأغراضهم الخاصة.',
        'لا نبيع بياناتك الشخصية لأي طرف خارجي.',
        'قد نكشف عن بيانات محددة إذا كان ذلك مطلوباً قانونياً، أو لحماية حقوق المتجر والمستخدمين، أو للتحقيق في احتيال أو إساءة استخدام.',
      ],
    ),
    _PolicySection(
      title: 'الاحتفاظ بالبيانات وحذفها',
      points: [
        'نحتفظ ببيانات الحساب ما دام الحساب نشطاً، وبالبيانات الأخرى فقط للمدة اللازمة لتقديم الخدمة وتنفيذ الطلبات وتسوية المدفوعات ومعالجة الشكاوى.',
        'يمكنك بدء حذف حسابك من الملف الشخصي ثم اختيار «حذف الحساب نهائيًا». يؤدي ذلك إلى حذف الحساب والبيانات الشخصية المرتبطة به التي لا يلزمنا الاحتفاظ بها.',
        'قد نحتفظ بسجلات محدودة للطلبات أو المدفوعات أو النزاعات عندما يكون ذلك ضرورياً للالتزامات القانونية أو المحاسبية أو لمنع الاحتيال. تُقيّد هذه السجلات ولا تُستخدم للتسويق.',
        'قد تبقى نسخ مؤقتة ضمن النسخ الاحتياطية الآمنة إلى أن تُحذف تلقائياً وفق دورة النسخ الاحتياطي المعتادة، ولا نعيد استخدامها بعد طلب حذف الحساب.',
        'بعد اكتمال الحذف لا يمكن استعادة الحساب أو بياناته المحذوفة. ويمكنك التواصل مع الدعم إذا تعذر عليك تنفيذ الحذف من داخل التطبيق.',
      ],
    ),
    _PolicySection(
      title: 'حماية البيانات',
      points: [
        'نستخدم وسائل حماية تقنية وتنظيمية مناسبة، واتصالات مشفرة أثناء النقل، لتقليل مخاطر الوصول غير المصرح به إلى بياناتك.',
        'نقيّد الوصول إلى البيانات على الأشخاص ومزودي الخدمة الذين يحتاجون إليها لتشغيل الخدمة أو دعم المستخدم.',
        'ينبغي عليك الحفاظ على سرية كلمة المرور وعدم مشاركتها مع أي شخص.',
        'رغم اتخاذ إجراءات الحماية، لا توجد وسيلة نقل أو تخزين إلكترونية مضمونة بنسبة 100%.',
      ],
    ),
    _PolicySection(
      title: 'حقوقك واختياراتك',
      points: [
        'يمكنك تعديل بيانات حسابك من صفحة الملف الشخصي متى كان ذلك متاحاً.',
        'يمكنك إدارة عناوينك المحفوظة من صفحة العناوين.',
        'يمكنك حذف حسابك نهائياً من داخل التطبيق، أو طلب المساعدة للوصول إلى بياناتك أو تصحيحها أو حذفها عبر صفحة الدعم.',
        'يمكنك سحب أذونات الموقع والإشعارات من إعدادات الجهاز في أي وقت، مع العلم أن ذلك قد يعطل الميزات المرتبطة بها.',
        'قد نطلب معلومات مناسبة للتحقق من هويتك قبل تنفيذ طلب يتعلق ببيانات الحساب، وذلك لحماية بياناتك من الطلبات غير المصرح بها.',
      ],
    ),
    _PolicySection(
      title: 'التواصل بخصوص الخصوصية',
      points: [
        'لأي سؤال أو طلب يتعلق بخصوصيتك أو بياناتك، استخدم صفحة دعم LUNORA داخل التطبيق.',
        'يرجى توضيح نوع الطلب والبيانات اللازمة للتعرف على حسابك، وتجنب إرسال كلمة المرور أو معلومات دفع حساسة عبر البريد.',
      ],
    ),
    _PolicySection(
      title: 'تحديث هذه السياسة',
      points: [
        'قد نقوم بتحديث سياسة الخصوصية عند إضافة مزايا جديدة أو تغيير طريقة عمل الخدمة.',
        'سنوضح تاريخ آخر تحديث، وسنعرض إشعاراً مناسباً أو نطلب موافقة جديدة إذا كان التغيير جوهرياً أو تطلب القانون ذلك.',
      ],
    ),
  ],
);

const _termsDocument = _PolicyDocument(
  title: 'الشروط والأحكام',
  icon: AppIcons.gavel_rounded,
  summary:
      'باستخدامك ${AppConstants.appName} فإنك توافق على هذه الشروط التي تنظّم إنشاء الحساب، الطلبات، الدفع، التوصيل، واستخدام خدمات التطبيق.',
  sections: [
    _PolicySection(
      title: 'استخدام التطبيق والحساب',
      points: [
        'يجب إدخال بيانات صحيحة عند إنشاء الحساب أو إضافة عنوان أو تنفيذ طلب.',
        'أنت مسؤول عن الحفاظ على سرية بيانات الدخول إلى حسابك.',
        'يحق للتطبيق تقييد أو إيقاف أي حساب عند وجود استخدام مخالف أو بيانات غير صحيحة أو نشاط يضر بالخدمة.',
      ],
    ),
    _PolicySection(
      title: 'المنتجات والأسعار',
      points: [
        'نعمل على عرض معلومات المنتجات والأسعار بأكبر قدر ممكن من الدقة.',
        'قد تتغير الأسعار أو التوفر دون إشعار مسبق قبل تأكيد الطلب.',
        'وجود المنتج في السلة لا يعني حجزه أو ضمان توفره حتى يتم تأكيد الطلب.',
      ],
    ),
    _PolicySection(
      title: 'الطلبات والدفع',
      points: [
        'يتم إنشاء الطلب بعد مراجعة السلة، اختيار عنوان التوصيل، وتحديد طريقة الدفع.',
        'قد يحتاج الطلب إلى تأكيد الدفع أو مراجعة الإدارة قبل بدء التجهيز.',
        'إذا فشلت عملية الدفع أو لم تصل لنا نتيجة مؤكدة، قد يبقى الطلب قيد الانتظار حتى تتم المراجعة.',
        'يتحمل المستخدم مسؤولية التأكد من صحة العنوان ورقم الهاتف قبل تأكيد الطلب.',
      ],
    ),
    _PolicySection(
      title: 'الشحن والتوصيل',
      points: [
        'تخضع عمليات التوصيل للمدن والمناطق المدعومة داخل التطبيق.',
        'رسوم التوصيل تظهر في ملخص الطلب قبل تأكيد الشراء، وقد تختلف حسب المدينة أو الموقع.',
        'قد يتم التواصل معك لتأكيد العنوان أو ترتيب التسليم.',
        'يمكنك مراجعة صفحة سياسة الشحن والتوصيل من الملف الشخصي لمزيد من التفاصيل.',
      ],
    ),
    _PolicySection(
      title: 'الاسترجاع والاستبدال',
      points: [
        'تتم مراجعة طلبات الاسترجاع والاستبدال حسب حالة المنتج وسبب الطلب وبيانات الشراء.',
        'قد يطلب فريق الدعم رقم الطلب أو صوراً توضّح المشكلة قبل اعتماد أي إجراء.',
        'يمكنك مراجعة صفحة سياسة الاسترجاع والاستبدال من الملف الشخصي لمزيد من التفاصيل.',
      ],
    ),
    _PolicySection(
      title: 'المحفظة والدعم',
      points: [
        'عمليات شحن المحفظة أو الدفع تخضع للتأكيد من النظام أو مزود الدفع أو مراجعة الإدارة حسب الطريقة المختارة.',
        'يجب إرفاق إيصال واضح عند استخدام طرق دفع تتطلب إثبات تحويل.',
        'الدعم يساعدك في متابعة الطلبات والمشاكل التقنية، لكنه قد يحتاج بيانات الطلب أو الحساب للتحقق.',
      ],
    ),
    _PolicySection(
      title: 'حدود المسؤولية',
      points: [
        'نسعى لتوفير خدمة مستقرة، لكن قد تحدث انقطاعات أو أخطاء تقنية خارجة عن السيطرة.',
        'لا نتحمل مسؤولية التأخير الناتج عن بيانات عنوان غير صحيحة أو عدم إمكانية التواصل مع المستخدم.',
        'يمنع استخدام التطبيق لأي نشاط غير قانوني أو محاولة تعطيل الخدمة أو إساءة استخدامها.',
      ],
    ),
    _PolicySection(
      title: 'تحديث الشروط',
      points: [
        'قد يتم تعديل هذه الشروط عند تحديث التطبيق أو تغيير الخدمات المتاحة.',
        'استمرار استخدامك للتطبيق بعد نشر التحديث يعني موافقتك على الشروط المحدثة.',
      ],
    ),
  ],
);
