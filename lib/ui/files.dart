import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import 'common.dart';

/// Выгрузка файла с API: в вебе — ссылкой (браузер отправит cookie сессии),
/// на телефоне — скачать с токеном и открыть меню «Поделиться».
Future<void> exportFile(BuildContext context, String path, String filename, String mime) async {
  final s = AppScope.read(context);
  await guarded(context, () async {
    if (kIsWeb) {
      await launchUrl(s.api.url(path), webOnlyWindowName: '_blank');
      return;
    }
    final bytes = await s.api.bytes(path);
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: filename, mimeType: mime)]));
  });
}

Future<void> openLink(BuildContext context, String url) =>
    guarded(context, () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
