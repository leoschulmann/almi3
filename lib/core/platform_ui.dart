import 'package:almi3/core/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

// ---------------------------------------------------------------------------
// Time picker

Future<TimeOfDay?> showAdaptiveTimePicker(
  BuildContext context,
  TimeOfDay initial,
) async {
  if (isIOS) {
    var picked = initial;
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(2000, 1, 1, initial.hour, initial.minute),
                onDateTimeChanged: (dt) => picked = TimeOfDay.fromDateTime(dt),
              ),
            ),
          ],
        ),
      ),
    );
    return confirmed == true ? picked : null;
  } else {
    return showTimePicker(context: context, initialTime: initial);
  }
}

// ---------------------------------------------------------------------------
// Confirm dialog

Future<bool> showAdaptiveConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String destructiveLabel,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    builder: (ctx) => isIOS
        ? CupertinoAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(destructiveLabel),
              ),
            ],
          )
        : AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  destructiveLabel,
                  style: const TextStyle(color: Color(0xFFFF3B30)),
                ),
              ),
            ],
          ),
  );
  return result == true;
}

// ---------------------------------------------------------------------------
// Adaptive segmented control
//
// On iOS: CupertinoSlidingSegmentedControl
// On Android: Material SegmentedButton

class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
  final List<(T value, String label)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const AdaptiveSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<T>(
          groupValue: selected,
          onValueChanged: (v) { if (v != null) onChanged(v); },
          children: {
            for (final s in segments)
              s.$1: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(s.$2),
              ),
          },
        ),
      );
    } else {
      return SegmentedButton<T>(
        segments: segments
            .map((s) => ButtonSegment<T>(value: s.$1, label: Text(s.$2)))
            .toList(),
        selected: {selected},
        onSelectionChanged: (v) => onChanged(v.first),
        style: ButtonStyle(
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.fieldFill, width: 0),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Adaptive icon button — no Material ripple on iOS, uses CupertinoButton

class AdaptiveIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const AdaptiveIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onPressed: onPressed,
        child: icon,
      );
    } else {
      return IconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Adaptive page route — slide-from-right with iOS physics on iOS

PageRoute<T> adaptivePageRoute<T>({required WidgetBuilder builder}) {
  if (isIOS) {
    return CupertinoPageRoute<T>(builder: builder);
  } else {
    return MaterialPageRoute<T>(builder: builder);
  }
}

// ---------------------------------------------------------------------------
// Adaptive option picker — CupertinoActionSheet on iOS, bottom sheet with
// ListTiles on Android.
//
// options: list of (value, label) pairs. Returns the selected value or null.

Future<T?> showAdaptiveOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<(T value, String label)> options,
  T? current,
}) async {
  if (isIOS) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(title),
        actions: options.map((o) => CupertinoActionSheetAction(
          isDefaultAction: o.$1 == current,
          onPressed: () => Navigator.pop(ctx, o.$1),
          child: Text(o.$2),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
      ),
    );
  } else {
    return showModalBottomSheet<T>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((o) => ListTile(
            title: Text(o.$2),
            trailing: o.$1 == current
                ? const Icon(Icons.check_rounded, color: AppColors.tekhelet)
                : null,
            onTap: () => Navigator.pop(ctx, o.$1),
          )).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adaptive toast/snackbar — CupertinoToast-style overlay on iOS,
// SnackBar on Android.

void showAdaptiveToast(BuildContext context, String message) {
  if (isIOS) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => _IosToast(message: message),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      ),
    );
  }
}

class _IosToast extends StatefulWidget {
  final String message;
  const _IosToast({required this.message});

  @override
  State<_IosToast> createState() => _IosToastState();
}

class _IosToastState extends State<_IosToast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 60,
      left: 32,
      right: 32,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xE6323232),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
