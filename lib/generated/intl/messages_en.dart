// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
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
  String get localeName => 'en';

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "amount": MessageLookupByLibrary.simpleMessage("Amount"),
    "enterAmount": MessageLookupByLibrary.simpleMessage("Enter amount"),
    "generate": MessageLookupByLibrary.simpleMessage("Generate"),
    "invalidAmount": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid amount.",
    ),
    "invalidUssdCode": MessageLookupByLibrary.simpleMessage(
      "Invalid USSD code",
    ),
    "launchError": MessageLookupByLibrary.simpleMessage(
      "Unable to launch USSD code",
    ),
    "loadFromContacts": MessageLookupByLibrary.simpleMessage(
      "Load from Contacts",
    ),
    "mobileNumber": MessageLookupByLibrary.simpleMessage("Mobile Number"),
    "momoCode": MessageLookupByLibrary.simpleMessage("Momo Code"),
    "proceed": MessageLookupByLibrary.simpleMessage("Proceed"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "scanNow": MessageLookupByLibrary.simpleMessage("Scan Now"),
    "selectLanguage": MessageLookupByLibrary.simpleMessage("Select Language"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "shortDesc": MessageLookupByLibrary.simpleMessage(
      "Make your payments smooth & fast!",
    ),
    "viaContact": MessageLookupByLibrary.simpleMessage("via Contacts"),
    "viaScan": MessageLookupByLibrary.simpleMessage("via Scan"),
    "welcomeHere": MessageLookupByLibrary.simpleMessage("Welcome here"),
  };
}
