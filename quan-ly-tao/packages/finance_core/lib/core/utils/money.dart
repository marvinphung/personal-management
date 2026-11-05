class Money {
  static const maxMinor = 9000000000000000;
  static const exponents = {'VND': 0, 'USD': 2, 'EUR': 2, 'GBP': 2, 'JPY': 0};
  static int parse(
    String input, {
    String currency = 'VND',
    bool allowZero = false,
  }) {
    final exponent = exponents[currency];
    if (exponent == null) throw const FormatException('Unsupported currency');
    final match = RegExp(
      r'^(\d+)(?:\.(\d+))?([kKmM]?)$',
    ).firstMatch(input.trim());
    if (match == null) {
      throw const FormatException('Enter an amount such as 45000, 45k or 1.5m');
    }
    final fraction = match[2] ?? '';
    final multiplier = switch (match[3]!.toLowerCase()) {
      'k' => 1000,
      'm' => 1000000,
      _ => 1,
    };
    final numerator =
        BigInt.parse('${match[1]}$fraction') *
        BigInt.from(multiplier) *
        BigInt.from(10).pow(exponent);
    final divisor = BigInt.from(10).pow(fraction.length);
    if (numerator % divisor != BigInt.zero) {
      throw const FormatException('Too many decimal places for this currency');
    }
    final value = numerator ~/ divisor;
    if (value < BigInt.zero ||
        (!allowZero && value == BigInt.zero) ||
        value > BigInt.from(maxMinor)) {
      throw const FormatException(
        'Amount must be positive and within the supported limit',
      );
    }
    return value.toInt();
  }

  static int parseBalance(String input, {String currency = 'VND'}) {
    final text = input.trim();
    final negative = text.startsWith('-');
    final amount = parse(
      negative ? text.substring(1) : text,
      currency: currency,
      allowZero: true,
    );
    return negative ? -amount : amount;
  }

  static String input(int minor, String currency) {
    final exponent = exponents[currency] ?? 0;
    if (exponent == 0) return minor.toString();
    final digits = minor.abs().toString().padLeft(exponent + 1, '0');
    return '${minor < 0 ? '-' : ''}${digits.substring(0, digits.length - exponent)}.${digits.substring(digits.length - exponent)}';
  }

  static String format(int minor, [String currency = 'VND']) {
    final parts = input(minor, currency).split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$grouped${parts.length > 1 ? '.${parts[1]}' : ''} ${currency == 'VND' ? '₫' : currency}';
  }
}
