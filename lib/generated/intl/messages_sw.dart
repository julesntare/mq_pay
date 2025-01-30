// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a sw locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'sw';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "amount": MessageLookupByLibrary.simpleMessage("Kiasi"),
    "enterAmount": MessageLookupByLibrary.simpleMessage("Weka kiasi"),
    "generate": MessageLookupByLibrary.simpleMessage("Tengeneza"),
    "invalidAmount": MessageLookupByLibrary.simpleMessage(
      "Tafadhali weka kiasi halali.",
    ),
    "launchError": MessageLookupByLibrary.simpleMessage(
      "Haiwezekani kuzindua msimbo wa USSD",
    ),
    "loadFromContacts": MessageLookupByLibrary.simpleMessage(
      "Pakia kutoka kwa Mawasiliano",
    ),
    "mobileNumber": MessageLookupByLibrary.simpleMessage("Nambari ya Simu"),
    "momoCode": MessageLookupByLibrary.simpleMessage("Msimbo wa Momo"),
    "proceed": MessageLookupByLibrary.simpleMessage("Endelea"),
    "reset": MessageLookupByLibrary.simpleMessage("Weka upya"),
    "save": MessageLookupByLibrary.simpleMessage("Hifadhi"),
    "scanNow": MessageLookupByLibrary.simpleMessage("Scan Sasa"),
    "selectLanguage": MessageLookupByLibrary.simpleMessage("Chagua Lugha"),
    "settings": MessageLookupByLibrary.simpleMessage("Mipangilio"),
    "shortDesc": MessageLookupByLibrary.simpleMessage(
      "Fanya malipo yako kuwa laini na haraka!",
    ),
    "viaContact": MessageLookupByLibrary.simpleMessage("kupitia Mawasiliano"),
    "viaScan": MessageLookupByLibrary.simpleMessage("kupitia Scan"),
    "welcomeHere": MessageLookupByLibrary.simpleMessage("Karibu hapa"),
  };
}
