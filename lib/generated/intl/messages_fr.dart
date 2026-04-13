// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
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
  String get localeName => 'fr';

  static String m0(amount) => "Montant: ${amount} RWF";

  static String m1(number) => "Contact chargé: ${number}";

  static String m2(amount) => "Frais: ${amount}";

  static String m3(code) => "Code Momo: ${code}";

  static String m4(filterName) => "Aucune transaction ${filterName}";

  static String m5(query) => "Aucun résultat pour \"${query}\"";

  static String m6(number) => "Téléphone: ${number}";

  static String m7(recipient) => "Destinataire: ${recipient}";

  static String m8(result) => "Scanné: ${result}";

  static String m9(step) => "Étape ${step} sur 2";

  static String m10(type) => "Type de tarif: ${type}";

  static String m11(name) => "À: ${name}";

  static String m12(amount) => "Total: ${amount}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "aboutToRedial": MessageLookupByLibrary.simpleMessage(
      "Vous êtes sur le point de recomposer cette transaction :",
    ),
    "activeStatus": MessageLookupByLibrary.simpleMessage("Actif"),
    "add": MessageLookupByLibrary.simpleMessage("Ajouter"),
    "addPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Ajouter une méthode de paiement",
    ),
    "airtelMoney": MessageLookupByLibrary.simpleMessage("Airtel Money"),
    "allFilter": MessageLookupByLibrary.simpleMessage("Tous"),
    "allRecordsCleared": MessageLookupByLibrary.simpleMessage(
      "Tous les enregistrements ont été effacés avec succès",
    ),
    "amount": MessageLookupByLibrary.simpleMessage("Montant"),
    "amountRwf": MessageLookupByLibrary.simpleMessage("Montant (RWF)"),
    "amountRwfLabel": m0,
    "appInformation": MessageLookupByLibrary.simpleMessage(
      "Informations sur l\'application",
    ),
    "appVersion": MessageLookupByLibrary.simpleMessage(
      "Version de l\'application",
    ),
    "apply": MessageLookupByLibrary.simpleMessage("Appliquer"),
    "applyTransactionFee": MessageLookupByLibrary.simpleMessage(
      "Appliquer les frais de transaction",
    ),
    "autoBackup": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde automatique",
    ),
    "autoBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Sauvegardez automatiquement vos données périodiquement",
    ),
    "availableBackups": MessageLookupByLibrary.simpleMessage(
      "Sauvegardes disponibles",
    ),
    "back": MessageLookupByLibrary.simpleMessage("Retour"),
    "backupDeletedSuccess": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde supprimée avec succès",
    ),
    "backupExportedSuccess": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde exportée avec succès!",
    ),
    "backupFrequency": MessageLookupByLibrary.simpleMessage(
      "Fréquence de sauvegarde",
    ),
    "backupLocation": MessageLookupByLibrary.simpleMessage(
      "Emplacement de sauvegarde",
    ),
    "backupRestore": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde et restauration",
    ),
    "backupRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "Exportez vos données pour les protéger ou restaurez depuis une sauvegarde précédente",
    ),
    "backupRestoredMsg": MessageLookupByLibrary.simpleMessage(
      "Vos données ont été restaurées avec succès!",
    ),
    "backupRestoredTitle": MessageLookupByLibrary.simpleMessage(
      "Restauration terminée",
    ),
    "backupUploadedTitle": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde téléchargée",
    ),
    "cancel": MessageLookupByLibrary.simpleMessage("Annuler"),
    "checkingStatus": MessageLookupByLibrary.simpleMessage(
      "Vérification du statut...",
    ),
    "clearAction": MessageLookupByLibrary.simpleMessage("Effacer"),
    "clearAll": MessageLookupByLibrary.simpleMessage("Tout effacer"),
    "clearAllConfirmMsg": MessageLookupByLibrary.simpleMessage(
      "Êtes-vous sûr de vouloir effacer tous les enregistrements USSD? Cette action ne peut pas être annulée.",
    ),
    "clearAllRecords": MessageLookupByLibrary.simpleMessage(
      "Effacer tous les enregistrements",
    ),
    "clearReasonFilter": MessageLookupByLibrary.simpleMessage(
      "Effacer le filtre de raison",
    ),
    "close": MessageLookupByLibrary.simpleMessage("Fermer"),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirmer"),
    "confirmTransactionComplete": MessageLookupByLibrary.simpleMessage(
      "Confirmer que cette transaction a été complétée",
    ),
    "contact": MessageLookupByLibrary.simpleMessage("Contact"),
    "contactLoaded": m1,
    "contactNameOptional": MessageLookupByLibrary.simpleMessage(
      "Nom du contact (optionnel)",
    ),
    "contactPermissionDenied": MessageLookupByLibrary.simpleMessage(
      "Permission de contact refusée",
    ),
    "continueAction": MessageLookupByLibrary.simpleMessage("Continuer"),
    "createQrCodeDesc": MessageLookupByLibrary.simpleMessage(
      "Créez un QR code pour que quelqu\'un vous paie",
    ),
    "daily": MessageLookupByLibrary.simpleMessage("Quotidien"),
    "darkTheme": MessageLookupByLibrary.simpleMessage("Thème sombre"),
    "darkThemeDesc": MessageLookupByLibrary.simpleMessage(
      "Agréable pour les yeux",
    ),
    "dateLabel": MessageLookupByLibrary.simpleMessage("Date"),
    "dateRange": MessageLookupByLibrary.simpleMessage("Plage"),
    "defaultLocation": MessageLookupByLibrary.simpleMessage(
      "Emplacement par défaut",
    ),
    "delete": MessageLookupByLibrary.simpleMessage("Supprimer"),
    "deleteBackupMessage": MessageLookupByLibrary.simpleMessage(
      "Êtes-vous sûr de vouloir supprimer cette sauvegarde?",
    ),
    "deleteBackupTitle": MessageLookupByLibrary.simpleMessage(
      "Supprimer la sauvegarde?",
    ),
    "deleteFailedOrDuplicate": MessageLookupByLibrary.simpleMessage(
      "Supprimer une transaction échouée ou dupliquée",
    ),
    "deletePaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Supprimer la méthode de paiement",
    ),
    "dial": MessageLookupByLibrary.simpleMessage("Composer"),
    "dialUssdCode": MessageLookupByLibrary.simpleMessage(
      "Composer ce code USSD :",
    ),
    "edit": MessageLookupByLibrary.simpleMessage("Modifier"),
    "editPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Modifier la méthode de paiement",
    ),
    "editTransaction": MessageLookupByLibrary.simpleMessage(
      "Modifier la transaction",
    ),
    "enableAutoBackup": MessageLookupByLibrary.simpleMessage(
      "Activer la sauvegarde automatique",
    ),
    "endDate": MessageLookupByLibrary.simpleMessage("Date de fin"),
    "enterAmount": MessageLookupByLibrary.simpleMessage("Entrez le montant"),
    "enterManually": MessageLookupByLibrary.simpleMessage(
      "Entrer manuellement",
    ),
    "enterNameForContact": MessageLookupByLibrary.simpleMessage(
      "Entrez le nom de ce contact",
    ),
    "enterPaymentNumber": MessageLookupByLibrary.simpleMessage(
      "Entrer le numéro de paiement",
    ),
    "enterPhoneOrMomoDesc": MessageLookupByLibrary.simpleMessage(
      "Entrez le numéro de téléphone ou le code momo pour recevoir un paiement",
    ),
    "enterPhoneOrMomoHint": MessageLookupByLibrary.simpleMessage(
      "Entrez le numéro de téléphone ou le code momo",
    ),
    "enterValidMinAmount": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer un montant valide (minimum 1 RWF)",
    ),
    "enterValidPhoneOrMomo": MessageLookupByLibrary.simpleMessage(
      "Entrez un numéro de téléphone ou code momo valide",
    ),
    "enterValidPhoneOrMomoMsg": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer un numéro de téléphone valide (078xxxxxxx) ou un code momo",
    ),
    "error": MessageLookupByLibrary.simpleMessage("Erreur"),
    "excelExportedSuccess": MessageLookupByLibrary.simpleMessage(
      "Fichier Excel exporté avec succès!",
    ),
    "exportBackup": MessageLookupByLibrary.simpleMessage(
      "Exporter la sauvegarde",
    ),
    "exportToExcel": MessageLookupByLibrary.simpleMessage(
      "Exporter vers Excel",
    ),
    "exportingBackup": MessageLookupByLibrary.simpleMessage(
      "Exportation de la sauvegarde...",
    ),
    "exportingToExcel": MessageLookupByLibrary.simpleMessage(
      "Exportation vers Excel...",
    ),
    "feeLabel": m2,
    "feeTrackingEnabled": MessageLookupByLibrary.simpleMessage(
      "Suivi des frais activé (aucun frais calculé pour ce type)",
    ),
    "feeWillBeAdded": MessageLookupByLibrary.simpleMessage(
      "Les frais seront ajoutés au total",
    ),
    "fees": MessageLookupByLibrary.simpleMessage("frais"),
    "feesExcludedFromTotals": MessageLookupByLibrary.simpleMessage(
      "Frais Exclus de Tous les Totaux",
    ),
    "feesIncludedInTotals": MessageLookupByLibrary.simpleMessage(
      "Frais Inclus dans Tous les Totaux",
    ),
    "filtersLabel": MessageLookupByLibrary.simpleMessage("Filtres"),
    "general": MessageLookupByLibrary.simpleMessage("Général"),
    "generate": MessageLookupByLibrary.simpleMessage("Générer"),
    "generatePaymentQr": MessageLookupByLibrary.simpleMessage(
      "Générer un QR de paiement",
    ),
    "generateQrCode": MessageLookupByLibrary.simpleMessage(
      "Générer le QR Code",
    ),
    "generateQrHint": MessageLookupByLibrary.simpleMessage(
      "Entrez le montant que vous souhaitez recevoir, puis générez un QR code à montrer au payeur",
    ),
    "getPaid": MessageLookupByLibrary.simpleMessage("Se faire payer"),
    "gotIt": MessageLookupByLibrary.simpleMessage("Compris"),
    "howMuchSend": MessageLookupByLibrary.simpleMessage(
      "Combien voulez-vous envoyer?",
    ),
    "importBackup": MessageLookupByLibrary.simpleMessage(
      "Importer la sauvegarde",
    ),
    "importBackupTitle": MessageLookupByLibrary.simpleMessage(
      "Importer la sauvegarde",
    ),
    "importBackupWarning": MessageLookupByLibrary.simpleMessage(
      "L\'importation d\'une sauvegarde remplacera toutes vos données actuelles, y compris les transactions, les méthodes de paiement et les paramètres. Cette action ne peut pas être annulée.\n\nVoulez-vous continuer?",
    ),
    "importingBackup": MessageLookupByLibrary.simpleMessage(
      "Importation de la sauvegarde...",
    ),
    "invalidAmount": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer un montant valide.",
    ),
    "invalidContactPhone": MessageLookupByLibrary.simpleMessage(
      "Le contact sélectionné a un numéro invalide. Veuillez sélectionner un contact avec un numéro rwandais valide.",
    ),
    "invalidPhoneNumber": MessageLookupByLibrary.simpleMessage(
      "Numéro de téléphone invalide",
    ),
    "invalidPhoneOrMomo": MessageLookupByLibrary.simpleMessage(
      "Numéro de téléphone ou code momo invalide",
    ),
    "invalidTransactionDeleted": MessageLookupByLibrary.simpleMessage(
      "Transaction invalide supprimée avec succès",
    ),
    "invalidUssdCode": MessageLookupByLibrary.simpleMessage(
      "Code USSD invalide",
    ),
    "languagePreferences": MessageLookupByLibrary.simpleMessage(
      "Préférences de langue",
    ),
    "launchError": MessageLookupByLibrary.simpleMessage(
      "Impossible de lancer le code USSD",
    ),
    "lightTheme": MessageLookupByLibrary.simpleMessage("Thème clair"),
    "lightThemeDesc": MessageLookupByLibrary.simpleMessage(
      "Interface lumineuse et propre",
    ),
    "loadFromContacts": MessageLookupByLibrary.simpleMessage(
      "Charger à partir des contacts",
    ),
    "loadingBackups": MessageLookupByLibrary.simpleMessage(
      "Chargement des sauvegardes...",
    ),
    "makeSamePaymentAgain": MessageLookupByLibrary.simpleMessage(
      "Refaire le même paiement",
    ),
    "markFailed": MessageLookupByLibrary.simpleMessage("Marquer comme échoué"),
    "markInvalid": MessageLookupByLibrary.simpleMessage(
      "Marquer comme invalide",
    ),
    "markSuccessful": MessageLookupByLibrary.simpleMessage(
      "Marquer comme réussi",
    ),
    "misc": MessageLookupByLibrary.simpleMessage("Divers"),
    "moCode": MessageLookupByLibrary.simpleMessage("MoCode"),
    "mobileNumber": MessageLookupByLibrary.simpleMessage("Numéro de mobile"),
    "modifyTransactionDetails": MessageLookupByLibrary.simpleMessage(
      "Modifier les détails de la transaction",
    ),
    "momoCode": MessageLookupByLibrary.simpleMessage("Code Momo"),
    "momoCodeHint": MessageLookupByLibrary.simpleMessage("Entrez le code momo"),
    "momoCodeLabel": m3,
    "momoFormatDetected": MessageLookupByLibrary.simpleMessage(
      "Format de code momo détecté",
    ),
    "momoPayment": MessageLookupByLibrary.simpleMessage("Paiement Momo"),
    "monthly": MessageLookupByLibrary.simpleMessage("Mensuel"),
    "mtnMomo": MessageLookupByLibrary.simpleMessage("MTN MoMo"),
    "next": MessageLookupByLibrary.simpleMessage("Suivant"),
    "noAutoBackupsFound": MessageLookupByLibrary.simpleMessage(
      "Aucune sauvegarde automatique trouvée",
    ),
    "noBackupsFound": MessageLookupByLibrary.simpleMessage(
      "Aucune sauvegarde trouvée",
    ),
    "noBackupsYet": MessageLookupByLibrary.simpleMessage(
      "Aucune sauvegarde pour l\'instant",
    ),
    "noFeeApplied": MessageLookupByLibrary.simpleMessage(
      "Aucun frais ne sera appliqué",
    ),
    "noFeeTracked": MessageLookupByLibrary.simpleMessage(
      "Aucun frais ne sera suivi",
    ),
    "noFilterTransactions": m4,
    "noPaymentMethods": MessageLookupByLibrary.simpleMessage(
      "Aucune méthode de paiement configurée. Ajoutez votre première méthode ci-dessous.",
    ),
    "noReasonsFound": MessageLookupByLibrary.simpleMessage(
      "Aucune raison trouvée",
    ),
    "noRecordsFound": MessageLookupByLibrary.simpleMessage(
      "Aucun enregistrement trouvé",
    ),
    "noResultsFor": m5,
    "notEnabled": MessageLookupByLibrary.simpleMessage("Non activé"),
    "ok": MessageLookupByLibrary.simpleMessage("OK"),
    "openAccessibilitySettings": MessageLookupByLibrary.simpleMessage(
      "Ouvrir les paramètres d\'accessibilité",
    ),
    "optionalSidePaymentsHint": MessageLookupByLibrary.simpleMessage(
      "Optionnel - laisser vide pour les paiements annexes",
    ),
    "optionalTransactionNote": MessageLookupByLibrary.simpleMessage(
      "Note optionnelle sur cette transaction",
    ),
    "overallTotal": MessageLookupByLibrary.simpleMessage("Total Général"),
    "payNow": MessageLookupByLibrary.simpleMessage("Payer"),
    "payerScanQuick": MessageLookupByLibrary.simpleMessage(
      "Le payeur peut scanner ce code pour vous payer rapidement le montant exact",
    ),
    "payerScanWithNumber": MessageLookupByLibrary.simpleMessage(
      "Le payeur peut scanner ce code pour vous payer le montant exact au numéro spécifié",
    ),
    "paymentDetails": MessageLookupByLibrary.simpleMessage(
      "Détails du paiement",
    ),
    "paymentMethods": MessageLookupByLibrary.simpleMessage(
      "Méthodes de paiement",
    ),
    "paymentMethodsDesc": MessageLookupByLibrary.simpleMessage(
      "Gérez vos numéros de mobile et vos options de paiement",
    ),
    "paymentRecordSaved": MessageLookupByLibrary.simpleMessage(
      "Enregistrement de paiement sauvegardé avec succès!",
    ),
    "paymentRequestQR": MessageLookupByLibrary.simpleMessage(
      "QR de demande de paiement",
    ),
    "phoneFilter": MessageLookupByLibrary.simpleMessage("Téléphone"),
    "phoneFormatDetected": MessageLookupByLibrary.simpleMessage(
      "Format de numéro de téléphone détecté",
    ),
    "phoneLabel": m6,
    "phoneNumberHint": MessageLookupByLibrary.simpleMessage("078xxxxxxx"),
    "phoneNumberLabel": MessageLookupByLibrary.simpleMessage(
      "Numéro de téléphone",
    ),
    "phoneOrMomo": MessageLookupByLibrary.simpleMessage(
      "Numéro de téléphone ou code Momo",
    ),
    "phoneOrMomoExample": MessageLookupByLibrary.simpleMessage(
      "Téléphone: 078xxxxxxx ou Momo: 123456",
    ),
    "phoneOrMomoOptional": MessageLookupByLibrary.simpleMessage(
      "Numéro de téléphone ou code Momo (optionnel)",
    ),
    "phonePayment": MessageLookupByLibrary.simpleMessage(
      "Paiement par téléphone",
    ),
    "pleaseEnterValidAmount": MessageLookupByLibrary.simpleMessage(
      "Veuillez d\'abord entrer un montant valide",
    ),
    "pleaseEnterValidMomo": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer un code momo valide",
    ),
    "pleaseEnterValidPhone": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer un numéro de téléphone valide",
    ),
    "pleaseEnterValidValue": MessageLookupByLibrary.simpleMessage(
      "Veuillez entrer une valeur valide",
    ),
    "pleaseRestartApp": MessageLookupByLibrary.simpleMessage(
      "Veuillez redémarrer l\'application pour voir tous les changements.",
    ),
    "positionQrCode": MessageLookupByLibrary.simpleMessage(
      "Positionnez le QR code dans le cadre pour scanner",
    ),
    "privacy": MessageLookupByLibrary.simpleMessage("Confidentialité"),
    "probablyInvalidNumber": MessageLookupByLibrary.simpleMessage(
      "Numéro probablement invalide",
    ),
    "probablyMomoCode": MessageLookupByLibrary.simpleMessage(
      "Probablement un code momo",
    ),
    "proceed": MessageLookupByLibrary.simpleMessage("Procéder"),
    "providerLabel": MessageLookupByLibrary.simpleMessage("Fournisseur"),
    "quickPayment": MessageLookupByLibrary.simpleMessage("Paiement Rapide"),
    "reasonHint": MessageLookupByLibrary.simpleMessage(
      "Pourquoi envoyez-vous cet argent?",
    ),
    "reasonLabel": MessageLookupByLibrary.simpleMessage("Raison"),
    "reasonOptional": MessageLookupByLibrary.simpleMessage(
      "Raison (optionnel)",
    ),
    "recipientInfo": MessageLookupByLibrary.simpleMessage(
      "Informations du destinataire",
    ),
    "recipientLabel": m7,
    "recipientName": MessageLookupByLibrary.simpleMessage(
      "Nom du destinataire (optionnel)",
    ),
    "recipientNameHint": MessageLookupByLibrary.simpleMessage(
      "Entrez le nom du destinataire",
    ),
    "recordOnly": MessageLookupByLibrary.simpleMessage("Enregistre seulement"),
    "recordOnlyExplain": MessageLookupByLibrary.simpleMessage(
      "Lorsqu\'activé, les transactions sont sauvegardées comme enregistrements sans exécuter le paiement. Ceci est utile pour suivre les paiements annexes ou les transactions gérées manuellement.",
    ),
    "recordOnlyMode": MessageLookupByLibrary.simpleMessage(
      "Mode enregistrement uniquement",
    ),
    "redial": MessageLookupByLibrary.simpleMessage("Recomposer"),
    "redialTransaction": MessageLookupByLibrary.simpleMessage(
      "Recomposer la transaction",
    ),
    "refresh": MessageLookupByLibrary.simpleMessage("Actualiser"),
    "refreshStatus": MessageLookupByLibrary.simpleMessage(
      "Actualiser le statut",
    ),
    "reset": MessageLookupByLibrary.simpleMessage("Réinitialiser"),
    "restore": MessageLookupByLibrary.simpleMessage("Restaurer"),
    "restoreBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Cela fusionnera les données de sauvegarde avec vos données actuelles. Les doublons seront automatiquement ignorés.\n\nVoulez-vous continuer?",
    ),
    "restoreBackupTitle": MessageLookupByLibrary.simpleMessage(
      "Restaurer la sauvegarde?",
    ),
    "restoreFailedTitle": MessageLookupByLibrary.simpleMessage(
      "Échec de la restauration",
    ),
    "restoredSuccess": MessageLookupByLibrary.simpleMessage(
      "Restauré avec succès!",
    ),
    "restoringBackup": MessageLookupByLibrary.simpleMessage(
      "Restauration de la sauvegarde...",
    ),
    "restoringFromSupabase": MessageLookupByLibrary.simpleMessage(
      "Restauration depuis Supabase...",
    ),
    "save": MessageLookupByLibrary.simpleMessage("Enregistrer"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "Enregistrer les modifications",
    ),
    "savePaymentRecord": MessageLookupByLibrary.simpleMessage(
      "Enregistrer le paiement",
    ),
    "saveRecord": MessageLookupByLibrary.simpleMessage("Enregistrer"),
    "scanNow": MessageLookupByLibrary.simpleMessage("Scanner maintenant"),
    "scanQrCode": MessageLookupByLibrary.simpleMessage("Scanner le QR Code"),
    "scannedResult": m8,
    "searchHint": MessageLookupByLibrary.simpleMessage(
      "Rechercher par nom, numéro, montant, raison...",
    ),
    "searchReasons": MessageLookupByLibrary.simpleMessage(
      "Rechercher des raisons...",
    ),
    "seeFullUssdCode": MessageLookupByLibrary.simpleMessage(
      "Voir le code USSD complet utilisé",
    ),
    "selectLanguage": MessageLookupByLibrary.simpleMessage("Choisir la langue"),
    "selectPaymentMethod": MessageLookupByLibrary.simpleMessage(
      "Sélectionner la méthode de paiement",
    ),
    "sendMoney": MessageLookupByLibrary.simpleMessage("Envoyer"),
    "setAsDefault": MessageLookupByLibrary.simpleMessage("Définir par défaut"),
    "settings": MessageLookupByLibrary.simpleMessage("Paramètres"),
    "settingsSubtitle": MessageLookupByLibrary.simpleMessage(
      "Configurez vos préférences de paiement",
    ),
    "shortDesc": MessageLookupByLibrary.simpleMessage(
      "Rendez vos paiements faciles et rapides!",
    ),
    "showQrToReceive": MessageLookupByLibrary.simpleMessage(
      "Montrez ce QR code pour recevoir un paiement",
    ),
    "sidePayment": MessageLookupByLibrary.simpleMessage("Paiement annexe"),
    "sidePayments": MessageLookupByLibrary.simpleMessage("Paiements Annexes"),
    "singleDate": MessageLookupByLibrary.simpleMessage("Unique"),
    "startDate": MessageLookupByLibrary.simpleMessage("Date de début"),
    "stepOf": m9,
    "stepsToEnable": MessageLookupByLibrary.simpleMessage(
      "Étapes pour activer :\n1. Trouvez \"MQ Pay\" dans la liste\n2. Activez l\'interrupteur\n3. Accordez la permission",
    ),
    "suggestions": MessageLookupByLibrary.simpleMessage("Suggestions"),
    "supabaseBackups": MessageLookupByLibrary.simpleMessage(
      "Sauvegardes Supabase",
    ),
    "supabaseCloudBackup": MessageLookupByLibrary.simpleMessage(
      "Sauvegarde cloud Supabase",
    ),
    "supabaseNotConfigured": MessageLookupByLibrary.simpleMessage(
      "Identifiants Supabase non configurés",
    ),
    "support": MessageLookupByLibrary.simpleMessage("Assistance"),
    "syncComplete": MessageLookupByLibrary.simpleMessage(
      "Synchronisation terminée",
    ),
    "syncingDates": MessageLookupByLibrary.simpleMessage(
      "Synchronisation de toutes les dates...",
    ),
    "tapFilterViewAll": MessageLookupByLibrary.simpleMessage(
      "Appuyez à nouveau sur le filtre pour tout afficher",
    ),
    "tapToEnable": MessageLookupByLibrary.simpleMessage(
      "Appuyez ci-dessous pour activer dans les Paramètres",
    ),
    "tariffTypeLabel": m10,
    "themePreferences": MessageLookupByLibrary.simpleMessage(
      "Préférences de thème",
    ),
    "toRecipient": m11,
    "today": MessageLookupByLibrary.simpleMessage("Aujourd\'hui"),
    "total": MessageLookupByLibrary.simpleMessage("Total"),
    "totalFeesPaid": MessageLookupByLibrary.simpleMessage(
      "Total des Frais Payés",
    ),
    "totalLabel": m12,
    "transactionActions": MessageLookupByLibrary.simpleMessage(
      "Actions sur la transaction",
    ),
    "transactionDidNotComplete": MessageLookupByLibrary.simpleMessage(
      "Cette transaction n\'a pas abouti",
    ),
    "transactionMarkedFailed": MessageLookupByLibrary.simpleMessage(
      "Transaction marquée comme échouée",
    ),
    "transactionMarkedSuccessful": MessageLookupByLibrary.simpleMessage(
      "Transaction marquée comme réussie",
    ),
    "transactionPlural": MessageLookupByLibrary.simpleMessage("transactions"),
    "transactionSingular": MessageLookupByLibrary.simpleMessage("transaction"),
    "transactionUpdated": MessageLookupByLibrary.simpleMessage(
      "Transaction mise à jour avec succès",
    ),
    "tryDifferentKeywords": MessageLookupByLibrary.simpleMessage(
      "Essayez des mots-clés différents",
    ),
    "typeDifferentNumber": MessageLookupByLibrary.simpleMessage(
      "Saisir un numéro différent",
    ),
    "typeLabel": MessageLookupByLibrary.simpleMessage("Type"),
    "typeNamePhoneOrMomoHint": MessageLookupByLibrary.simpleMessage(
      "Saisir un nom, téléphone ou code momo",
    ),
    "typeSidePayment": MessageLookupByLibrary.simpleMessage(
      "Type: Paiement annexe",
    ),
    "update": MessageLookupByLibrary.simpleMessage("Mettre à jour"),
    "uploadBackup": MessageLookupByLibrary.simpleMessage(
      "Télécharger la sauvegarde",
    ),
    "uploadingToSupabase": MessageLookupByLibrary.simpleMessage(
      "Téléchargement vers Supabase...",
    ),
    "useThisNumber": MessageLookupByLibrary.simpleMessage("Utiliser ce numéro"),
    "ussdAutoDetection": MessageLookupByLibrary.simpleMessage(
      "Détection automatique USSD",
    ),
    "ussdAutoDetectionDesc": MessageLookupByLibrary.simpleMessage(
      "Active la détection automatique des réponses aux transactions USSD. Seules les transactions réussies seront sauvegardées.",
    ),
    "ussdCode": MessageLookupByLibrary.simpleMessage("Code USSD"),
    "ussdCodeCopied": MessageLookupByLibrary.simpleMessage("Code USSD copié!"),
    "ussdDetectionActive": MessageLookupByLibrary.simpleMessage(
      "La détection USSD est active. Les transactions seront auto-validées.",
    ),
    "ussdRecordsTitle": MessageLookupByLibrary.simpleMessage("Historique USSD"),
    "validMomoDetected": MessageLookupByLibrary.simpleMessage(
      "Code momo valide détecté",
    ),
    "validPhoneDetected": MessageLookupByLibrary.simpleMessage(
      "Numéro de téléphone valide détecté",
    ),
    "viaContact": MessageLookupByLibrary.simpleMessage("via Contacts"),
    "viaScan": MessageLookupByLibrary.simpleMessage("via Scan"),
    "viewBackups": MessageLookupByLibrary.simpleMessage("Voir les sauvegardes"),
    "viewRestoreBackups": MessageLookupByLibrary.simpleMessage(
      "Voir et restaurer les sauvegardes",
    ),
    "viewUssdCode": MessageLookupByLibrary.simpleMessage("Voir le code USSD"),
    "weekly": MessageLookupByLibrary.simpleMessage("Hebdomadaire"),
    "welcomeHere": MessageLookupByLibrary.simpleMessage("Bienvenue ici"),
    "whichNumberReceive": MessageLookupByLibrary.simpleMessage(
      "Quel numéro doit recevoir le paiement?",
    ),
    "yesterday": MessageLookupByLibrary.simpleMessage("Hier"),
  };
}
