import 'dart:ui';
import 'package:almi3/core/app_colors.dart';

import 'package:almi3/core/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontPickerPage extends StatefulWidget {
  final String title;
  final List<String> fontNames;
  final List<String> selected;
  final bool multiSelect;
  final void Function(List<String> selected) onChanged;
  final ScrollController? scrollController;

  const FontPickerPage({
    super.key,
    required this.title,
    required this.fontNames,
    required this.selected,
    required this.multiSelect,
    required this.onChanged,
    this.scrollController,
  });

  @override
  State<FontPickerPage> createState() => _FontPickerPageState();
}

class _FontPickerPageState extends State<FontPickerPage> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.of(widget.selected);
  }

  void _toggle(String font) {
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(font)) {
          if (_selected.length == 1) return; // must keep at least one
          _selected.remove(font);
        } else {
          _selected.add(font);
        }
        widget.onChanged(List.of(_selected));
      } else {
        _selected = [font];
        widget.onChanged(_selected);
        Navigator.of(context).pop();
      }
    });
  }

  TextStyle? _googleFont(String name) {
    try {
      return GoogleFonts.getFont(name, fontSize: 27);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _FontNavBarDelegate(
              title: widget.title,
              onDone: () => Navigator.of(context).pop(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (widget.multiSelect)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 7),
                    child: Text(
                      'SELECT ONE OR MORE · SHOWN IN RANDOM',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.fontNames.asMap().entries.map((entry) {
                      final i = entry.key;
                      final font = entry.value;
                      final isSelected = _selected.contains(font);
                      final tag = kFontTags[font] ?? '';
                      final fontStyle = _googleFont(font);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggle(font),
                        child: Container(
                          decoration: i == 0
                              ? null
                              : const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Color(0x14000000), width: 0.5),
                                  ),
                                ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  'אבגדן',
                                  style: fontStyle?.copyWith(
                                        fontSize: 27,
                                        color: AppColors.ink,
                                      ) ??
                                      const TextStyle(fontSize: 27, color: AppColors.ink),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      font,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    if (tag.isNotEmpty) ...[
                                      const SizedBox(height: 1),
                                      Text(
                                        tag,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 19,
                                  color: AppColors.tekhelet,
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (widget.multiSelect)
                  const Padding(
                    padding: EdgeInsets.only(top: 22, bottom: 6),
                    child: Text(
                      'Handwritten faces train real-world reading.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.inkSecondary),
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _FontNavBarDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final VoidCallback onDone;

  const _FontNavBarDelegate({required this.title, required this.onDone});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 52,
          decoration: const BoxDecoration(
            color: AppColors.navBarBackground,
            border: Border(bottom: BorderSide(color: Color(0x21000000), width: 0.5)),
          ),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: onDone,
                  child: const Center(
                    child: Text(
                      'Done',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.tekhelet),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FontNavBarDelegate old) => old.title != title;
}
