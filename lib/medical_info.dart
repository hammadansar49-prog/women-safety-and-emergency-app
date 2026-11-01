import 'package:flutter/material.dart';

import 'social_controller.dart';
import 'theme/tokens.dart';
import 'ui/design.dart';

const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// Blood group, allergies, medicines and conditions. Sent with an SOS only,
/// and only to approved buddies, so they can tell paramedics.
class MedicalInfoScreen extends StatefulWidget {
  const MedicalInfoScreen({super.key, required this.social});
  final SocialController social;

  @override
  State<MedicalInfoScreen> createState() => _MedicalInfoScreenState();
}

class _MedicalInfoScreenState extends State<MedicalInfoScreen> {
  late String? _blood = widget.social.bloodGroup;
  late final _notes = TextEditingController(text: widget.social.medicalNotes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    widget.social.setMedicalInfo(_blood, _notes.text);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: HeaderPage(
        headerHeight: 200,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeaderBack(onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 14),
            const HeaderTitle(
              'Medical info',
              subtitle: 'Shared with your buddies only during an SOS.',
              size: 28,
            ),
          ],
        ),
        children: [
          const SectionLabel('Blood group'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in bloodGroups)
                PillButton(
                  label: g,
                  filled: _blood == g,
                  tone: _blood == g ? null : (AppColors.tint, AppColors.textMuted),
                  onTap: () => setState(() => _blood = _blood == g ? null : g),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('Allergies, medicines, conditions'),
          TextField(
            controller: _notes,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'e.g. Penicillin allergy, asthma inhaler, diabetic',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Leave empty to share nothing.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          BerryButton(label: 'Save', onTap: _save),
        ],
      ),
    );
  }
}

/// What a buddy sees on an incoming SOS.
class MedicalInfoCard extends StatelessWidget {
  const MedicalInfoCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconChip(Icons.medical_information_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Medical info',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}
