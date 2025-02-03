import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../generated/l10n.dart';

void launchUSSD(String ussdCode, BuildContext context) async {
  final formattedCode = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
  final ussdUrl = 'tel:$formattedCode';
  if (await canLaunch(ussdUrl)) {
    await launch(ussdUrl);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${S.of(context).launchError}: $ussdCode')),
    );
  }
}
