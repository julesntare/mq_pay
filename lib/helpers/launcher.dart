import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

void launchUSSD(String ussdCode, BuildContext context) async {
  final formattedCode = ussdCode.replaceAll('#', Uri.encodeComponent('#'));
  final ussdUrl = '$formattedCode';
  await FlutterPhoneDirectCaller.callNumber(ussdUrl);
}
