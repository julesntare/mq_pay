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

  static String m0(amount) => "Amount: ${amount} RWF";

  static String m1(number) => "Contact loaded: ${number}";

  static String m2(amount) => "Fee: ${amount}";

  static String m3(code) => "Momo Code: ${code}";

  static String m4(filterName) => "No ${filterName} transactions";

  static String m5(query) => "No results for \"${query}\"";

  static String m6(number) => "Phone: ${number}";

  static String m7(recipient) => "Recipient: ${recipient}";

  static String m8(result) => "Scanned: ${result}";

  static String m9(step) => "Step ${step} of 2";

  static String m10(type) => "Tariff Type: ${type}";

  static String m11(name) => "To: ${name}";

  static String m12(amount) => "Total: ${amount}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "aboutToRedial": MessageLookupByLibrary.simpleMessage(
      "You are about to redial this transaction:",
    ),
    "activeStatus": MessageLookupByLibrary.simpleMessage("Active"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Add Payment Method",
    ),
    "airtelMoney": MessageLookupByLibrary.simpleMessage("Airtel Money"),
    "allFilter": MessageLookupByLibrary.simpleMessage("All"),
    "allRecordsCleared": MessageLookupByLibrary.simpleMessage(
      "All records cleared successfully",
    ),
    "amount": MessageLookupByLibrary.simpleMessage("Amount"),
    "amountRwf": MessageLookupByLibrary.simpleMessage("Amount (RWF)"),
    "amountRwfLabel": m0,
    "appInformation": MessageLookupByLibrary.simpleMessage("App Information"),
    "appVersion": MessageLookupByLibrary.simpleMessage("App Version"),
    "apply": MessageLookupByLibrary.simpleMessage("Apply"),
    "applyTransactionFee": MessageLookupByLibrary.simpleMessage(
      "Apply Transaction Fee",
    ),
    "autoBackup": MessageLookupByLibrary.simpleMessage("Auto-Backup"),
    "autoBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Automatically backup your data periodically",
    ),
    "availableBackups": MessageLookupByLibrary.simpleMessage(
      "Available Backups",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Back"),
    "backupDeletedSuccess": MessageLookupByLibrary.simpleMessage(
      "Backup deleted successfully",
    ),
    "backupExportedSuccess": MessageLookupByLibrary.simpleMessage(
      "Backup exported successfully!",
    ),
    "backupFrequency": MessageLookupByLibrary.simpleMessage("Backup Frequency"),
    "backupLocation": MessageLookupByLibrary.simpleMessage("Backup Location"),
    "backupRestore": MessageLookupByLibrary.simpleMessage("Backup & Restore"),
    "backupRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "Export your data to keep it safe or restore from a previous backup",
    ),
    "backupRestoredMsg": MessageLookupByLibrary.simpleMessage(
      "Your data has been restored successfully!",
    ),
    "backupRestoredTitle": MessageLookupByLibrary.simpleMessage(
      "Restore Complete",
    ),
    "backupUploadedTitle": MessageLookupByLibrary.simpleMessage(
      "Backup Uploaded",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "checkingStatus": MessageLookupByLibrary.simpleMessage(
      "Checking status...",
    ),
    "clearAction": MessageLookupByLibrary.simpleMessage("Clear"),
    "clearAll": MessageLookupByLibrary.simpleMessage("Clear All"),
    "clearAllConfirmMsg": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to clear all USSD records? This action cannot be undone.",
    ),
    "clearAllRecords": MessageLookupByLibrary.simpleMessage(
      "Clear All Records",
    ),
    "clearReasonFilter": MessageLookupByLibrary.simpleMessage(
      "Clear reason filter",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Close"),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmTransactionComplete": MessageLookupByLibrary.simpleMessage(
      "Confirm this transaction completed",
    ),
    "contact": MessageLookupByLibrary.simpleMessage("Contact"),
    "contactLoaded": m1,
    "contactNameOptional": MessageLookupByLibrary.simpleMessage(
      "Contact Name (Optional)",
    ),
    "contactPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Contact permission denied",
    ),
    "continueAction": MessageLookupByLibrary.simpleMessage("Continue"),
    "createQrCodeDesc": MessageLookupByLibrary.simpleMessage(
      "Create a QR code for someone to pay you",
    ),
    "daily": MessageLookupByLibrary.simpleMessage("Daily"),
    "darkTheme": MessageLookupByLibrary.simpleMessage("Dark Theme"),
    "darkThemeDesc": MessageLookupByLibrary.simpleMessage("Easy on the eyes"),
    "dateLabel": MessageLookupByLibrary.simpleMessage("Date"),
    "dateRange": MessageLookupByLibrary.simpleMessage("Range"),
    "defaultLocation": MessageLookupByLibrary.simpleMessage("Default Location"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteBackupMessage": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to delete this backup?",
    ),
    "deleteBackupTitle": MessageLookupByLibrary.simpleMessage("Delete Backup?"),
    "deleteFailedOrDuplicate": MessageLookupByLibrary.simpleMessage(
      "Delete failed or duplicate transaction",
    ),
    "deletePaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Delete Payment Method",
    ),
    "dial": MessageLookupByLibrary.simpleMessage("Dial"),
    "dialUssdCode": MessageLookupByLibrary.simpleMessage(
      "Dial this USSD code:",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Edit Payment Method",
    ),
    "editTransaction": MessageLookupByLibrary.simpleMessage("Edit Transaction"),
    "enableAutoBackup": MessageLookupByLibrary.simpleMessage(
      "Enable Auto-Backup",
    ),
    "endDate": MessageLookupByLibrary.simpleMessage("End date"),
    "enterAmount": MessageLookupByLibrary.simpleMessage("Enter amount"),
    "enterManually": MessageLookupByLibrary.simpleMessage("Enter manually"),
    "enterNameForContact": MessageLookupByLibrary.simpleMessage(
      "Enter name for this contact",
    ),
    "enterPaymentNumber": MessageLookupByLibrary.simpleMessage(
      "Enter Payment Number",
    ),
    "enterPhoneOrMomoDesc": MessageLookupByLibrary.simpleMessage(
      "Enter the phone number or momo code to receive payment",
    ),
    "enterPhoneOrMomoHint": MessageLookupByLibrary.simpleMessage(
      "Enter phone number or momo code",
    ),
    "enterValidMinAmount": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid amount (minimum 1 RWF)",
    ),
    "enterValidPhoneOrMomo": MessageLookupByLibrary.simpleMessage(
      "Enter valid phone number or momo code",
    ),
    "enterValidPhoneOrMomoMsg": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid phone number (078xxxxxxx) or momo code",
    ),
    "error": MessageLookupByLibrary.simpleMessage("Error"),
    "excelExportedSuccess": MessageLookupByLibrary.simpleMessage(
      "Excel file exported successfully!",
    ),
    "exportBackup": MessageLookupByLibrary.simpleMessage("Export Backup"),
    "exportToExcel": MessageLookupByLibrary.simpleMessage("Export to Excel"),
    "exportingBackup": MessageLookupByLibrary.simpleMessage(
      "Exporting backup...",
    ),
    "exportingToExcel": MessageLookupByLibrary.simpleMessage(
      "Exporting to Excel...",
    ),
    "feeLabel": m2,
    "feeTrackingEnabled": MessageLookupByLibrary.simpleMessage(
      "Fee tracking enabled (no fee calculated for this type)",
    ),
    "feeWillBeAdded": MessageLookupByLibrary.simpleMessage(
      "Fee will be added to total",
    ),
    "fees": MessageLookupByLibrary.simpleMessage("fees"),
    "feesExcludedFromTotals": MessageLookupByLibrary.simpleMessage(
      "Fees Excluded from All Totals",
    ),
    "feesIncludedInTotals": MessageLookupByLibrary.simpleMessage(
      "Fees Included in All Totals",
    ),
    "filtersLabel": MessageLookupByLibrary.simpleMessage("Filters"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "generate": MessageLookupByLibrary.simpleMessage("Generate"),
    "generatePaymentQr": MessageLookupByLibrary.simpleMessage(
      "Generate Payment QR",
    ),
    "generateQrCode": MessageLookupByLibrary.simpleMessage("Generate QR Code"),
    "generateQrHint": MessageLookupByLibrary.simpleMessage(
      "Enter the amount you want to receive, then generate a QR code to show the payer",
    ),
    "getPaid": MessageLookupByLibrary.simpleMessage("Get Paid"),
    "gotIt": MessageLookupByLibrary.simpleMessage("Got it"),
    "howMuchSend": MessageLookupByLibrary.simpleMessage(
      "How much do you want to send?",
    ),
    "importBackup": MessageLookupByLibrary.simpleMessage("Import Backup"),
    "importBackupTitle": MessageLookupByLibrary.simpleMessage("Import Backup"),
    "importBackupWarning": MessageLookupByLibrary.simpleMessage(
      "Importing a backup will replace all your current data including transactions, payment methods, and settings. This action cannot be undone.\n\nDo you want to continue?",
    ),
    "importingBackup": MessageLookupByLibrary.simpleMessage(
      "Importing backup...",
    ),
    "invalidAmount": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid amount.",
    ),
    "invalidContactPhone": MessageLookupByLibrary.simpleMessage(
      "The selected contact has an invalid phone number format. Please select a contact with a valid Rwanda phone number.",
    ),
    "invalidPhoneNumber": MessageLookupByLibrary.simpleMessage(
      "Invalid Phone Number",
    ),
    "invalidPhoneOrMomo": MessageLookupByLibrary.simpleMessage(
      "Invalid phone number or momo code",
    ),
    "invalidTransactionDeleted": MessageLookupByLibrary.simpleMessage(
      "Invalid transaction deleted successfully",
    ),
    "invalidUssdCode": MessageLookupByLibrary.simpleMessage(
      "Invalid USSD code",
    ),
    "languagePreferences": MessageLookupByLibrary.simpleMessage(
      "Language Preferences",
    ),
    "launchError": MessageLookupByLibrary.simpleMessage(
      "Unable to launch USSD code",
    ),
    "lightTheme": MessageLookupByLibrary.simpleMessage("Light Theme"),
    "lightThemeDesc": MessageLookupByLibrary.simpleMessage(
      "Bright and clean interface",
    ),
    "loadFromContacts": MessageLookupByLibrary.simpleMessage(
      "Load from Contacts",
    ),
    "loadingBackups": MessageLookupByLibrary.simpleMessage(
      "Loading backups...",
    ),
    "makeSamePaymentAgain": MessageLookupByLibrary.simpleMessage(
      "Make the same payment again",
    ),
    "markFailed": MessageLookupByLibrary.simpleMessage("Mark as Failed"),
    "markInvalid": MessageLookupByLibrary.simpleMessage("Mark as Invalid"),
    "markSuccessful": MessageLookupByLibrary.simpleMessage(
      "Mark as Successful",
    ),
    "misc": MessageLookupByLibrary.simpleMessage("Misc"),
    "moCode": MessageLookupByLibrary.simpleMessage("MoCode"),
    "mobileNumber": MessageLookupByLibrary.simpleMessage("Mobile Number"),
    "modifyTransactionDetails": MessageLookupByLibrary.simpleMessage(
      "Modify transaction details",
    ),
    "momoCode": MessageLookupByLibrary.simpleMessage("Momo Code"),
    "momoCodeHint": MessageLookupByLibrary.simpleMessage("Enter momo code"),
    "momoCodeLabel": m3,
    "momoFormatDetected": MessageLookupByLibrary.simpleMessage(
      "Momo code format detected",
    ),
    "momoPayment": MessageLookupByLibrary.simpleMessage("Momo Payment"),
    "monthly": MessageLookupByLibrary.simpleMessage("Monthly"),
    "mtnMomo": MessageLookupByLibrary.simpleMessage("MTN MoMo"),
    "next": MessageLookupByLibrary.simpleMessage("Next"),
    "noAutoBackupsFound": MessageLookupByLibrary.simpleMessage(
      "No auto-backups found",
    ),
    "noBackupsFound": MessageLookupByLibrary.simpleMessage("No backups found"),
    "noBackupsYet": MessageLookupByLibrary.simpleMessage("No backups yet"),
    "noFeeApplied": MessageLookupByLibrary.simpleMessage(
      "No fee will be applied",
    ),
    "noFeeTracked": MessageLookupByLibrary.simpleMessage(
      "No fee will be tracked",
    ),
    "noFilterTransactions": m4,
    "noPaymentMethods": MessageLookupByLibrary.simpleMessage(
      "No payment methods configured. Add your first payment method below.",
    ),
    "noReasonsFound": MessageLookupByLibrary.simpleMessage("No reasons found"),
    "noRecordsFound": MessageLookupByLibrary.simpleMessage("No records found"),
    "noResultsFor": m5,
    "notEnabled": MessageLookupByLibrary.simpleMessage("Not Enabled"),
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "openAccessibilitySettings": MessageLookupByLibrary.simpleMessage(
      "Open Accessibility Settings",
    ),
    "optionalSidePaymentsHint": MessageLookupByLibrary.simpleMessage(
      "Optional - leave blank for side payments",
    ),
    "optionalTransactionNote": MessageLookupByLibrary.simpleMessage(
      "Optional note about this transaction",
    ),
    "overallTotal": MessageLookupByLibrary.simpleMessage("Overall Total"),
    "payNow": MessageLookupByLibrary.simpleMessage("Pay Now"),
    "payerScanQuick": MessageLookupByLibrary.simpleMessage(
      "The payer can scan this code to quickly pay you the exact amount",
    ),
    "payerScanWithNumber": MessageLookupByLibrary.simpleMessage(
      "The payer can scan this code to pay you the exact amount at the specified number",
    ),
    "paymentDetails": MessageLookupByLibrary.simpleMessage("Payment Details"),
    "paymentMethods": MessageLookupByLibrary.simpleMessage("Payment Methods"),
    "paymentMethodsDesc": MessageLookupByLibrary.simpleMessage(
      "Manage your mobile numbers and payment options",
    ),
    "paymentRecordSaved": MessageLookupByLibrary.simpleMessage(
      "Payment record saved successfully!",
    ),
    "paymentRequestQR": MessageLookupByLibrary.simpleMessage(
      "Payment Request QR",
    ),
    "phoneFilter": MessageLookupByLibrary.simpleMessage("Phone"),
    "phoneFormatDetected": MessageLookupByLibrary.simpleMessage(
      "Phone number format detected",
    ),
    "phoneLabel": m6,
    "phoneNumberHint": MessageLookupByLibrary.simpleMessage("078xxxxxxx"),
    "phoneNumberLabel": MessageLookupByLibrary.simpleMessage("Phone Number"),
    "phoneOrMomo": MessageLookupByLibrary.simpleMessage(
      "Phone Number or Momo Code",
    ),
    "phoneOrMomoExample": MessageLookupByLibrary.simpleMessage(
      "Phone: 078xxxxxxx or Momo: 123456",
    ),
    "phoneOrMomoOptional": MessageLookupByLibrary.simpleMessage(
      "Phone Number or Momo Code (Optional)",
    ),
    "phonePayment": MessageLookupByLibrary.simpleMessage("Phone Payment"),
    "pleaseEnterValidAmount": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid amount first",
    ),
    "pleaseEnterValidMomo": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid momo code",
    ),
    "pleaseEnterValidPhone": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid phone number",
    ),
    "pleaseEnterValidValue": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid value",
    ),
    "pleaseRestartApp": MessageLookupByLibrary.simpleMessage(
      "Please restart the app to see all changes.",
    ),
    "positionQrCode": MessageLookupByLibrary.simpleMessage(
      "Position the QR code within the frame to scan",
    ),
    "privacy": MessageLookupByLibrary.simpleMessage("Privacy"),
    "probablyInvalidNumber": MessageLookupByLibrary.simpleMessage(
      "Probably invalid number",
    ),
    "probablyMomoCode": MessageLookupByLibrary.simpleMessage(
      "Probably a momo code",
    ),
    "proceed": MessageLookupByLibrary.simpleMessage("Proceed"),
    "providerLabel": MessageLookupByLibrary.simpleMessage("Provider"),
    "quickPayment": MessageLookupByLibrary.simpleMessage("Quick Payment"),
    "reasonHint": MessageLookupByLibrary.simpleMessage(
      "Why are you sending this money?",
    ),
    "reasonLabel": MessageLookupByLibrary.simpleMessage("Reason"),
    "reasonOptional": MessageLookupByLibrary.simpleMessage("Reason (optional)"),
    "recipientInfo": MessageLookupByLibrary.simpleMessage(
      "Recipient Information",
    ),
    "recipientLabel": m7,
    "recipientName": MessageLookupByLibrary.simpleMessage(
      "Recipient Name (Optional)",
    ),
    "recipientNameHint": MessageLookupByLibrary.simpleMessage(
      "Enter name for this recipient",
    ),
    "recordOnly": MessageLookupByLibrary.simpleMessage("Record Only"),
    "recordOnlyExplain": MessageLookupByLibrary.simpleMessage(
      "When enabled, transactions are saved as records without executing the payment. This is useful for tracking side payments or manually handled transactions.",
    ),
    "recordOnlyMode": MessageLookupByLibrary.simpleMessage("Record Only Mode"),
    "redial": MessageLookupByLibrary.simpleMessage("Redial"),
    "redialTransaction": MessageLookupByLibrary.simpleMessage(
      "Redial Transaction",
    ),
    "refresh": MessageLookupByLibrary.simpleMessage("Refresh"),
    "refreshStatus": MessageLookupByLibrary.simpleMessage("Refresh status"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "restore": MessageLookupByLibrary.simpleMessage("Restore"),
    "restoreBackupDesc": MessageLookupByLibrary.simpleMessage(
      "This will merge the backup data with your current data. Duplicates will be automatically skipped.\n\nDo you want to continue?",
    ),
    "restoreBackupTitle": MessageLookupByLibrary.simpleMessage(
      "Restore Backup?",
    ),
    "restoreFailedTitle": MessageLookupByLibrary.simpleMessage(
      "Restore Failed",
    ),
    "restoredSuccess": MessageLookupByLibrary.simpleMessage(
      "Restored successfully!",
    ),
    "restoringBackup": MessageLookupByLibrary.simpleMessage(
      "Restoring backup...",
    ),
    "restoringFromSupabase": MessageLookupByLibrary.simpleMessage(
      "Restoring from Supabase...",
    ),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveChanges": MessageLookupByLibrary.simpleMessage("Save Changes"),
    "savePaymentRecord": MessageLookupByLibrary.simpleMessage(
      "Save Payment Record",
    ),
    "saveRecord": MessageLookupByLibrary.simpleMessage("Save Record"),
    "scanNow": MessageLookupByLibrary.simpleMessage("Scan Now"),
    "scanQrCode": MessageLookupByLibrary.simpleMessage("Scan QR Code"),
    "scannedResult": m8,
    "searchHint": MessageLookupByLibrary.simpleMessage(
      "Search by name, number, amount, reason...",
    ),
    "searchReasons": MessageLookupByLibrary.simpleMessage("Search reasons..."),
    "seeFullUssdCode": MessageLookupByLibrary.simpleMessage(
      "See the full USSD code used",
    ),
    "selectLanguage": MessageLookupByLibrary.simpleMessage("Select Language"),
    "selectPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Select Payment Method",
    ),
    "sendMoney": MessageLookupByLibrary.simpleMessage("Send Money"),
    "setAsDefault": MessageLookupByLibrary.simpleMessage("Set as Default"),
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "settingsSubtitle": MessageLookupByLibrary.simpleMessage(
      "Configure your payment preferences",
    ),
    "shortDesc": MessageLookupByLibrary.simpleMessage(
      "Make your payments smooth & fast!",
    ),
    "showQrToReceive": MessageLookupByLibrary.simpleMessage(
      "Show this QR code to receive payment",
    ),
    "sidePayment": MessageLookupByLibrary.simpleMessage("Side Payment"),
    "sidePayments": MessageLookupByLibrary.simpleMessage("Side Payments"),
    "singleDate": MessageLookupByLibrary.simpleMessage("Single"),
    "startDate": MessageLookupByLibrary.simpleMessage("Start date"),
    "stepOf": m9,
    "stepsToEnable": MessageLookupByLibrary.simpleMessage(
      "Steps to enable:\n1. Find \"MQ Pay\" in the list\n2. Toggle the switch to ON\n3. Grant permission",
    ),
    "suggestions": MessageLookupByLibrary.simpleMessage("Suggestions"),
    "supabaseBackups": MessageLookupByLibrary.simpleMessage("Supabase Backups"),
    "supabaseCloudBackup": MessageLookupByLibrary.simpleMessage(
      "Supabase Cloud Backup",
    ),
    "supabaseNotConfigured": MessageLookupByLibrary.simpleMessage(
      "Supabase credentials not configured",
    ),
    "support": MessageLookupByLibrary.simpleMessage("Support"),
    "syncComplete": MessageLookupByLibrary.simpleMessage("Sync Complete"),
    "syncingDates": MessageLookupByLibrary.simpleMessage(
      "Syncing all dates...",
    ),
    "tapFilterViewAll": MessageLookupByLibrary.simpleMessage(
      "Tap the filter again to view all",
    ),
    "tapToEnable": MessageLookupByLibrary.simpleMessage(
      "Tap below to enable in Settings",
    ),
    "tariffTypeLabel": m10,
    "themePreferences": MessageLookupByLibrary.simpleMessage(
      "Theme Preferences",
    ),
    "toRecipient": m11,
    "today": MessageLookupByLibrary.simpleMessage("Today"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalFeesPaid": MessageLookupByLibrary.simpleMessage("Total Fees Paid"),
    "totalLabel": m12,
    "transactionActions": MessageLookupByLibrary.simpleMessage(
      "Transaction Actions",
    ),
    "transactionDidNotComplete": MessageLookupByLibrary.simpleMessage(
      "This transaction did not complete",
    ),
    "transactionMarkedFailed": MessageLookupByLibrary.simpleMessage(
      "Transaction marked as failed",
    ),
    "transactionMarkedSuccessful": MessageLookupByLibrary.simpleMessage(
      "Transaction marked as successful",
    ),
    "transactionPlural": MessageLookupByLibrary.simpleMessage("transactions"),
    "transactionSingular": MessageLookupByLibrary.simpleMessage("transaction"),
    "transactionUpdated": MessageLookupByLibrary.simpleMessage(
      "Transaction updated successfully",
    ),
    "tryDifferentKeywords": MessageLookupByLibrary.simpleMessage(
      "Try different keywords",
    ),
    "typeDifferentNumber": MessageLookupByLibrary.simpleMessage(
      "Type a different number",
    ),
    "typeLabel": MessageLookupByLibrary.simpleMessage("Type"),
    "typeNamePhoneOrMomoHint": MessageLookupByLibrary.simpleMessage(
      "Type name, phone or momo code",
    ),
    "typeSidePayment": MessageLookupByLibrary.simpleMessage(
      "Type: Side Payment",
    ),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "uploadBackup": MessageLookupByLibrary.simpleMessage("Upload Backup"),
    "uploadingToSupabase": MessageLookupByLibrary.simpleMessage(
      "Uploading to Supabase...",
    ),
    "useThisNumber": MessageLookupByLibrary.simpleMessage("Use This Number"),
    "ussdAutoDetection": MessageLookupByLibrary.simpleMessage(
      "USSD Auto-Detection",
    ),
    "ussdAutoDetectionDesc": MessageLookupByLibrary.simpleMessage(
      "Enables automatic detection of USSD transaction responses. Only successful transactions will be saved.",
    ),
    "ussdCode": MessageLookupByLibrary.simpleMessage("USSD Code"),
    "ussdCodeCopied": MessageLookupByLibrary.simpleMessage("USSD code copied!"),
    "ussdDetectionActive": MessageLookupByLibrary.simpleMessage(
      "USSD detection is active. Transactions will be auto-validated.",
    ),
    "ussdRecordsTitle": MessageLookupByLibrary.simpleMessage("USSD Records"),
    "validMomoDetected": MessageLookupByLibrary.simpleMessage(
      "Valid momo code detected",
    ),
    "validPhoneDetected": MessageLookupByLibrary.simpleMessage(
      "Valid phone number detected",
    ),
    "viaContact": MessageLookupByLibrary.simpleMessage("via Contacts"),
    "viaScan": MessageLookupByLibrary.simpleMessage("via Scan"),
    "viewBackups": MessageLookupByLibrary.simpleMessage("View Backups"),
    "viewRestoreBackups": MessageLookupByLibrary.simpleMessage(
      "View & Restore Backups",
    ),
    "viewUssdCode": MessageLookupByLibrary.simpleMessage("View USSD Code"),
    "weekly": MessageLookupByLibrary.simpleMessage("Weekly"),
    "welcomeHere": MessageLookupByLibrary.simpleMessage("Welcome here"),
    "whichNumberReceive": MessageLookupByLibrary.simpleMessage(
      "Which number should receive the payment?",
    ),
    "yesterday": MessageLookupByLibrary.simpleMessage("Yesterday"),
  };
}
