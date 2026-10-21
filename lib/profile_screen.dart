import 'package:flutter/material.dart';

import 'profile_photo.dart';
import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

/// Edit profile: photo, name, the locked username and the email.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({
    super.key,
    required this.social,
    this.safetyBannerBuilder,
  });

  final SocialController social;
  final WidgetBuilder? safetyBannerBuilder;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListenableBuilder(
      listenable: social,
      builder: (context, _) => Column(
        children: [
          if (safetyBannerBuilder != null) safetyBannerBuilder!(context),
          Expanded(
            child: HeaderPage(
              headerHeight: 270,
              overlap: -22,
              bottomPadding: 40,
              header: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          behavior: HitTestBehavior.opaque,
                          child: Semantics(
                            button: true,
                            label: 'Back',
                            child: SizedBox(
                              height: 44,
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Edit profile',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProfilePhotoEditor(social: social),
                ],
              ),
              children: [
                _field(context, 'NAME', social.currentUser.name),
                _field(
                  context,
                  'USERNAME',
                  '@${social.currentUser.username}',
                  locked: true,
                  note: 'Usernames are unique and cannot be changed.',
                ),
                _field(context, 'EMAIL', 'Google account not connected'),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    BuildContext context,
    String label,
    String value, {
    bool locked = false,
    String? note,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: locked ? AppColors.tint : AppColors.surface,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    color: locked ? AppColors.textMuted : AppColors.text,
                  ),
                ),
              ),
              if (locked)
                Icon(Icons.lock_outline, size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(note, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    ),
  );
}
