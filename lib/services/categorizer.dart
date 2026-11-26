import '../models.dart';

/// Picks a category for a transaction, in this order:
/// 1. the category used most often for this payee in past transactions ([history]),
/// 2. a category the user set for the payee with "Update all" ([rules]),
/// 3. keywords in the payee name and message text.
class Categorizer {
  /// Fund houses, clearing houses and brokers, as bank SMS write them.
  /// Money to them is investing; money back from them is a withdrawal, not income.
  static const _investPlatforms = [
    'mutual fund', 'mutual funds', 'mf', 'asset management', 'asset mgmt', 'iccl', 'indian clearing',
    'clearing corp', 'clearing corporation', 'nse clearing', 'nsccl', 'bse limited', 'bse ltd', 'bse star',
    'bsestarmf', 'nse mf', 'nsemf', 'cams', 'camsonline', 'kfintech', 'kfin', 'karvy', 'zerodha', 'groww',
    'nextbillion', 'upstox', 'rksv', 'angel one', 'angel broking', 'kuvera', 'paytm money', 'smallcase',
    'et money', 'etmoney', 'indmoney', 'coin by zerodha', 'securities', 'broking', 'stock broking',
    'share broking', 'capital markets', 'icicidirect', 'motilal oswal', 'sharekhan', '5paisa', 'fyers', 'iifl',
    'geojit', 'nuvama', 'edelweiss', 'moneylicious', 'mirae asset', 'ppfas', 'parag parikh', 'nippon india',
  ];

  static const Map<String, List<String>> _keywords = {
    // Checked first: SIP auto-debits mention the clearing house or fund platform.
    'investments': [
      ..._investPlatforms,
      'sip', 'digital gold', 'safegold', 'augmont', 'sgb', 'sovereign gold', 'stocks', 'demat'
    ],
    'deposits': [
      'fixed deposit', 'recurring deposit', 'term deposit', 'fd booking', 'fd opening', 'rd instalment',
      'rd installment', 'ppf', 'public provident', 'nps', 'national pension', 'sukanya', 'ssy'
    ],
    'food': [
      'swiggy', 'zomato', 'restaurant', 'cafe', 'coffee', 'bakery', 'hotel', 'dominos', 'domino',
      'mcdonald', 'kfc', 'pizza', 'burger', 'starbucks', 'chai', 'biryani', 'eatsure', 'food'
    ],
    'groceries': [
      'bigbasket', 'blinkit', 'zepto', 'instamart', 'dmart', 'supermarket', 'hypermarket',
      'reliance fresh', 'reliance smart', 'more retail', 'grocery', 'grocer', 'jiomart', 'lulu'
    ],
    'transport': ['uber', 'ola', 'rapido', 'metro', 'namma yatri', 'parking', 'fastag', 'toll', 'ksrtc'],
    'fuel': ['petrol', 'fuel', 'hpcl', 'bpcl', 'iocl', 'indian oil', 'bharat petroleum', 'hp petrol', 'shell'],
    'shopping': ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'decathlon', 'croma', 'reliance digital'],
    'bills': [
      'electricity', 'kseb', 'bescom', 'tneb', 'jio', 'airtel', 'bsnl', 'vodafone', 'broadband',
      'recharge', 'dth', 'tata play', 'water bill', 'gas bill', 'indane', 'bharat gas'
    ],
    'rent': ['rent', 'nobroker', 'landlord'],
    'entertainment': [
      'netflix', 'hotstar', 'spotify', 'bookmyshow', 'prime video', 'youtube', 'pvr', 'inox', 'sonyliv',
      'google play', 'play store', 'app store', 'apple.com', 'itunes'
    ],
    'health': ['pharmacy', 'medical', 'apollo', 'hospital', 'clinic', 'pharmeasy', '1mg', 'netmeds', 'diagnostic', 'lab'],
    'travel': ['irctc', 'makemytrip', 'goibibo', 'indigo', 'air india', 'akasa', 'redbus', 'cleartrip', 'oyo', 'ixigo'],
    'education': ['school', 'college', 'university', 'tuition', 'udemy', 'coursera', 'byju', 'fees'],
    'emi': ['emi', 'loan', 'bajaj finance', 'finance ltd'],
    'cash': ['atm', 'cash withdrawal', 'withdrawn'],
  };

  static final Map<String, List<RegExp>> _patterns = {
    for (final e in _keywords.entries)
      e.key: [for (final k in e.value) RegExp('(?<![a-z])${RegExp.escape(k)}(?![a-z])')]
  };

  static String categorize({
    required String merchant,
    required String text,
    required TxnType type,
    Map<String, String> rules = const {},
    Map<String, String> history = const {},
  }) {
    final m = merchant.toLowerCase().trim();
    bool fits(String key) => categoryFor(key).income == (type == TxnType.credit);
    if (m.isNotEmpty) {
      final learned = history[m];
      if (learned != null && fits(learned)) return learned;
      final rule = rules[m];
      if (rule != null && fits(rule)) return rule;
    }
    final hay = '$m ${text.toLowerCase()}';

    if (type == TxnType.credit) {
      if (hay.contains('salary') || hay.contains('sal ') || hay.contains('payroll')) return 'salary';
      // Dividends and interest are returns you earned: income, even from a fund or FD.
      if (RegExp(r'(?<![a-z])(dividend|div pay|interest|int\.? ?pd|int\.? ?paid|int\.? ?cr|int\.? ?credit)',
              caseSensitive: false)
          .hasMatch(hay)) {
        return 'returns';
      }
      if (hay.contains('refund') || hay.contains('cashback') || hay.contains('reversed') || hay.contains('reversal')) {
        return 'refund';
      }
      // Money back from investments or deposits is your own savings returning, not income.
      const withdrawals = [
        'redemption', 'redeemed', 'redeem', 'maturity', 'matured', 'premature closure', 'fd closure', 'fd closed',
        'funds withdrawal', 'fund withdrawal', 'payout', ..._investPlatforms,
      ];
      if (withdrawals.any((w) => RegExp('(?<![a-z])${RegExp.escape(w)}(?![a-z])').hasMatch(hay))) return 'redemption';
      return 'income';
    }

    for (final e in _patterns.entries) {
      if (e.value.any((re) => re.hasMatch(hay))) return e.key;
    }
    return 'other';
  }
}
