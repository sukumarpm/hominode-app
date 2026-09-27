String normalizePaymentMethod(Object? value) {
  final method = value is String ? value.trim().toLowerCase() : '';
  return switch (method) {
    'upi' => 'UPI',
    'cash' => 'Cash',
    'bank_transfer' => 'Bank Transfer',
    'cheque' => 'Cheque',
    'manual' => 'Manual',
    'external' => 'External',
    '' => 'Not recorded',
    _ =>
      method
          .replaceAll(RegExp(r'[_-]+'), ' ')
          .split(' ')
          .map(
            (part) => part.isEmpty
                ? part
                : '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' '),
  };
}

String normalizePaymentProvider(Object? value) {
  final provider = value is String ? value.trim().toLowerCase() : '';
  if (provider == 'direct_upi') return 'Direct UPI';
  if (provider.isEmpty) return 'Not specified';
  return provider
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .split(' ')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}
