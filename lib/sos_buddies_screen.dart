import 'package:flutter/material.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';
import 'ui/motion.dart';

/// Everyone chosen to receive your SOS, with their approval state.
class SosBuddiesScreen extends StatelessWidget {
  const SosBuddiesScreen({super.key, required this.social, this.onAdd});

  final SocialController social;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListenableBuilder(
      listenable: social,
      builder: (context, _) {
        final chosen = social.profiles
            .where((p) => social.isFavorite(p.id))
            .toList();
        final approved = chosen
            .where((p) => social.isApprovedFavorite(p.id))
            .length;
        final pending = chosen.length - approved;
        const max = SocialController.maxSosBuddies;
        return HeaderPage(
          headerHeight: 220,
          overlap: 24,
          bottomPadding: 40,
          header: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeaderBack(),
              HeaderTitle(
                'SOS buddies',
                subtitle: 'Only these people receive your SOS.',
                size: 30,
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A2E1426),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$approved of $max approved',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (pending > 0)
                        Text(
                          '$pending pending',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.accent,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < max; i++) ...[
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: i < approved
                                  ? AppColors.primary
                                  : i < approved + pending
                                  ? const Color(0xFFF3C98B)
                                  : AppColors.border,
                            ),
                          ),
                        ),
                        if (i < max - 1) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final p in chosen)
              RowCard(
                leading: AvatarDot(name: p.name),
                title: '@${p.username}',
                detail: social.isApprovedFavorite(p.id)
                    ? null
                    : social.hasPendingSosRequest(p.id)
                    ? 'Waiting for them to accept'
                    : 'Approval needed',
                trailing: PillButton(
                  label: social.isApprovedFavorite(p.id)
                      ? 'Approved'
                      : 'Pending',
                  tone: social.isApprovedFavorite(p.id)
                      ? (
                          AppColors.light
                              ? const Color(0xFFE4F2E9)
                              : AppColors.tint,
                          AppColors.light
                              ? const Color(0xFF1F6B45)
                              : AppColors.success,
                        )
                      : (
                          AppColors.light
                              ? const Color(0xFFFFEDE5)
                              : AppColors.tint,
                          AppColors.light
                              ? const Color(0xFF8C3A1E)
                              : AppColors.text,
                        ),
                  onTap: () {
                    try {
                      social.unfavorite(p.id);
                    } on StateError catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(e.message)));
                    }
                  },
                ),
              ),
            if (chosen.isEmpty)
              RowCard(
                leading: const IconChip(Icons.star_outline_rounded),
                title: 'Nobody chosen yet',
                detail: 'Star a buddy from their chat menu.',
              ),
            if (chosen.length < max)
              Pressable(
                borderRadius: BorderRadius.circular(18),
                onTap: onAdd,
                semanticLabel: 'Add from your buddies',
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: AppColors.tint,
                    border: Border.all(
                      color: AppColors.light
                          ? const Color(0xFFD9A5B5)
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '+ Add from your buddies',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.onHeader,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Text(
              'Tap a status to remove someone. It takes effect immediately.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    ),
  );
}
