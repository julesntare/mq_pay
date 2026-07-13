import 'package:flutter/material.dart';

/// Opens a simple calculator bottom sheet and returns the computed amount,
/// or null if the user cancelled.
///
/// Supports + − × ÷ with standard precedence (× ÷ before + −), a live
/// result preview, and a `000` key for quick thousands entry.
Future<double?> showCalculatorSheet(BuildContext context,
    {double? initialValue}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _CalculatorSheet(initialValue: initialValue),
  );
}

class _CalculatorSheet extends StatefulWidget {
  final double? initialValue;

  const _CalculatorSheet({this.initialValue});

  @override
  State<_CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<_CalculatorSheet> {
  /// Expression as tokens: number strings and the operators + − × ÷.
  final List<String> _tokens = [];

  static const _operators = ['+', '−', '×', '÷'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    if (initial != null && initial >= 1) {
      _tokens.add(initial.round().toString());
    }
  }

  bool _isOperator(String t) => _operators.contains(t);

  String? get _lastToken => _tokens.isEmpty ? null : _tokens.last;

  void _pressDigit(String digit) {
    setState(() {
      final last = _lastToken;
      if (last != null && !_isOperator(last)) {
        if (last.replaceAll('.', '').length >= 12) return;
        // Replace a bare leading zero instead of building "05".
        _tokens[_tokens.length - 1] =
            (last == '0' && digit != '000') ? digit : last + digit;
      } else {
        if (digit == '000') return; // no number to extend
        _tokens.add(digit);
      }
    });
  }

  void _pressDecimal() {
    setState(() {
      final last = _lastToken;
      if (last != null && !_isOperator(last)) {
        if (!last.contains('.')) _tokens[_tokens.length - 1] = '$last.';
      } else {
        _tokens.add('0.');
      }
    });
  }

  void _pressOperator(String op) {
    setState(() {
      final last = _lastToken;
      if (last == null) return; // expression must start with a number
      if (_isOperator(last)) {
        _tokens[_tokens.length - 1] = op; // replace pending operator
      } else {
        _tokens.add(op);
      }
    });
  }

  void _pressBackspace() {
    setState(() {
      final last = _lastToken;
      if (last == null) return;
      if (_isOperator(last) || last.length == 1) {
        _tokens.removeLast();
      } else {
        _tokens[_tokens.length - 1] = last.substring(0, last.length - 1);
      }
    });
  }

  void _pressClear() => setState(_tokens.clear);

  void _pressEquals() {
    final result = _evaluate();
    if (result == null) return;
    setState(() {
      _tokens
        ..clear()
        ..add(_trimTrailingZeros(result));
    });
  }

  /// Evaluates the expression with × ÷ before + −.
  /// A trailing operator is ignored. Returns null when empty or on ÷ 0.
  double? _evaluate() {
    final tokens = List<String>.from(_tokens);
    if (tokens.isNotEmpty && _isOperator(tokens.last)) tokens.removeLast();
    if (tokens.isEmpty) return null;

    // Pass 1: collapse × and ÷.
    final collapsed = <String>[tokens.first];
    for (var i = 1; i < tokens.length - 1; i += 2) {
      final op = tokens[i];
      final rhs = double.tryParse(tokens[i + 1]);
      if (rhs == null) return null;
      if (op == '×' || op == '÷') {
        final lhs = double.tryParse(collapsed.removeLast());
        if (lhs == null) return null;
        if (op == '÷' && rhs == 0) return null;
        collapsed.add((op == '×' ? lhs * rhs : lhs / rhs).toString());
      } else {
        collapsed
          ..add(op)
          ..add(tokens[i + 1]);
      }
    }

    // Pass 2: left-to-right + and −.
    final first = double.tryParse(collapsed.first);
    if (first == null) return null;
    var total = first;
    for (var i = 1; i < collapsed.length - 1; i += 2) {
      final rhs = double.tryParse(collapsed[i + 1]);
      if (rhs == null) return null;
      total = collapsed[i] == '+' ? total + rhs : total - rhs;
    }
    return total;
  }

  static String _trimTrailingZeros(double v) {
    var s = v.toStringAsFixed(2);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s.isEmpty ? '0' : s;
  }

  static String _formatNumber(String raw) {
    final parts = raw.split('.');
    final whole = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }

  String get _expressionDisplay => _tokens
      .map((t) => _isOperator(t) ? ' $t ' : _formatNumber(t))
      .join();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _evaluate();
    final canProceed = result != null && result >= 1;
    // Show the preview once there is an actual calculation, not a bare number.
    final showResult = result != null && _tokens.length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Display
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _tokens.isEmpty ? '0' : _expressionDisplay,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    showResult
                        ? '= ${_formatNumber(_trimTrailingZeros(result))} RWF'
                        : ' ',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Keypad
            _buildKeyRow(theme, [
              _key('C', onTap: _pressClear, color: theme.colorScheme.error),
              _key('⌫',
                  onTap: _pressBackspace, color: theme.colorScheme.secondary),
              _key('÷', onTap: () => _pressOperator('÷'), isOperator: true),
              _key('×', onTap: () => _pressOperator('×'), isOperator: true),
            ]),
            _buildKeyRow(theme, [
              _key('7', onTap: () => _pressDigit('7')),
              _key('8', onTap: () => _pressDigit('8')),
              _key('9', onTap: () => _pressDigit('9')),
              _key('−', onTap: () => _pressOperator('−'), isOperator: true),
            ]),
            _buildKeyRow(theme, [
              _key('4', onTap: () => _pressDigit('4')),
              _key('5', onTap: () => _pressDigit('5')),
              _key('6', onTap: () => _pressDigit('6')),
              _key('+', onTap: () => _pressOperator('+'), isOperator: true),
            ]),
            _buildKeyRow(theme, [
              _key('1', onTap: () => _pressDigit('1')),
              _key('2', onTap: () => _pressDigit('2')),
              _key('3', onTap: () => _pressDigit('3')),
              _key('000', onTap: () => _pressDigit('000')),
            ]),
            _buildKeyRow(theme, [
              _key('0', onTap: () => _pressDigit('0'), flex: 2),
              _key('.', onTap: _pressDecimal),
              _key('=', onTap: _pressEquals, isOperator: true),
            ]),
            const SizedBox(height: 12),
            // Cancel / Proceed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.outlined(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 28,
                  tooltip: 'Cancel',
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(
                        color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.all(14),
                  ),
                ),
                IconButton.filled(
                  onPressed: canProceed
                      ? () => Navigator.of(context).pop(result)
                      : null,
                  icon: const Icon(Icons.check_rounded),
                  iconSize: 28,
                  tooltip: 'Use this amount',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.all(14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(ThemeData theme, List<Widget> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: keys),
    );
  }

  Widget _key(
    String label, {
    required VoidCallback onTap,
    bool isOperator = false,
    Color? color,
    int flex = 1,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isOperator
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color ??
                        (isOperator
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
