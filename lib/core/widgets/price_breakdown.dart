import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../services/pricing_service.dart';
import '../utils/formatters.dart';

IconData _lineIcon(PriceLineKind k) => switch (k) {
      PriceLineKind.base => Icons.calendar_today_rounded,
      PriceLineKind.season => Icons.wb_sunny_rounded,
      PriceLineKind.weekend => Icons.weekend_rounded,
      PriceLineKind.discount => Icons.savings_rounded,
    };

Color _lineColor(BuildContext context, PriceLine l) => switch (l.kind) {
      PriceLineKind.base => context.palette.muted,
      PriceLineKind.season => AppColors.warning,
      PriceLineKind.weekend => l.amount < 0 ? AppColors.success : AppColors.violet,
      PriceLineKind.discount => AppColors.success,
    };

/// Detailed price of a rental: base rate, high season, weekend, long-stay
/// discount and total (rental form and pricing simulator).
class PriceBreakdown extends StatelessWidget {
  final PriceQuote quote;
  const PriceBreakdown({super.key, required this.quote});

  @override
  Widget build(BuildContext context) {
    final lines = quote.lines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(_lineIcon(l.kind), size: 18, color: _lineColor(context, l)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.label, style: context.text.bodyMedium),
                    Text(l.detail, style: context.text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l.kind == PriceLineKind.base
                    ? formatMoney(l.amount)
                    : '${l.amount < 0 ? '−' : '+'} ${formatMoney(l.amount.abs())}',
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: l.kind == PriceLineKind.base
                      ? null
                      : _lineColor(context, l),
                ),
              ),
            ]),
          ),
        Divider(height: 18, color: context.palette.border),
        Row(children: [
          Expanded(child: Text('Total', style: context.text.titleMedium)),
          Text(formatMoney(quote.total),
              style: context.text.titleMedium
                  ?.copyWith(color: AppColors.brand)),
        ]),
        if (quote.isAdjusted)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Soit ${formatMoney(quote.averageDailyRate)} par jour en moyenne'
              '${quote.total < quote.baseTotal ? ' · économie de ${formatMoney(quote.baseTotal - quote.total)}' : ''}',
              textAlign: TextAlign.right,
              style: context.text.bodySmall,
            ),
          ),
      ],
    );
  }
}
