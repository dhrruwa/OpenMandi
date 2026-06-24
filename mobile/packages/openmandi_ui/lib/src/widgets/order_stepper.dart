import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/trade.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Vertical lifecycle tracker: offer → accepted → escrow → transit → delivered
/// → completed. Past steps filled, current emphasised, future muted.
class OrderStepper extends StatelessWidget {
  const OrderStepper(this.stage, {super.key});
  final OrderStage stage;

  static const _stages = [
    OrderStage.accepted,
    OrderStage.confirmed,
    OrderStage.inTransit,
    OrderStage.delivered,
    OrderStage.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final d = MediaQuery.of(context).disableAnimations ? Duration.zero : Motion.base;
    return Column(
      children: [
        for (var i = 0; i < _stages.length; i++)
          _row(_stages[i], i, last: i == _stages.length - 1, d: d),
      ],
    );
  }

  Widget _row(OrderStage s, int i, {required bool last, required Duration d}) {
    final done = s.index < stage.index || stage == OrderStage.completed;
    final current = s == stage;
    final reached = s.index <= stage.index;
    final color = reached ? AppColors.primary : AppColors.lineStrong;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: d,
                curve: const Cubic(0.22, 1, 0.36, 1),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: reached ? AppColors.primary : AppColors.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: done
                    ? const Icon(Icons.check, size: 15, color: AppColors.onPrimary)
                    : current
                        ? const Center(
                            child: Icon(Icons.circle, size: 9, color: AppColors.onPrimary))
                        : null,
              ),
              if (!last)
                Expanded(
                  child: AnimatedContainer(
                    duration: d,
                    curve: const Cubic(0.22, 1, 0.36, 1),
                    width: 2,
                    color: s.index < stage.index ? AppColors.primary : AppColors.line,
                  ),
                ),
            ],
          ),
          const SizedBox(width: Insets.s3),
          Padding(
            padding: EdgeInsets.only(top: 3, bottom: last ? 0 : Insets.s4),
            child: Text(
              s.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: reached ? AppColors.ink : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact horizontal progress bar of the order lifecycle (for list rows).
class OrderProgressBar extends StatelessWidget {
  const OrderProgressBar(this.stage, {super.key});
  final OrderStage stage;

  @override
  Widget build(BuildContext context) {
    const total = 5;
    final reached = (stage.index).clamp(1, total);
    final d = MediaQuery.of(context).disableAnimations ? Duration.zero : Motion.base;
    return Row(
      children: [
        for (var i = 1; i <= total; i++)
          Expanded(
            child: AnimatedContainer(
              duration: d,
              curve: const Cubic(0.22, 1, 0.36, 1),
              height: 4,
              margin: EdgeInsets.only(right: i == total ? 0 : 3),
              decoration: BoxDecoration(
                color: i <= reached ? AppColors.primary : AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}
