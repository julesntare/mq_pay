// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Welcome here`
  String get welcomeHere {
    return Intl.message(
      'Welcome here',
      name: 'welcomeHere',
      desc: '',
      args: [],
    );
  }

  /// `Make your payments smooth & fast!`
  String get shortDesc {
    return Intl.message(
      'Make your payments smooth & fast!',
      name: 'shortDesc',
      desc: '',
      args: [],
    );
  }

  /// `Amount`
  String get amount {
    return Intl.message('Amount', name: 'amount', desc: '', args: []);
  }

  /// `Enter amount`
  String get enterAmount {
    return Intl.message(
      'Enter amount',
      name: 'enterAmount',
      desc: '',
      args: [],
    );
  }

  /// `Mobile Number`
  String get mobileNumber {
    return Intl.message(
      'Mobile Number',
      name: 'mobileNumber',
      desc: '',
      args: [],
    );
  }

  /// `Momo Code`
  String get momoCode {
    return Intl.message('Momo Code', name: 'momoCode', desc: '', args: []);
  }

  /// `Generate`
  String get generate {
    return Intl.message('Generate', name: 'generate', desc: '', args: []);
  }

  /// `Scan Now`
  String get scanNow {
    return Intl.message('Scan Now', name: 'scanNow', desc: '', args: []);
  }

  /// `Reset`
  String get reset {
    return Intl.message('Reset', name: 'reset', desc: '', args: []);
  }

  /// `Settings`
  String get settings {
    return Intl.message('Settings', name: 'settings', desc: '', args: []);
  }

  /// `Save`
  String get save {
    return Intl.message('Save', name: 'save', desc: '', args: []);
  }

  /// `Select Language`
  String get selectLanguage {
    return Intl.message(
      'Select Language',
      name: 'selectLanguage',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid amount.`
  String get invalidAmount {
    return Intl.message(
      'Please enter a valid amount.',
      name: 'invalidAmount',
      desc: '',
      args: [],
    );
  }

  /// `Unable to launch USSD code`
  String get launchError {
    return Intl.message(
      'Unable to launch USSD code',
      name: 'launchError',
      desc: '',
      args: [],
    );
  }

  /// `via Scan`
  String get viaScan {
    return Intl.message('via Scan', name: 'viaScan', desc: '', args: []);
  }

  /// `via Contacts`
  String get viaContact {
    return Intl.message('via Contacts', name: 'viaContact', desc: '', args: []);
  }

  /// `Load from Contacts`
  String get loadFromContacts {
    return Intl.message(
      'Load from Contacts',
      name: 'loadFromContacts',
      desc: '',
      args: [],
    );
  }

  /// `Proceed`
  String get proceed {
    return Intl.message('Proceed', name: 'proceed', desc: '', args: []);
  }

  /// `Invalid USSD code`
  String get invalidUssdCode {
    return Intl.message(
      'Invalid USSD code',
      name: 'invalidUssdCode',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message('Cancel', name: 'cancel', desc: '', args: []);
  }

  /// `OK`
  String get ok {
    return Intl.message('OK', name: 'ok', desc: '', args: []);
  }

  /// `Close`
  String get close {
    return Intl.message('Close', name: 'close', desc: '', args: []);
  }

  /// `Delete`
  String get delete {
    return Intl.message('Delete', name: 'delete', desc: '', args: []);
  }

  /// `Edit`
  String get edit {
    return Intl.message('Edit', name: 'edit', desc: '', args: []);
  }

  /// `Restore`
  String get restore {
    return Intl.message('Restore', name: 'restore', desc: '', args: []);
  }

  /// `Confirm`
  String get confirm {
    return Intl.message('Confirm', name: 'confirm', desc: '', args: []);
  }

  /// `Continue`
  String get continueAction {
    return Intl.message('Continue', name: 'continueAction', desc: '', args: []);
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Add`
  String get add {
    return Intl.message('Add', name: 'add', desc: '', args: []);
  }

  /// `Apply`
  String get apply {
    return Intl.message('Apply', name: 'apply', desc: '', args: []);
  }

  /// `Clear`
  String get clearAction {
    return Intl.message('Clear', name: 'clearAction', desc: '', args: []);
  }

  /// `Next`
  String get next {
    return Intl.message('Next', name: 'next', desc: '', args: []);
  }

  /// `Send Money`
  String get sendMoney {
    return Intl.message('Send Money', name: 'sendMoney', desc: '', args: []);
  }

  /// `Get Paid`
  String get getPaid {
    return Intl.message('Get Paid', name: 'getPaid', desc: '', args: []);
  }

  /// `USSD Code`
  String get ussdCode {
    return Intl.message('USSD Code', name: 'ussdCode', desc: '', args: []);
  }

  /// `Payment Details`
  String get paymentDetails {
    return Intl.message(
      'Payment Details',
      name: 'paymentDetails',
      desc: '',
      args: [],
    );
  }

  /// `Apply Transaction Fee`
  String get applyTransactionFee {
    return Intl.message(
      'Apply Transaction Fee',
      name: 'applyTransactionFee',
      desc: '',
      args: [],
    );
  }

  /// `Recipient Information`
  String get recipientInfo {
    return Intl.message(
      'Recipient Information',
      name: 'recipientInfo',
      desc: '',
      args: [],
    );
  }

  /// `Recipient Name (Optional)`
  String get recipientName {
    return Intl.message(
      'Recipient Name (Optional)',
      name: 'recipientName',
      desc: '',
      args: [],
    );
  }

  /// `Enter name for this recipient`
  String get recipientNameHint {
    return Intl.message(
      'Enter name for this recipient',
      name: 'recipientNameHint',
      desc: '',
      args: [],
    );
  }

  /// `Reason`
  String get reasonLabel {
    return Intl.message('Reason', name: 'reasonLabel', desc: '', args: []);
  }

  /// `Why are you sending this money?`
  String get reasonHint {
    return Intl.message(
      'Why are you sending this money?',
      name: 'reasonHint',
      desc: '',
      args: [],
    );
  }

  /// `Dial`
  String get dial {
    return Intl.message('Dial', name: 'dial', desc: '', args: []);
  }

  /// `Pay Now`
  String get payNow {
    return Intl.message('Pay Now', name: 'payNow', desc: '', args: []);
  }

  /// `Save Record`
  String get saveRecord {
    return Intl.message('Save Record', name: 'saveRecord', desc: '', args: []);
  }

  /// `Side Payment`
  String get sidePayment {
    return Intl.message(
      'Side Payment',
      name: 'sidePayment',
      desc: '',
      args: [],
    );
  }

  /// `Configure your payment preferences`
  String get settingsSubtitle {
    return Intl.message(
      'Configure your payment preferences',
      name: 'settingsSubtitle',
      desc: '',
      args: [],
    );
  }

  /// `Payment Methods`
  String get paymentMethods {
    return Intl.message(
      'Payment Methods',
      name: 'paymentMethods',
      desc: '',
      args: [],
    );
  }

  /// `Manage your mobile numbers and payment options`
  String get paymentMethodsDesc {
    return Intl.message(
      'Manage your mobile numbers and payment options',
      name: 'paymentMethodsDesc',
      desc: '',
      args: [],
    );
  }

  /// `No payment methods configured. Add your first payment method below.`
  String get noPaymentMethods {
    return Intl.message(
      'No payment methods configured. Add your first payment method below.',
      name: 'noPaymentMethods',
      desc: '',
      args: [],
    );
  }

  /// `Add Payment Method`
  String get addPaymentMethod {
    return Intl.message(
      'Add Payment Method',
      name: 'addPaymentMethod',
      desc: '',
      args: [],
    );
  }

  /// `Delete Payment Method`
  String get deletePaymentMethod {
    return Intl.message(
      'Delete Payment Method',
      name: 'deletePaymentMethod',
      desc: '',
      args: [],
    );
  }

  /// `Type`
  String get typeLabel {
    return Intl.message('Type', name: 'typeLabel', desc: '', args: []);
  }

  /// `Provider`
  String get providerLabel {
    return Intl.message('Provider', name: 'providerLabel', desc: '', args: []);
  }

  /// `MTN MoMo`
  String get mtnMomo {
    return Intl.message('MTN MoMo', name: 'mtnMomo', desc: '', args: []);
  }

  /// `Airtel Money`
  String get airtelMoney {
    return Intl.message(
      'Airtel Money',
      name: 'airtelMoney',
      desc: '',
      args: [],
    );
  }

  /// `Phone Number`
  String get phoneNumberLabel {
    return Intl.message(
      'Phone Number',
      name: 'phoneNumberLabel',
      desc: '',
      args: [],
    );
  }

  /// `Language Preferences`
  String get languagePreferences {
    return Intl.message(
      'Language Preferences',
      name: 'languagePreferences',
      desc: '',
      args: [],
    );
  }

  /// `Theme Preferences`
  String get themePreferences {
    return Intl.message(
      'Theme Preferences',
      name: 'themePreferences',
      desc: '',
      args: [],
    );
  }

  /// `Light Theme`
  String get lightTheme {
    return Intl.message('Light Theme', name: 'lightTheme', desc: '', args: []);
  }

  /// `Bright and clean interface`
  String get lightThemeDesc {
    return Intl.message(
      'Bright and clean interface',
      name: 'lightThemeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Dark Theme`
  String get darkTheme {
    return Intl.message('Dark Theme', name: 'darkTheme', desc: '', args: []);
  }

  /// `Easy on the eyes`
  String get darkThemeDesc {
    return Intl.message(
      'Easy on the eyes',
      name: 'darkThemeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Backup & Restore`
  String get backupRestore {
    return Intl.message(
      'Backup & Restore',
      name: 'backupRestore',
      desc: '',
      args: [],
    );
  }

  /// `Export your data to keep it safe or restore from a previous backup`
  String get backupRestoreDesc {
    return Intl.message(
      'Export your data to keep it safe or restore from a previous backup',
      name: 'backupRestoreDesc',
      desc: '',
      args: [],
    );
  }

  /// `Export Backup`
  String get exportBackup {
    return Intl.message(
      'Export Backup',
      name: 'exportBackup',
      desc: '',
      args: [],
    );
  }

  /// `Export to Excel`
  String get exportToExcel {
    return Intl.message(
      'Export to Excel',
      name: 'exportToExcel',
      desc: '',
      args: [],
    );
  }

  /// `Import Backup`
  String get importBackup {
    return Intl.message(
      'Import Backup',
      name: 'importBackup',
      desc: '',
      args: [],
    );
  }

  /// `Auto-Backup`
  String get autoBackup {
    return Intl.message('Auto-Backup', name: 'autoBackup', desc: '', args: []);
  }

  /// `Automatically backup your data periodically`
  String get autoBackupDesc {
    return Intl.message(
      'Automatically backup your data periodically',
      name: 'autoBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Enable Auto-Backup`
  String get enableAutoBackup {
    return Intl.message(
      'Enable Auto-Backup',
      name: 'enableAutoBackup',
      desc: '',
      args: [],
    );
  }

  /// `Backup Frequency`
  String get backupFrequency {
    return Intl.message(
      'Backup Frequency',
      name: 'backupFrequency',
      desc: '',
      args: [],
    );
  }

  /// `Daily`
  String get daily {
    return Intl.message('Daily', name: 'daily', desc: '', args: []);
  }

  /// `Weekly`
  String get weekly {
    return Intl.message('Weekly', name: 'weekly', desc: '', args: []);
  }

  /// `Monthly`
  String get monthly {
    return Intl.message('Monthly', name: 'monthly', desc: '', args: []);
  }

  /// `Backup Location`
  String get backupLocation {
    return Intl.message(
      'Backup Location',
      name: 'backupLocation',
      desc: '',
      args: [],
    );
  }

  /// `Default Location`
  String get defaultLocation {
    return Intl.message(
      'Default Location',
      name: 'defaultLocation',
      desc: '',
      args: [],
    );
  }

  /// `View & Restore Backups`
  String get viewRestoreBackups {
    return Intl.message(
      'View & Restore Backups',
      name: 'viewRestoreBackups',
      desc: '',
      args: [],
    );
  }

  /// `App Information`
  String get appInformation {
    return Intl.message(
      'App Information',
      name: 'appInformation',
      desc: '',
      args: [],
    );
  }

  /// `App Version`
  String get appVersion {
    return Intl.message('App Version', name: 'appVersion', desc: '', args: []);
  }

  /// `Support`
  String get support {
    return Intl.message('Support', name: 'support', desc: '', args: []);
  }

  /// `Privacy`
  String get privacy {
    return Intl.message('Privacy', name: 'privacy', desc: '', args: []);
  }

  /// `Supabase Cloud Backup`
  String get supabaseCloudBackup {
    return Intl.message(
      'Supabase Cloud Backup',
      name: 'supabaseCloudBackup',
      desc: '',
      args: [],
    );
  }

  /// `Upload Backup`
  String get uploadBackup {
    return Intl.message(
      'Upload Backup',
      name: 'uploadBackup',
      desc: '',
      args: [],
    );
  }

  /// `View Backups`
  String get viewBackups {
    return Intl.message(
      'View Backups',
      name: 'viewBackups',
      desc: '',
      args: [],
    );
  }

  /// `No backups yet`
  String get noBackupsYet {
    return Intl.message(
      'No backups yet',
      name: 'noBackupsYet',
      desc: '',
      args: [],
    );
  }

  /// `Available Backups`
  String get availableBackups {
    return Intl.message(
      'Available Backups',
      name: 'availableBackups',
      desc: '',
      args: [],
    );
  }

  /// `Restore Backup?`
  String get restoreBackupTitle {
    return Intl.message(
      'Restore Backup?',
      name: 'restoreBackupTitle',
      desc: '',
      args: [],
    );
  }

  /// `This will merge the backup data with your current data. Duplicates will be automatically skipped.\n\nDo you want to continue?`
  String get restoreBackupDesc {
    return Intl.message(
      'This will merge the backup data with your current data. Duplicates will be automatically skipped.\n\nDo you want to continue?',
      name: 'restoreBackupDesc',
      desc: '',
      args: [],
    );
  }

  /// `Delete Backup?`
  String get deleteBackupTitle {
    return Intl.message(
      'Delete Backup?',
      name: 'deleteBackupTitle',
      desc: '',
      args: [],
    );
  }

  /// `Are you sure you want to delete this backup?`
  String get deleteBackupMessage {
    return Intl.message(
      'Are you sure you want to delete this backup?',
      name: 'deleteBackupMessage',
      desc: '',
      args: [],
    );
  }

  /// `Import Backup`
  String get importBackupTitle {
    return Intl.message(
      'Import Backup',
      name: 'importBackupTitle',
      desc: '',
      args: [],
    );
  }

  /// `Importing a backup will replace all your current data including transactions, payment methods, and settings. This action cannot be undone.\n\nDo you want to continue?`
  String get importBackupWarning {
    return Intl.message(
      'Importing a backup will replace all your current data including transactions, payment methods, and settings. This action cannot be undone.\n\nDo you want to continue?',
      name: 'importBackupWarning',
      desc: '',
      args: [],
    );
  }

  /// `Restore Complete`
  String get backupRestoredTitle {
    return Intl.message(
      'Restore Complete',
      name: 'backupRestoredTitle',
      desc: '',
      args: [],
    );
  }

  /// `Your data has been restored successfully!`
  String get backupRestoredMsg {
    return Intl.message(
      'Your data has been restored successfully!',
      name: 'backupRestoredMsg',
      desc: '',
      args: [],
    );
  }

  /// `Backup exported successfully!`
  String get backupExportedSuccess {
    return Intl.message(
      'Backup exported successfully!',
      name: 'backupExportedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Excel file exported successfully!`
  String get excelExportedSuccess {
    return Intl.message(
      'Excel file exported successfully!',
      name: 'excelExportedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Exporting backup...`
  String get exportingBackup {
    return Intl.message(
      'Exporting backup...',
      name: 'exportingBackup',
      desc: '',
      args: [],
    );
  }

  /// `Importing backup...`
  String get importingBackup {
    return Intl.message(
      'Importing backup...',
      name: 'importingBackup',
      desc: '',
      args: [],
    );
  }

  /// `Restoring backup...`
  String get restoringBackup {
    return Intl.message(
      'Restoring backup...',
      name: 'restoringBackup',
      desc: '',
      args: [],
    );
  }

  /// `Exporting to Excel...`
  String get exportingToExcel {
    return Intl.message(
      'Exporting to Excel...',
      name: 'exportingToExcel',
      desc: '',
      args: [],
    );
  }

  /// `USSD Records`
  String get ussdRecordsTitle {
    return Intl.message(
      'USSD Records',
      name: 'ussdRecordsTitle',
      desc: '',
      args: [],
    );
  }

  /// `Search by name, number, amount, reason...`
  String get searchHint {
    return Intl.message(
      'Search by name, number, amount, reason...',
      name: 'searchHint',
      desc: '',
      args: [],
    );
  }

  /// `Filters`
  String get filtersLabel {
    return Intl.message('Filters', name: 'filtersLabel', desc: '', args: []);
  }

  /// `All`
  String get allFilter {
    return Intl.message('All', name: 'allFilter', desc: '', args: []);
  }

  /// `Phone`
  String get phoneFilter {
    return Intl.message('Phone', name: 'phoneFilter', desc: '', args: []);
  }

  /// `Date`
  String get dateLabel {
    return Intl.message('Date', name: 'dateLabel', desc: '', args: []);
  }

  /// `Single`
  String get singleDate {
    return Intl.message('Single', name: 'singleDate', desc: '', args: []);
  }

  /// `Range`
  String get dateRange {
    return Intl.message('Range', name: 'dateRange', desc: '', args: []);
  }

  /// `Start date`
  String get startDate {
    return Intl.message('Start date', name: 'startDate', desc: '', args: []);
  }

  /// `End date`
  String get endDate {
    return Intl.message('End date', name: 'endDate', desc: '', args: []);
  }

  /// `Mark as Successful`
  String get markSuccessful {
    return Intl.message(
      'Mark as Successful',
      name: 'markSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Mark as Failed`
  String get markFailed {
    return Intl.message(
      'Mark as Failed',
      name: 'markFailed',
      desc: '',
      args: [],
    );
  }

  /// `Redial`
  String get redial {
    return Intl.message('Redial', name: 'redial', desc: '', args: []);
  }

  /// `View USSD Code`
  String get viewUssdCode {
    return Intl.message(
      'View USSD Code',
      name: 'viewUssdCode',
      desc: '',
      args: [],
    );
  }

  /// `Mark as Invalid`
  String get markInvalid {
    return Intl.message(
      'Mark as Invalid',
      name: 'markInvalid',
      desc: '',
      args: [],
    );
  }

  /// `Transaction updated successfully`
  String get transactionUpdated {
    return Intl.message(
      'Transaction updated successfully',
      name: 'transactionUpdated',
      desc: '',
      args: [],
    );
  }

  /// `USSD Auto-Detection`
  String get ussdAutoDetection {
    return Intl.message(
      'USSD Auto-Detection',
      name: 'ussdAutoDetection',
      desc: '',
      args: [],
    );
  }

  /// `Active`
  String get activeStatus {
    return Intl.message('Active', name: 'activeStatus', desc: '', args: []);
  }

  /// `Not Enabled`
  String get notEnabled {
    return Intl.message('Not Enabled', name: 'notEnabled', desc: '', args: []);
  }

  /// `Open Accessibility Settings`
  String get openAccessibilitySettings {
    return Intl.message(
      'Open Accessibility Settings',
      name: 'openAccessibilitySettings',
      desc: '',
      args: [],
    );
  }

  /// `Error`
  String get error {
    return Intl.message('Error', name: 'error', desc: '', args: []);
  }

  /// `Please restart the app to see all changes.`
  String get pleaseRestartApp {
    return Intl.message(
      'Please restart the app to see all changes.',
      name: 'pleaseRestartApp',
      desc: '',
      args: [],
    );
  }

  /// `Invalid Phone Number`
  String get invalidPhoneNumber {
    return Intl.message(
      'Invalid Phone Number',
      name: 'invalidPhoneNumber',
      desc: '',
      args: [],
    );
  }

  /// `USSD code copied!`
  String get ussdCodeCopied {
    return Intl.message(
      'USSD code copied!',
      name: 'ussdCodeCopied',
      desc: '',
      args: [],
    );
  }

  /// `Payment record saved successfully!`
  String get paymentRecordSaved {
    return Intl.message(
      'Payment record saved successfully!',
      name: 'paymentRecordSaved',
      desc: '',
      args: [],
    );
  }

  /// `Clear All Records`
  String get clearAllRecords {
    return Intl.message(
      'Clear All Records',
      name: 'clearAllRecords',
      desc: '',
      args: [],
    );
  }

  /// `Clear All`
  String get clearAll {
    return Intl.message('Clear All', name: 'clearAll', desc: '', args: []);
  }

  /// `Are you sure you want to clear all USSD records? This action cannot be undone.`
  String get clearAllConfirmMsg {
    return Intl.message(
      'Are you sure you want to clear all USSD records? This action cannot be undone.',
      name: 'clearAllConfirmMsg',
      desc: '',
      args: [],
    );
  }

  /// `All records cleared successfully`
  String get allRecordsCleared {
    return Intl.message(
      'All records cleared successfully',
      name: 'allRecordsCleared',
      desc: '',
      args: [],
    );
  }

  /// `Record Only Mode`
  String get recordOnlyMode {
    return Intl.message(
      'Record Only Mode',
      name: 'recordOnlyMode',
      desc: '',
      args: [],
    );
  }

  /// `Confirm this transaction completed`
  String get confirmTransactionComplete {
    return Intl.message(
      'Confirm this transaction completed',
      name: 'confirmTransactionComplete',
      desc: '',
      args: [],
    );
  }

  /// `Select Payment Method`
  String get selectPaymentMethod {
    return Intl.message(
      'Select Payment Method',
      name: 'selectPaymentMethod',
      desc: '',
      args: [],
    );
  }

  /// `Enter manually`
  String get enterManually {
    return Intl.message(
      'Enter manually',
      name: 'enterManually',
      desc: '',
      args: [],
    );
  }

  /// `Use This Number`
  String get useThisNumber {
    return Intl.message(
      'Use This Number',
      name: 'useThisNumber',
      desc: '',
      args: [],
    );
  }

  /// `Payment Request QR`
  String get paymentRequestQR {
    return Intl.message(
      'Payment Request QR',
      name: 'paymentRequestQR',
      desc: '',
      args: [],
    );
  }

  /// `Backup deleted successfully`
  String get backupDeletedSuccess {
    return Intl.message(
      'Backup deleted successfully',
      name: 'backupDeletedSuccess',
      desc: '',
      args: [],
    );
  }

  /// `Uploading to Supabase...`
  String get uploadingToSupabase {
    return Intl.message(
      'Uploading to Supabase...',
      name: 'uploadingToSupabase',
      desc: '',
      args: [],
    );
  }

  /// `Restoring from Supabase...`
  String get restoringFromSupabase {
    return Intl.message(
      'Restoring from Supabase...',
      name: 'restoringFromSupabase',
      desc: '',
      args: [],
    );
  }

  /// `No backups found`
  String get noBackupsFound {
    return Intl.message(
      'No backups found',
      name: 'noBackupsFound',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid value`
  String get pleaseEnterValidValue {
    return Intl.message(
      'Please enter a valid value',
      name: 'pleaseEnterValidValue',
      desc: '',
      args: [],
    );
  }

  /// `Supabase credentials not configured`
  String get supabaseNotConfigured {
    return Intl.message(
      'Supabase credentials not configured',
      name: 'supabaseNotConfigured',
      desc: '',
      args: [],
    );
  }

  /// `Checking status...`
  String get checkingStatus {
    return Intl.message(
      'Checking status...',
      name: 'checkingStatus',
      desc: '',
      args: [],
    );
  }

  /// `Tap below to enable in Settings`
  String get tapToEnable {
    return Intl.message(
      'Tap below to enable in Settings',
      name: 'tapToEnable',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid amount first`
  String get pleaseEnterValidAmount {
    return Intl.message(
      'Please enter a valid amount first',
      name: 'pleaseEnterValidAmount',
      desc: '',
      args: [],
    );
  }

  /// `Contact permission denied`
  String get contactPermissionDenied {
    return Intl.message(
      'Contact permission denied',
      name: 'contactPermissionDenied',
      desc: '',
      args: [],
    );
  }

  /// `Enter momo code`
  String get momoCodeHint {
    return Intl.message(
      'Enter momo code',
      name: 'momoCodeHint',
      desc: '',
      args: [],
    );
  }

  /// `078xxxxxxx`
  String get phoneNumberHint {
    return Intl.message(
      '078xxxxxxx',
      name: 'phoneNumberHint',
      desc: '',
      args: [],
    );
  }

  /// `Restored successfully!`
  String get restoredSuccess {
    return Intl.message(
      'Restored successfully!',
      name: 'restoredSuccess',
      desc: '',
      args: [],
    );
  }

  /// `No records found`
  String get noRecordsFound {
    return Intl.message(
      'No records found',
      name: 'noRecordsFound',
      desc: '',
      args: [],
    );
  }

  /// `Syncing all dates...`
  String get syncingDates {
    return Intl.message(
      'Syncing all dates...',
      name: 'syncingDates',
      desc: '',
      args: [],
    );
  }

  /// `Sync Complete`
  String get syncComplete {
    return Intl.message(
      'Sync Complete',
      name: 'syncComplete',
      desc: '',
      args: [],
    );
  }

  /// `General`
  String get general {
    return Intl.message('General', name: 'general', desc: '', args: []);
  }

  /// `Create a QR code for someone to pay you`
  String get createQrCodeDesc {
    return Intl.message(
      'Create a QR code for someone to pay you',
      name: 'createQrCodeDesc',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid amount (minimum 1 RWF)`
  String get enterValidMinAmount {
    return Intl.message(
      'Please enter a valid amount (minimum 1 RWF)',
      name: 'enterValidMinAmount',
      desc: '',
      args: [],
    );
  }

  /// `Generate QR Code`
  String get generateQrCode {
    return Intl.message(
      'Generate QR Code',
      name: 'generateQrCode',
      desc: '',
      args: [],
    );
  }

  /// `Amount (RWF)`
  String get amountRwf {
    return Intl.message('Amount (RWF)', name: 'amountRwf', desc: '', args: []);
  }

  /// `Phone Number or Momo Code (Optional)`
  String get phoneOrMomoOptional {
    return Intl.message(
      'Phone Number or Momo Code (Optional)',
      name: 'phoneOrMomoOptional',
      desc: '',
      args: [],
    );
  }

  /// `Phone Number or Momo Code`
  String get phoneOrMomo {
    return Intl.message(
      'Phone Number or Momo Code',
      name: 'phoneOrMomo',
      desc: '',
      args: [],
    );
  }

  /// `Optional - leave blank for side payments`
  String get optionalSidePaymentsHint {
    return Intl.message(
      'Optional - leave blank for side payments',
      name: 'optionalSidePaymentsHint',
      desc: '',
      args: [],
    );
  }

  /// `Type name, phone or momo code`
  String get typeNamePhoneOrMomoHint {
    return Intl.message(
      'Type name, phone or momo code',
      name: 'typeNamePhoneOrMomoHint',
      desc: '',
      args: [],
    );
  }

  /// `Back`
  String get back {
    return Intl.message('Back', name: 'back', desc: '', args: []);
  }

  /// `Invalid phone number or momo code`
  String get invalidPhoneOrMomo {
    return Intl.message(
      'Invalid phone number or momo code',
      name: 'invalidPhoneOrMomo',
      desc: '',
      args: [],
    );
  }

  /// `Dial this USSD code:`
  String get dialUssdCode {
    return Intl.message(
      'Dial this USSD code:',
      name: 'dialUssdCode',
      desc: '',
      args: [],
    );
  }

  /// `Type a different number`
  String get typeDifferentNumber {
    return Intl.message(
      'Type a different number',
      name: 'typeDifferentNumber',
      desc: '',
      args: [],
    );
  }

  /// `Enter Payment Number`
  String get enterPaymentNumber {
    return Intl.message(
      'Enter Payment Number',
      name: 'enterPaymentNumber',
      desc: '',
      args: [],
    );
  }

  /// `Enter the phone number or momo code to receive payment`
  String get enterPhoneOrMomoDesc {
    return Intl.message(
      'Enter the phone number or momo code to receive payment',
      name: 'enterPhoneOrMomoDesc',
      desc: '',
      args: [],
    );
  }

  /// `Phone: 078xxxxxxx or Momo: 123456`
  String get phoneOrMomoExample {
    return Intl.message(
      'Phone: 078xxxxxxx or Momo: 123456',
      name: 'phoneOrMomoExample',
      desc: '',
      args: [],
    );
  }

  /// `Phone number format detected`
  String get phoneFormatDetected {
    return Intl.message(
      'Phone number format detected',
      name: 'phoneFormatDetected',
      desc: '',
      args: [],
    );
  }

  /// `Momo code format detected`
  String get momoFormatDetected {
    return Intl.message(
      'Momo code format detected',
      name: 'momoFormatDetected',
      desc: '',
      args: [],
    );
  }

  /// `Enter valid phone number or momo code`
  String get enterValidPhoneOrMomo {
    return Intl.message(
      'Enter valid phone number or momo code',
      name: 'enterValidPhoneOrMomo',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid phone number (078xxxxxxx) or momo code`
  String get enterValidPhoneOrMomoMsg {
    return Intl.message(
      'Please enter a valid phone number (078xxxxxxx) or momo code',
      name: 'enterValidPhoneOrMomoMsg',
      desc: '',
      args: [],
    );
  }

  /// `Valid phone number detected`
  String get validPhoneDetected {
    return Intl.message(
      'Valid phone number detected',
      name: 'validPhoneDetected',
      desc: '',
      args: [],
    );
  }

  /// `Valid momo code detected`
  String get validMomoDetected {
    return Intl.message(
      'Valid momo code detected',
      name: 'validMomoDetected',
      desc: '',
      args: [],
    );
  }

  /// `Got it`
  String get gotIt {
    return Intl.message('Got it', name: 'gotIt', desc: '', args: []);
  }

  /// `Record Only`
  String get recordOnly {
    return Intl.message('Record Only', name: 'recordOnly', desc: '', args: []);
  }

  /// `When enabled, transactions are saved as records without executing the payment. This is useful for tracking side payments or manually handled transactions.`
  String get recordOnlyExplain {
    return Intl.message(
      'When enabled, transactions are saved as records without executing the payment. This is useful for tracking side payments or manually handled transactions.',
      name: 'recordOnlyExplain',
      desc: '',
      args: [],
    );
  }

  /// `Reason (optional)`
  String get reasonOptional {
    return Intl.message(
      'Reason (optional)',
      name: 'reasonOptional',
      desc: '',
      args: [],
    );
  }

  /// `Today`
  String get today {
    return Intl.message('Today', name: 'today', desc: '', args: []);
  }

  /// `Yesterday`
  String get yesterday {
    return Intl.message('Yesterday', name: 'yesterday', desc: '', args: []);
  }

  /// `Redial Transaction`
  String get redialTransaction {
    return Intl.message(
      'Redial Transaction',
      name: 'redialTransaction',
      desc: '',
      args: [],
    );
  }

  /// `You are about to redial this transaction:`
  String get aboutToRedial {
    return Intl.message(
      'You are about to redial this transaction:',
      name: 'aboutToRedial',
      desc: '',
      args: [],
    );
  }

  /// `Try different keywords`
  String get tryDifferentKeywords {
    return Intl.message(
      'Try different keywords',
      name: 'tryDifferentKeywords',
      desc: '',
      args: [],
    );
  }

  /// `Tap the filter again to view all`
  String get tapFilterViewAll {
    return Intl.message(
      'Tap the filter again to view all',
      name: 'tapFilterViewAll',
      desc: '',
      args: [],
    );
  }

  /// `MoCode`
  String get moCode {
    return Intl.message('MoCode', name: 'moCode', desc: '', args: []);
  }

  /// `Misc`
  String get misc {
    return Intl.message('Misc', name: 'misc', desc: '', args: []);
  }

  /// `No reasons found`
  String get noReasonsFound {
    return Intl.message(
      'No reasons found',
      name: 'noReasonsFound',
      desc: '',
      args: [],
    );
  }

  /// `Clear reason filter`
  String get clearReasonFilter {
    return Intl.message(
      'Clear reason filter',
      name: 'clearReasonFilter',
      desc: '',
      args: [],
    );
  }

  /// `Search reasons...`
  String get searchReasons {
    return Intl.message(
      'Search reasons...',
      name: 'searchReasons',
      desc: '',
      args: [],
    );
  }

  /// `Set as Default`
  String get setAsDefault {
    return Intl.message(
      'Set as Default',
      name: 'setAsDefault',
      desc: '',
      args: [],
    );
  }

  /// `Edit Payment Method`
  String get editPaymentMethod {
    return Intl.message(
      'Edit Payment Method',
      name: 'editPaymentMethod',
      desc: '',
      args: [],
    );
  }

  /// `Loading backups...`
  String get loadingBackups {
    return Intl.message(
      'Loading backups...',
      name: 'loadingBackups',
      desc: '',
      args: [],
    );
  }

  /// `Supabase Backups`
  String get supabaseBackups {
    return Intl.message(
      'Supabase Backups',
      name: 'supabaseBackups',
      desc: '',
      args: [],
    );
  }

  /// `Enables automatic detection of USSD transaction responses. Only successful transactions will be saved.`
  String get ussdAutoDetectionDesc {
    return Intl.message(
      'Enables automatic detection of USSD transaction responses. Only successful transactions will be saved.',
      name: 'ussdAutoDetectionDesc',
      desc: '',
      args: [],
    );
  }

  /// `Refresh status`
  String get refreshStatus {
    return Intl.message(
      'Refresh status',
      name: 'refreshStatus',
      desc: '',
      args: [],
    );
  }

  /// `Steps to enable:\n1. Find "MQ Pay" in the list\n2. Toggle the switch to ON\n3. Grant permission`
  String get stepsToEnable {
    return Intl.message(
      'Steps to enable:\n1. Find "MQ Pay" in the list\n2. Toggle the switch to ON\n3. Grant permission',
      name: 'stepsToEnable',
      desc: '',
      args: [],
    );
  }

  /// `USSD detection is active. Transactions will be auto-validated.`
  String get ussdDetectionActive {
    return Intl.message(
      'USSD detection is active. Transactions will be auto-validated.',
      name: 'ussdDetectionActive',
      desc: '',
      args: [],
    );
  }

  /// `Overall Total`
  String get overallTotal {
    return Intl.message(
      'Overall Total',
      name: 'overallTotal',
      desc: '',
      args: [],
    );
  }

  /// `Fees Included in All Totals`
  String get feesIncludedInTotals {
    return Intl.message(
      'Fees Included in All Totals',
      name: 'feesIncludedInTotals',
      desc: '',
      args: [],
    );
  }

  /// `Fees Excluded from All Totals`
  String get feesExcludedFromTotals {
    return Intl.message(
      'Fees Excluded from All Totals',
      name: 'feesExcludedFromTotals',
      desc: '',
      args: [],
    );
  }

  /// `Total Fees Paid`
  String get totalFeesPaid {
    return Intl.message(
      'Total Fees Paid',
      name: 'totalFeesPaid',
      desc: '',
      args: [],
    );
  }

  /// `Total`
  String get total {
    return Intl.message('Total', name: 'total', desc: '', args: []);
  }

  /// `fees`
  String get fees {
    return Intl.message('fees', name: 'fees', desc: '', args: []);
  }

  /// `Side Payments`
  String get sidePayments {
    return Intl.message(
      'Side Payments',
      name: 'sidePayments',
      desc: '',
      args: [],
    );
  }

  /// `transaction`
  String get transactionSingular {
    return Intl.message(
      'transaction',
      name: 'transactionSingular',
      desc: '',
      args: [],
    );
  }

  /// `transactions`
  String get transactionPlural {
    return Intl.message(
      'transactions',
      name: 'transactionPlural',
      desc: '',
      args: [],
    );
  }

  /// `No results for "{query}"`
  String noResultsFor(String query) {
    return Intl.message(
      'No results for "$query"',
      name: 'noResultsFor',
      desc: '',
      args: [query],
    );
  }

  /// `No {filterName} transactions`
  String noFilterTransactions(String filterName) {
    return Intl.message(
      'No $filterName transactions',
      name: 'noFilterTransactions',
      desc: '',
      args: [filterName],
    );
  }

  /// `Contact`
  String get contact {
    return Intl.message('Contact', name: 'contact', desc: '', args: []);
  }

  /// `Enter phone number or momo code`
  String get enterPhoneOrMomoHint {
    return Intl.message(
      'Enter phone number or momo code',
      name: 'enterPhoneOrMomoHint',
      desc: '',
      args: [],
    );
  }

  /// `Quick Payment`
  String get quickPayment {
    return Intl.message(
      'Quick Payment',
      name: 'quickPayment',
      desc: '',
      args: [],
    );
  }

  /// `How much do you want to send?`
  String get howMuchSend {
    return Intl.message(
      'How much do you want to send?',
      name: 'howMuchSend',
      desc: '',
      args: [],
    );
  }

  /// `Step {step} of 2`
  String stepOf(int step) {
    return Intl.message(
      'Step $step of 2',
      name: 'stepOf',
      desc: '',
      args: [step],
    );
  }

  /// `Transaction Actions`
  String get transactionActions {
    return Intl.message(
      'Transaction Actions',
      name: 'transactionActions',
      desc: '',
      args: [],
    );
  }

  /// `This transaction did not complete`
  String get transactionDidNotComplete {
    return Intl.message(
      'This transaction did not complete',
      name: 'transactionDidNotComplete',
      desc: '',
      args: [],
    );
  }

  /// `Make the same payment again`
  String get makeSamePaymentAgain {
    return Intl.message(
      'Make the same payment again',
      name: 'makeSamePaymentAgain',
      desc: '',
      args: [],
    );
  }

  /// `Modify transaction details`
  String get modifyTransactionDetails {
    return Intl.message(
      'Modify transaction details',
      name: 'modifyTransactionDetails',
      desc: '',
      args: [],
    );
  }

  /// `See the full USSD code used`
  String get seeFullUssdCode {
    return Intl.message(
      'See the full USSD code used',
      name: 'seeFullUssdCode',
      desc: '',
      args: [],
    );
  }

  /// `Delete failed or duplicate transaction`
  String get deleteFailedOrDuplicate {
    return Intl.message(
      'Delete failed or duplicate transaction',
      name: 'deleteFailedOrDuplicate',
      desc: '',
      args: [],
    );
  }

  /// `Transaction marked as successful`
  String get transactionMarkedSuccessful {
    return Intl.message(
      'Transaction marked as successful',
      name: 'transactionMarkedSuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Transaction marked as failed`
  String get transactionMarkedFailed {
    return Intl.message(
      'Transaction marked as failed',
      name: 'transactionMarkedFailed',
      desc: '',
      args: [],
    );
  }

  /// `Invalid transaction deleted successfully`
  String get invalidTransactionDeleted {
    return Intl.message(
      'Invalid transaction deleted successfully',
      name: 'invalidTransactionDeleted',
      desc: '',
      args: [],
    );
  }

  /// `Refresh`
  String get refresh {
    return Intl.message('Refresh', name: 'refresh', desc: '', args: []);
  }

  /// `Edit Transaction`
  String get editTransaction {
    return Intl.message(
      'Edit Transaction',
      name: 'editTransaction',
      desc: '',
      args: [],
    );
  }

  /// `Phone Payment`
  String get phonePayment {
    return Intl.message(
      'Phone Payment',
      name: 'phonePayment',
      desc: '',
      args: [],
    );
  }

  /// `Momo Payment`
  String get momoPayment {
    return Intl.message(
      'Momo Payment',
      name: 'momoPayment',
      desc: '',
      args: [],
    );
  }

  /// `Contact Name (Optional)`
  String get contactNameOptional {
    return Intl.message(
      'Contact Name (Optional)',
      name: 'contactNameOptional',
      desc: '',
      args: [],
    );
  }

  /// `Enter name for this contact`
  String get enterNameForContact {
    return Intl.message(
      'Enter name for this contact',
      name: 'enterNameForContact',
      desc: '',
      args: [],
    );
  }

  /// `Optional note about this transaction`
  String get optionalTransactionNote {
    return Intl.message(
      'Optional note about this transaction',
      name: 'optionalTransactionNote',
      desc: '',
      args: [],
    );
  }

  /// `Save Changes`
  String get saveChanges {
    return Intl.message(
      'Save Changes',
      name: 'saveChanges',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid phone number`
  String get pleaseEnterValidPhone {
    return Intl.message(
      'Please enter a valid phone number',
      name: 'pleaseEnterValidPhone',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid momo code`
  String get pleaseEnterValidMomo {
    return Intl.message(
      'Please enter a valid momo code',
      name: 'pleaseEnterValidMomo',
      desc: '',
      args: [],
    );
  }

  /// `Scan QR Code`
  String get scanQrCode {
    return Intl.message('Scan QR Code', name: 'scanQrCode', desc: '', args: []);
  }

  /// `Position the QR code within the frame to scan`
  String get positionQrCode {
    return Intl.message(
      'Position the QR code within the frame to scan',
      name: 'positionQrCode',
      desc: '',
      args: [],
    );
  }

  /// `No auto-backups found`
  String get noAutoBackupsFound {
    return Intl.message(
      'No auto-backups found',
      name: 'noAutoBackupsFound',
      desc: '',
      args: [],
    );
  }

  /// `Restore Failed`
  String get restoreFailedTitle {
    return Intl.message(
      'Restore Failed',
      name: 'restoreFailedTitle',
      desc: '',
      args: [],
    );
  }

  /// `Backup Uploaded`
  String get backupUploadedTitle {
    return Intl.message(
      'Backup Uploaded',
      name: 'backupUploadedTitle',
      desc: '',
      args: [],
    );
  }

  /// `Scanned: {result}`
  String scannedResult(String result) {
    return Intl.message(
      'Scanned: $result',
      name: 'scannedResult',
      desc: '',
      args: [result],
    );
  }

  /// `Contact loaded: {number}`
  String contactLoaded(String number) {
    return Intl.message(
      'Contact loaded: $number',
      name: 'contactLoaded',
      desc: '',
      args: [number],
    );
  }

  /// `To: {name}`
  String toRecipient(String name) {
    return Intl.message(
      'To: $name',
      name: 'toRecipient',
      desc: '',
      args: [name],
    );
  }

  /// `Phone: {number}`
  String phoneLabel(String number) {
    return Intl.message(
      'Phone: $number',
      name: 'phoneLabel',
      desc: '',
      args: [number],
    );
  }

  /// `Momo Code: {code}`
  String momoCodeLabel(String code) {
    return Intl.message(
      'Momo Code: $code',
      name: 'momoCodeLabel',
      desc: '',
      args: [code],
    );
  }

  /// `Fee: {amount}`
  String feeLabel(String amount) {
    return Intl.message(
      'Fee: $amount',
      name: 'feeLabel',
      desc: '',
      args: [amount],
    );
  }

  /// `Total: {amount}`
  String totalLabel(String amount) {
    return Intl.message(
      'Total: $amount',
      name: 'totalLabel',
      desc: '',
      args: [amount],
    );
  }

  /// `Tariff Type: {type}`
  String tariffTypeLabel(String type) {
    return Intl.message(
      'Tariff Type: $type',
      name: 'tariffTypeLabel',
      desc: '',
      args: [type],
    );
  }

  /// `Amount: {amount} RWF`
  String amountRwfLabel(String amount) {
    return Intl.message(
      'Amount: $amount RWF',
      name: 'amountRwfLabel',
      desc: '',
      args: [amount],
    );
  }

  /// `Recipient: {recipient}`
  String recipientLabel(String recipient) {
    return Intl.message(
      'Recipient: $recipient',
      name: 'recipientLabel',
      desc: '',
      args: [recipient],
    );
  }

  /// `Generate Payment QR`
  String get generatePaymentQr {
    return Intl.message(
      'Generate Payment QR',
      name: 'generatePaymentQr',
      desc: '',
      args: [],
    );
  }

  /// `Enter the amount you want to receive, then generate a QR code to show the payer`
  String get generateQrHint {
    return Intl.message(
      'Enter the amount you want to receive, then generate a QR code to show the payer',
      name: 'generateQrHint',
      desc: '',
      args: [],
    );
  }

  /// `Fee will be added to total`
  String get feeWillBeAdded {
    return Intl.message(
      'Fee will be added to total',
      name: 'feeWillBeAdded',
      desc: '',
      args: [],
    );
  }

  /// `No fee will be applied`
  String get noFeeApplied {
    return Intl.message(
      'No fee will be applied',
      name: 'noFeeApplied',
      desc: '',
      args: [],
    );
  }

  /// `Fee tracking enabled (no fee calculated for this type)`
  String get feeTrackingEnabled {
    return Intl.message(
      'Fee tracking enabled (no fee calculated for this type)',
      name: 'feeTrackingEnabled',
      desc: '',
      args: [],
    );
  }

  /// `No fee will be tracked`
  String get noFeeTracked {
    return Intl.message(
      'No fee will be tracked',
      name: 'noFeeTracked',
      desc: '',
      args: [],
    );
  }

  /// `Save Payment Record`
  String get savePaymentRecord {
    return Intl.message(
      'Save Payment Record',
      name: 'savePaymentRecord',
      desc: '',
      args: [],
    );
  }

  /// `Type: Side Payment`
  String get typeSidePayment {
    return Intl.message(
      'Type: Side Payment',
      name: 'typeSidePayment',
      desc: '',
      args: [],
    );
  }

  /// `The selected contact has an invalid phone number format. Please select a contact with a valid Rwanda phone number.`
  String get invalidContactPhone {
    return Intl.message(
      'The selected contact has an invalid phone number format. Please select a contact with a valid Rwanda phone number.',
      name: 'invalidContactPhone',
      desc: '',
      args: [],
    );
  }

  /// `Show this QR code to receive payment`
  String get showQrToReceive {
    return Intl.message(
      'Show this QR code to receive payment',
      name: 'showQrToReceive',
      desc: '',
      args: [],
    );
  }

  /// `The payer can scan this code to pay you the exact amount at the specified number`
  String get payerScanWithNumber {
    return Intl.message(
      'The payer can scan this code to pay you the exact amount at the specified number',
      name: 'payerScanWithNumber',
      desc: '',
      args: [],
    );
  }

  /// `The payer can scan this code to quickly pay you the exact amount`
  String get payerScanQuick {
    return Intl.message(
      'The payer can scan this code to quickly pay you the exact amount',
      name: 'payerScanQuick',
      desc: '',
      args: [],
    );
  }

  /// `Suggestions`
  String get suggestions {
    return Intl.message('Suggestions', name: 'suggestions', desc: '', args: []);
  }

  /// `Probably invalid number`
  String get probablyInvalidNumber {
    return Intl.message(
      'Probably invalid number',
      name: 'probablyInvalidNumber',
      desc: '',
      args: [],
    );
  }

  /// `Probably a momo code`
  String get probablyMomoCode {
    return Intl.message(
      'Probably a momo code',
      name: 'probablyMomoCode',
      desc: '',
      args: [],
    );
  }

  /// `Which number should receive the payment?`
  String get whichNumberReceive {
    return Intl.message(
      'Which number should receive the payment?',
      name: 'whichNumberReceive',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'fr'),
      Locale.fromSubtags(languageCode: 'rw'),
      Locale.fromSubtags(languageCode: 'sw'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
