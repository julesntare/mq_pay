import 'package:flutter/material.dart';
import 'package:flutter_direct_caller_plugin/flutter_direct_caller_plugin.dart';

void launchUSSD(String ussdCode, BuildContext context) async {
  final formattedCode = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
  final ussdUrl = '$formattedCode';
  await FlutterDirectCallerPlugin.callNumber(ussdUrl);
}
