/// The built-in detection pack — everything the app used to hardcode.
///
/// It is a JSON string rather than Dart objects on purpose: this is the exact
/// shape an exported rule file or a remote pack uses, so shipping a new bank
/// format later means shipping data, not a release. It is compiled in rather
/// than loaded as an asset so the background WorkManager isolate can read it
/// without touching `rootBundle`.
///
/// Users can't edit these rules, only disable them — the way back to shipped
/// behaviour is always one toggle away.
library;

const int builtinRulePackVersion = 1;

const String builtinRulePackJson = r'''
{
  "version": 1,
  "senders": {
    "mobileMoney": ["m-money", "mmoney", "mtn", "airtel", "ekash"],
    "bank": ["bkebank"]
  },
  "keywords": {
    "success": [
      "*s*",
      "transferred to",
      "was completed",
      "you have transferred",
      "you have sent",
      "successful",
      "congratulations",
      "transaction successful",
      "payment successful",
      "sent to",
      "confirmed.",
      "please keep",
      "has been sent",
      "has been transferred",
      "avez transféré",
      "effectué"
    ],
    "successExclude": ["unsuccessful"],
    "failure": [
      "*r*",
      "failed",
      "transaction declined",
      "not processed",
      "unsuccessful",
      "could not be completed",
      "declined",
      "your request was not",
      "refusé"
    ]
  },
  "rules": [
    {
      "id": "builtin.bank-pull-momo",
      "label": "Bank pull (wallet side)",
      "source": "builtin",
      "priority": 100,
      "direction": "feeOnly",
      "mustContain": ["you have received", "fund-transfer"],
      "anyOf": ["ft id", "financial transaction id"],
      "builtinParser": "bankPullMoMo",
      "serviceKey": "bk-pull"
    },
    {
      "id": "builtin.bank-pull-bank",
      "label": "Bank pull / eKash transfer (bank side)",
      "source": "builtin",
      "priority": 100,
      "direction": "feeOnly",
      "mustContain": [
        "transfer",
        "ekash",
        "credited account",
        "debited account",
        "completed"
      ],
      "builtinParser": "bankPullBank",
      "serviceKey": "bk-pull"
    },
    {
      "id": "builtin.bk-debit",
      "label": "BK debit alert",
      "source": "builtin",
      "priority": 0,
      "direction": "enrichment",
      "mustContain": ["has been debited"],
      "builtinParser": "bankDebit",
      "serviceKey": "bk"
    },
    {
      "id": "builtin.efashe",
      "priority": 10,
      "label": "Cash Power token (eFashe)",
      "source": "builtin",
      "direction": "enrichment",
      "senderMatch": ["efashe"],
      "mustContain": ["meter#", "token"],
      "serviceKey": "efashe",
      "requiredFields": ["token"],
      "detailsTemplate": "Token: {token} · Units: {units} KWh · Meter: {meter}",
      "fields": [
        {"name": "token", "type": "ref", "pattern": "Token\\s*:\\s*(\\S+)"},
        {"name": "units", "type": "decimal", "pattern": "Units\\s*:\\s*([\\d.]+)\\s*KW"},
        {"name": "meter", "type": "ref", "pattern": "Meter#\\s*:\\s*(\\S+)"},
        {"name": "amount", "type": "amount", "pattern": "Amount\\s*:\\s*([\\d.]+)"}
      ]
    },
    {
      "id": "builtin.canalbox",
      "priority": 10,
      "label": "Canalbox renewal",
      "source": "builtin",
      "direction": "enrichment",
      "senderMatch": ["canalbox"],
      "mustContain": ["canalbox"],
      "serviceKey": "canalbox",
      "detailsTemplate": "Subscription renewed · Valid until {valid}",
      "fields": [
        {"name": "valid", "type": "text", "pattern": "valid until\\s*([\\d\\-/]+)"},
        {"name": "amount", "type": "amount", "pattern": "Amount paid\\s*:?\\s*([\\d,]+)\\s*RWF"}
      ]
    },
    {
      "id": "builtin.umutekano",
      "priority": 10,
      "label": "Umutekano confirmation",
      "source": "builtin",
      "direction": "enrichment",
      "senderMatch": ["umutekano"],
      "mustContain": ["umutekano"],
      "serviceKey": "umutekano",
      "eventKeyField": "trid",
      "detailsTemplate": "Confirmed via Umutekano · TRID {trid}",
      "fields": [
        {"name": "amount", "type": "amount", "pattern": "Umutekano\\s*([\\d,]+)F"},
        {"name": "trid", "type": "ref", "pattern": "TRID\\s+([A-Za-z0-9]+)"}
      ]
    }
  ]
}
''';
