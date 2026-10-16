import 'package:hive_ce_flutter/hive_flutter.dart';
import 'social_controller.dart';

Future<SocialController> loadLocalAccount() async {
  await Hive.initFlutter();
  final box = await Hive.openBox<String>('safeher_account_v1');
  final value = box.get('account');
  final social = value == null
      ? SocialController(newAccount: true)
      : SocialController.fromSnapshot(value);
  social.persist = (data) async {
    await box.put('account', data);
    await box.flush();
  };
  return social;
}
