import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

/// Reverse marketplace: dealer posts what they need, farmers respond.
class RequirementsScreen extends StatelessWidget {
  const RequirementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    return Column(
      children: [
        _Bar(onPost: () => _postSheet(context, store)),
        Expanded(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              if (store.requirements.isEmpty) {
                return EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No open requirements',
                  body: 'Post what you need and matching farmers get alerted instantly.',
                  action: AppButton.primary('Post a requirement',
                      onPressed: () => _postSheet(context, store)),
                );
              }
              return ListView(
                padding: EdgeInsets.only(
                    bottom: 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  const SectionHeader(
                    title: 'Your buy requirements',
                    subtitle: 'Open requests farmers can respond to',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
                    child: Column(
                      children: [
                        for (var i = 0; i < store.requirements.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                                bottom: i == store.requirements.length - 1
                                    ? 0
                                    : Insets.s3),
                            child: Reveal(
                              delay: Duration(milliseconds: i * 55),
                              child: _RequirementCard(store.requirements[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _postSheet(BuildContext context, AppStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x731C2117),
      builder: (_) => const _PostRequirementSheet(),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.onPost});
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(Insets.s4, top + 14, Insets.s4, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text('Requirements',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onPrimary)),
          ),
          Tappable(
            onTap: onPost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.onPrimary,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: AppColors.primaryPress),
                  SizedBox(width: 4),
                  Text('Post',
                      style: TextStyle(
                          color: AppColors.primaryPress,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostRequirementSheet extends StatefulWidget {
  const _PostRequirementSheet();
  @override
  State<_PostRequirementSheet> createState() => _PostRequirementSheetState();
}

class _PostRequirementSheetState extends State<_PostRequirementSheet> {
  Crop? _crop;
  Unit _unit = Unit.ton;
  final _qty = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _days = TextEditingController(text: '7');

  @override
  void initState() {
    super.initState();
    for (final c in [_qty, _min, _max, _days]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_qty, _min, _max, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _crop != null &&
      (double.tryParse(_qty.text) ?? 0) > 0 &&
      (int.tryParse(_min.text) ?? 0) > 0 &&
      (int.tryParse(_max.text) ?? 0) >= (int.tryParse(_min.text) ?? 0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Insets.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Post a buy requirement',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: Insets.s4),
                const Text('Crop',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: Insets.s2),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in context.store.crops)
                        Padding(
                          padding: const EdgeInsets.only(right: Insets.s2),
                          child: ChoiceChip(
                            label: Text('${c.emoji} ${c.name}'),
                            selected: _crop?.name == c.name,
                            onSelected: (_) => setState(() => _crop = c),
                            selectedColor: AppColors.primaryTint,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _crop?.name == c.name
                                  ? AppColors.primaryPress
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.s4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(labelText: 'Quantity'),
                      ),
                    ),
                    const SizedBox(width: Insets.s3),
                    _unitDrop(),
                  ],
                ),
                const SizedBox(height: Insets.s4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _min,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Min ₹/qtl'),
                      ),
                    ),
                    const SizedBox(width: Insets.s3),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Max ₹/qtl'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.s4),
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Needed in (days)'),
                ),
                const SizedBox(height: Insets.s5),
                AppButton.primary(_busy ? 'Posting…' : 'Post requirement',
                    onPressed: (_valid && !_busy) ? _submit : null),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unitDrop() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.s3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: AppColors.line, width: 1.4),
      ),
      child: DropdownButton<Unit>(
        value: _unit,
        underline: const SizedBox.shrink(),
        items: [
          for (final u in Unit.values)
            DropdownMenuItem(value: u, child: Text(u.label)),
        ],
        onChanged: (v) => setState(() => _unit = v ?? _unit),
      ),
    );
  }

  bool _busy = false;

  Future<void> _submit() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.store.postRequirement(
        crop: _crop!,
        qty: double.parse(_qty.text),
        unit: _unit,
        priceMin: int.parse(_min.text),
        priceMax: int.parse(_max.text),
        neededInDays: int.tryParse(_days.text) ?? 7,
      );
      nav.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Requirement posted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not post: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ));
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard(this.r);
  final BuyRequirement r;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Insets.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(r.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: Insets.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.crop,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${_qty(r.qty)} ${r.unit.label} · ${r.location}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              Pill(
                label: '${r.responses} responses',
                icon: Icons.people_alt_outlined,
                fg: AppColors.primaryPress,
                bg: AppColors.primaryTint,
              ),
              IconButton(
                tooltip: 'Delete requirement',
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.danger),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          const Divider(height: Insets.s5),
          Row(
            children: [
              _stat('Price range', '${inr(r.priceMin)}–${inr(r.priceMax)}'),
              const SizedBox(width: Insets.s5),
              _stat('Needed in', '${r.neededInDays} days'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: const Text('Delete this requirement?'),
        content: const Text('Farmers will no longer see it. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.store.deleteRequirement(r);
      messenger.showSnackBar(const SnackBar(
        content: Text('Requirement deleted'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not delete: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Widget _stat(String k, String v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text(v,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
      ],
    );
  }

  static String _qty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}
