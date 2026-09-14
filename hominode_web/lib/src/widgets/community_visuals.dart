import 'package:flutter/material.dart';

import '../theme/web_design_system.dart';
import 'dashboard_components.dart';

/// Decorative community imagery, never presented as a photo of a user's unit.
class CommunityImage extends StatelessWidget {
  const CommunityImage({super.key, this.height = 220, this.child});
  final double height;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: height, minWidth: double.infinity),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/community_morning.png',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF53634C)),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xB3292B22), Color(0x00292B22)],
                ),
              ),
            ),
          ),
          if (child != null)
            Padding(padding: const EdgeInsets.all(26), child: child)
          else
            SizedBox(height: height),
        ],
      ),
    ),
  );
}

class CommunityWelcome extends StatelessWidget {
  const CommunityWelcome({
    super.key,
    required this.title,
    required this.subtitle,
    required this.palette,
    this.dashboard = false,
  });
  final String title;
  final String subtitle;
  final RolePalette palette;
  final bool dashboard;
  @override
  Widget build(BuildContext context) {
    final resident = palette.isResident;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (resident && dashboard)
          const Text(
            'YOUR COMMUNITY, CONNECTED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
        if (resident && dashboard) const SizedBox(height: 10),
        Text(
          dashboard && !resident ? 'Welcome back, Admin!' : title,
          style: TextStyle(
            color: resident ? Colors.white : WebDesign.text,
            fontSize: resident ? 32 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -.7,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          dashboard && !resident
              ? "Here’s what’s happening in your community today."
              : subtitle,
          style: TextStyle(
            color: resident ? Colors.white : WebDesign.muted,
            fontSize: 14,
          ),
        ),
        if (dashboard && !resident)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              title,
              style: const TextStyle(color: WebDesign.muted, fontSize: 11),
            ),
          ),
      ],
    );
    if (resident) {
      return CommunityImage(height: dashboard ? 214 : 166, child: text);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 20),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            Expanded(child: text),
            if (box.maxWidth >= 850) ...[
              const SizedBox(width: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: WebDesign.cardFor(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: palette.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${compactDate(DateTime.now())}, ${DateTime.now().year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const Text(
                'SMART PLACE.\nBETTER LIVES.',
                style: TextStyle(
                  color: WebDesign.text,
                  fontSize: 10,
                  height: 1.8,
                  letterSpacing: 2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CommunityPromo extends StatelessWidget {
  const CommunityPromo({super.key, this.resident = true});
  final bool resident;
  @override
  Widget build(BuildContext context) => CommunityImage(
    height: resident ? 232 : 174,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          resident
              ? 'Better community.\nBrighter tomorrow.'
              : 'Better community.\nHappier living.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'H O M I N O D E',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}

class CollectionSnapshot extends StatelessWidget {
  const CollectionSnapshot({
    super.key,
    required this.collected,
    required this.pending,
    required this.overdue,
  });
  final double collected;
  final double pending;
  final double overdue;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 440;
      final amounts = [collected, pending, overdue];
      const labels = ['Collected', 'Pending', 'Overdue'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moneyValue(collected + pending + overdue),
            style: const TextStyle(
              color: WebDesign.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: compact ? 6 : 16),
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(minHeight: compact ? 112 : 142),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: i == 1
                          ? RolePalette.admin.primary
                          : RolePalette.admin.soft,
                      borderRadius: BorderRadius.circular(compact ? 16 : 70),
                      border: Border.all(
                        color: i == 1
                            ? const Color(0xFF9ADCF8)
                            : const Color(0xFFD9E9FF),
                        width: i == 1 ? 4 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            moneyValue(amounts[i]),
                            style: TextStyle(
                              color: i == 1 ? Colors.white : WebDesign.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          labels[i],
                          style: TextStyle(
                            color: i == 1 ? Colors.white : WebDesign.text,
                            fontSize: compact ? 11 : 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    },
  );
}
