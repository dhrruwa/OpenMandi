import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');

/// ₹ with Indian digit grouping (lakh/crore), no decimals.
String inr(num n) => '₹${_inr.format(n.round())}';

/// Force tabular figures so prices/quantities don't jitter as they change.
const tnum = TextStyle(
  fontFeatures: [FontFeature.tabularFigures()],
);
