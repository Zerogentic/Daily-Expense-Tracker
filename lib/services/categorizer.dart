import '../models.dart';

/// Picks a category from the merchant and message text. Categories the user
/// picks by hand are saved as rules and always win next time.
class Categorizer {
  static const Map<String, List<String>> _keywords = {
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
  }) {
    final m = merchant.toLowerCase().trim();
    if (m.isNotEmpty && rules.containsKey(m)) return rules[m]!;
    final hay = '$m ${text.toLowerCase()}';

    if (type == TxnType.credit) {
      if (hay.contains('salary') || hay.contains('sal ') || hay.contains('payroll')) return 'salary';
      if (hay.contains('refund') || hay.contains('cashback') || hay.contains('reversed') || hay.contains('reversal')) {
        return 'refund';
      }
      return 'income';
    }

    for (final e in _patterns.entries) {
      if (e.value.any((re) => re.hasMatch(hay))) return e.key;
    }
    return 'other';
  }
}
