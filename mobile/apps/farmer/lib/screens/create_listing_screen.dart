import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openmandi_ui/openmandi_ui.dart';

class CreateListingSheet extends StatefulWidget {
  const CreateListingSheet({super.key});

  @override
  State<CreateListingSheet> createState() => _CreateListingSheetState();
}

class _CreateListingSheetState extends State<CreateListingSheet> {
  int _step = 0;
  bool _done = false;

  Crop? _crop;
  final _qty = TextEditingController();
  Unit _unit = Unit.quintal;
  DateTime? _harvest;
  Grade? _grade;
  bool _organic = false;
  final List<Uint8List> _photos = [];
  bool _publishing = false;
  final _picker = ImagePicker();
  final _price = TextEditingController();

  String? _pincode;
  String? _village;
  String? _taluk;
  String? _district;
  String? _state;
  String? _country;
  double? _lat;
  double? _lng;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _qty.addListener(_refresh);
    _price.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Step list is built from the location flag so the Location step is simply
  // absent when location is disabled (re-enable via AppConfig.locationEnabled).
  List<String> get _steps => AppConfig.locationEnabled
      ? const ['Crop', 'Quantity', 'Quality', 'Location', 'Photos', 'Price', 'Review']
      : const ['Crop', 'Quantity', 'Quality', 'Photos', 'Price', 'Review'];

  String get _stepName => _steps[_step];

  int get _market => _crop?.marketPrice ?? 0;
  int get _priceNum => int.tryParse(_price.text) ?? 0;

  String? get _verdict {
    if (_priceNum == 0 || _market == 0) return null;
    final diff = (_priceNum - _market) / _market;
    if (diff > 0.12) return 'high';
    if (diff < -0.08) return 'low';
    return 'fair';
  }

  bool get _canNext => switch (_stepName) {
        'Crop' => _crop != null,
        'Quantity' => (double.tryParse(_qty.text) ?? 0) > 0 && _harvest != null,
        'Quality' => _grade != null,
        'Location' => _pincode != null &&
            _village != null &&
            _taluk != null &&
            _district != null &&
            _state != null &&
            _country != null,
        'Price' => _priceNum > 0,
        _ => true,
      };

  bool get _last => _step == _steps.length - 1;

  void _next() {
    setState(() => _step++);
    _scroll.jumpTo(0);
  }

  Future<void> _pickPhoto() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1280, imageQuality: 82);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _photos.add(bytes));
  }

  Future<void> _publish() async {
    final store = context.store;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _publishing = true);
    final days = _harvest == null
        ? 0
        : _harvest!.difference(DateTime.now()).inDays.clamp(0, 120);
    var urls = <String>[];
    try {
      if (store.live) {
        for (var i = 0; i < _photos.length; i++) {
          final name =
              'listing_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          urls.add(await Backend.I.uploadListingPhoto(name, _photos[i]));
        }
      }
      final (plat, plng) = await store.currentLatLng();
      await store.addListing(
        crop: _crop!,
        qty: double.tryParse(_qty.text) ?? 0,
        unit: _unit,
        grade: _grade!,
        organic: _organic,
        price: _priceNum,
        harvestInDays: days,
        photos: urls,
        lat: _lat ?? plat,
        lng: _lng ?? plng,
        pincode: _pincode,
        village: _village,
        taluk: _taluk,
        district: _district,
        state: _state,
        country: _country,
        locationLabel: _village != null ? '$_village, $_taluk' : null,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        content: Text('Could not publish: $e'),
      ));
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step--);
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _done
            ? _Success(crop: _crop?.name ?? 'produce')
            : Column(
                children: [
                  _header(),
                  _progress(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                          Insets.s4, Insets.s5, Insets.s4, Insets.s5),
                      child: _stepBody(),
                    ),
                  ),
                  _footer(),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(Insets.s3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: Icon(_step == 0 ? Icons.close : Icons.arrow_back,
                color: AppColors.ink),
            tooltip: _step == 0 ? 'Close' : 'Back',
          ),
          const Expanded(
            child: Text('List your produce',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          Text('${_step + 1}/${_steps.length}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: Insets.s3),
        ],
      ),
    );
  }

  Widget _progress() {
    return SizedBox(
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: Motion.base,
          curve: const Cubic(0.22, 1, 0.36, 1),
          widthFactor: (_step + 1) / _steps.length,
          child: Container(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _stepBody() {
    return switch (_stepName) {
      'Crop' => _StepCrop(
          selected: _crop,
          onPick: (c) => setState(() => _crop = c),
        ),
      'Quantity' => _StepQuantity(
          crop: _crop!,
          qty: _qty,
          unit: _unit,
          onUnit: (u) => setState(() => _unit = u),
          harvest: _harvest,
          onHarvest: _pickDate,
        ),
      'Quality' => _StepQuality(
          grade: _grade,
          onGrade: (g) => setState(() => _grade = g),
          organic: _organic,
          onOrganic: () => setState(() => _organic = !_organic),
        ),
      'Location' => LocationPickerWidget(
          initialLat: _lat,
          initialLng: _lng,
          onLocationSelected: ({
            required String pincode,
            required String village,
            required String taluk,
            required String district,
            required String state,
            required String country,
            required double lat,
            required double lng,
          }) {
            setState(() {
              _pincode = pincode;
              _village = village;
              _taluk = taluk;
              _district = district;
              _state = state;
              _country = country;
              _lat = lat;
              _lng = lng;
            });
          },
        ),
      'Photos' => _StepPhotos(
          photos: _photos,
          onAdd: _photos.length < 3 ? _pickPhoto : null,
          onRemove: (i) => setState(() => _photos.removeAt(i)),
        ),
      'Price' => _StepPrice(
          crop: _crop!,
          price: _price,
          verdict: _verdict,
        ),
      _ => _StepReview(
          crop: _crop!,
          qty: _qty.text,
          unit: _unit,
          harvest: _harvest,
          grade: _grade,
          organic: _organic,
          photos: _photos.length,
          price: _priceNum,
          location: _village != null ? '$_village, $_taluk' : null,
        ),
    };
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _harvest ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 120)),
    );
    if (d != null) setState(() => _harvest = d);
  }

  Widget _footer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Insets.s4,
        Insets.s3,
        Insets.s4,
        Insets.s4 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            AppButton.ghost('Back', onPressed: _back),
            const SizedBox(width: Insets.s3),
          ],
          Expanded(
            child: _last
                ? AppButton.accent(_publishing ? 'Publishing…' : 'Publish listing',
                    onPressed: (_canNext && !_publishing) ? _publish : null)
                : AppButton.primary('Continue',
                    onPressed: _canNext ? _next : null),
          ),
        ],
      ),
    );
  }
}

// ── shared step atoms ──────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.q, this.hint);
  final String q;
  final String hint;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4)),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: Insets.s5),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.s2),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: text),
          const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.accent)),
        ]),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── step 0: crop ───────────────────────────────────────────────

class _StepCrop extends StatelessWidget {
  const _StepCrop({required this.selected, required this.onPick});
  final Crop? selected;
  final ValueChanged<Crop> onPick;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle(
              'What are you selling?', 'Pick your crop.'),
          const SizedBox(height: Insets.s3),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Insets.s3,
            crossAxisSpacing: Insets.s3,
            childAspectRatio: 1.05,
            children: [
              for (final c in context.store.crops)
                _CropButton(
                  crop: c,
                  on: selected?.name == c.name,
                  onTap: () => onPick(c),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CropButton extends StatelessWidget {
  const _CropButton({required this.crop, required this.on, required this.onTap});
  final Crop crop;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        decoration: BoxDecoration(
          color: on ? AppColors.primaryTint : AppColors.bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: on ? AppColors.primary : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(crop.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(crop.name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.primaryPress : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

// ── step 1: quantity ───────────────────────────────────────────

class _StepQuantity extends StatelessWidget {
  const _StepQuantity({
    required this.crop,
    required this.qty,
    required this.unit,
    required this.onUnit,
    required this.harvest,
    required this.onHarvest,
  });
  final Crop crop;
  final TextEditingController qty;
  final Unit unit;
  final ValueChanged<Unit> onUnit;
  final DateTime? harvest;
  final VoidCallback onHarvest;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepTitle('How much, and when?',
              '${crop.emoji} ${crop.name} — buyers filter by quantity, so be exact.'),
          const _FieldLabel('Quantity'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: tnum,
                  decoration: const InputDecoration(hintText: '0'),
                ),
              ),
              const SizedBox(width: Insets.s3),
              _UnitSelector(unit: unit, onChanged: onUnit),
            ],
          ),
          const SizedBox(height: Insets.s5),
          const _FieldLabel('Ready by'),
          Tappable(
            onTap: onHarvest,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: Insets.s4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: AppColors.line, width: 1.4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 18, color: AppColors.muted),
                  const SizedBox(width: Insets.s3),
                  Text(
                    harvest == null
                        ? 'Pick a date'
                        : '${harvest!.day}/${harvest!.month}/${harvest!.year}',
                    style: TextStyle(
                      fontSize: 16,
                      color: harvest == null ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.s2),
          const Text('Already harvested? Pick today.',
              style: TextStyle(fontSize: 14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  const _UnitSelector({required this.unit, required this.onChanged});
  final Unit unit;
  final ValueChanged<Unit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final u in Unit.values)
            GestureDetector(
              onTap: () => onChanged(u),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: unit == u ? AppColors.bg : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: unit == u
                      ? const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 3,
                              offset: Offset(0, 1))
                        ]
                      : null,
                ),
                child: Text(u.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: unit == u ? AppColors.ink : AppColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── step 2: quality ────────────────────────────────────────────

class _StepQuality extends StatelessWidget {
  const _StepQuality({
    required this.grade,
    required this.onGrade,
    required this.organic,
    required this.onOrganic,
  });
  final Grade? grade;
  final ValueChanged<Grade> onGrade;
  final bool organic;
  final VoidCallback onOrganic;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('What quality grade?',
              'Honest grading earns repeat buyers and better ratings.'),
          for (final g in Grade.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.s3),
              child: _GradeOption(
                grade: g,
                on: grade == g,
                onTap: () => onGrade(g),
              ),
            ),
          const SizedBox(height: Insets.s1),
          _OrganicToggle(on: organic, onTap: onOrganic),
        ],
      ),
    );
  }
}

class _GradeOption extends StatelessWidget {
  const _GradeOption({required this.grade, required this.on, required this.onTap});
  final Grade grade;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        width: double.infinity,
        padding: const EdgeInsets.all(Insets.s3),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryTint : AppColors.bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
              color: on ? AppColors.primary : AppColors.line, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grade ${grade.label}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(grade.desc,
                style: TextStyle(
                    fontSize: 13,
                    color: on ? AppColors.primaryPress : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _OrganicToggle extends StatelessWidget {
  const _OrganicToggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Insets.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.eco, size: 22, color: AppColors.ok),
            const SizedBox(width: Insets.s3),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Organic / chemical-free',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('Adds a verified-organic badge buyers can filter for',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: Insets.s3),
            AnimatedContainer(
              duration: Motion.fast,
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: on ? AppColors.ok : AppColors.lineStrong,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: AnimatedAlign(
                duration: Motion.base,
                curve: const Cubic(0.22, 1, 0.36, 1),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: AppColors.bg, shape: BoxShape.circle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── step 3: photos ─────────────────────────────────────────────

class _StepPhotos extends StatelessWidget {
  const _StepPhotos({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });
  final List<Uint8List> photos;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Add photos',
              'Listings with photos get ~3× more offers. Show the real produce.'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Insets.s3,
            crossAxisSpacing: Insets.s3,
            children: [
              for (var i = 0; i < photos.length; i++)
                _PhotoTile(bytes: photos[i], onRemove: () => onRemove(i)),
              if (onAdd != null) _AddPhoto(onTap: onAdd!),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
          child: Image.memory(bytes,
              fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                  color: Color(0x991C2117), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: AppColors.bg),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddPhoto extends StatelessWidget {
  const _AddPhoto({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: const Dottedish(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 26, color: AppColors.muted),
            SizedBox(height: 4),
            Text('Add photo',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// Dashed-looking add tile (solid stroke kept simple; reads as an add slot).
class Dottedish extends StatelessWidget {
  const Dottedish({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
            color: AppColors.lineStrong, width: 1.5, style: BorderStyle.solid),
      ),
      child: child,
    );
  }
}

// ── step 4: price ──────────────────────────────────────────────

class _StepPrice extends StatelessWidget {
  const _StepPrice({required this.crop, required this.price, required this.verdict});
  final Crop crop;
  final TextEditingController price;
  final String? verdict;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Set your price',
              "See today's mandi price first, then decide."),
          Container(
            padding: const EdgeInsets.all(Insets.s4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified, size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Text("TODAY'S MANDI PRICE · ${crop.name.toUpperCase()}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: Insets.s2),
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: inr(crop.marketPrice),
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const TextSpan(
                      text: ' /quintal',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ])),
                const SizedBox(height: 2),
                const Text('Source: eNAM / Agmarknet · Kolar APMC',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: Insets.s5),
          const _FieldLabel('Your asking price (₹/quintal)'),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: tnum,
            decoration: InputDecoration(hintText: '${crop.marketPrice}'),
          ),
          if (verdict != null) ...[
            const SizedBox(height: Insets.s2),
            _Verdict(verdict!),
          ],
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict(this.verdict);
  final String verdict;
  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (verdict) {
      'fair' => (
          Icons.check,
          AppColors.ok,
          "Fair — close to today's mandi rate"
        ),
      'high' => (
          Icons.arrow_upward,
          AppColors.warnInk,
          'Above mandi — may take longer to sell'
        ),
      _ => (
          Icons.arrow_downward,
          AppColors.accentPress,
          'Below mandi — you could ask for more'
        ),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(text,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ),
      ],
    );
  }
}

// ── step 5: review ─────────────────────────────────────────────

class _StepReview extends StatelessWidget {
  const _StepReview({
    required this.crop,
    required this.qty,
    required this.unit,
    required this.harvest,
    required this.grade,
    required this.organic,
    required this.photos,
    required this.price,
    this.location,
  });
  final Crop crop;
  final String qty;
  final Unit unit;
  final DateTime? harvest;
  final Grade? grade;
  final bool organic;
  final int photos;
  final int price;
  final String? location;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepTitle('Review & publish',
              'Check the details. You can edit anything before going live.'),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _row('Crop', '${crop.emoji} ${crop.name}'),
                _row('Quantity', '${qty.isEmpty ? '—' : qty} ${unit.label}'),
                _row(
                    'Ready by',
                    harvest == null
                        ? '—'
                        : '${harvest!.day}/${harvest!.month}/${harvest!.year}'),
                _row('Grade', grade == null ? '—' : 'Grade ${grade!.label}'),
                _row('Organic', organic ? 'Yes' : 'No'),
                if (location != null) _row('Location', location!),
                _row('Photos', '$photos added'),
                _row('Asking price', price == 0 ? '—' : '${inr(price)}/quintal',
                    last: true),
              ],
            ),
          ),
          const SizedBox(height: Insets.s4),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: Insets.s4, vertical: Insets.s3),
            decoration: BoxDecoration(
              color: AppColors.okTint,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user, size: 18, color: AppColors.ok),
                SizedBox(width: Insets.s2),
                Expanded(
                  child: Text(
                    'Payment is held in escrow and released to you only after '
                    'the buyer confirms delivery — so you always get paid.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF1F5230)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, {bool last = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: Insets.s4, vertical: Insets.s3),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text(k, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          const Spacer(),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── success ────────────────────────────────────────────────────

class _Success extends StatelessWidget {
  const _Success({required this.crop});
  final String crop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          Insets.s5, Insets.s10, Insets.s5, Insets.s5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: Motion.slow,
            curve: const Cubic(0.22, 1, 0.36, 1),
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  color: AppColors.okTint, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 42, color: AppColors.ok),
            ),
          ),
          const SizedBox(height: Insets.s5),
          Text('Your $crop is live',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const SizedBox(height: 6),
          const Text(
            "Buyers near Kolar can see it now. We'll notify you the moment an offer comes in.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.muted),
          ),
          const SizedBox(height: Insets.s8),
          AppButton.primary('Done', onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}
