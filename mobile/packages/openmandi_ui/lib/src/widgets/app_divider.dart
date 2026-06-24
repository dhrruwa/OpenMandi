import 'package:flutter/widgets.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// The one divider style for the app: a 1px hairline in [AppColors.line].
/// Use instead of ad-hoc Material `Divider` / `SizedBox` gaps.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0, this.height = Insets.s4});

  /// Left inset (e.g. to align under text past a leading avatar).
  final double indent;

  /// Total vertical space the divider occupies (line sits centred).
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          margin: EdgeInsets.only(left: indent),
          height: 1,
          color: AppColors.line,
        ),
      ),
    );
  }
}
