import 'package:almi3/core/app_colors.dart';
import 'package:almi3/core/logger.dart';
import 'package:almi3/model/dto/root_card_stats.dart';
import 'package:almi3/view/widgets/root_card.dart';
import 'package:almi3/view/widgets/root_filter_bar.dart';
import 'package:almi3/view/widgets/root_search_field.dart';
import 'package:almi3/view/word_page.dart';
import 'package:almi3/viewmodel/root_list_viewmodel.dart';
import 'package:almi3/viewmodel/state/root_list_page_state.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO: remove when word_progress table is wired
const _mockStats = [
  null,
  RootCardStats(verbs: WordTypeStats(total: 12, learned: 4, due: 0)),
  RootCardStats(verbs: WordTypeStats(total: 8, learned: 8, due: 0), nouns: WordTypeStats(total: 3, learned: 3, due: 0)),
  RootCardStats(verbs: WordTypeStats(total: 10, learned: 3, due: 2), nouns: WordTypeStats(total: 4, learned: 1, due: 1)),
  RootCardStats(verbs: WordTypeStats(total: 6, learned: 6, due: 0), nouns: WordTypeStats(total: 2, learned: 2, due: 0), adjs: WordTypeStats(total: 3, learned: 3, due: 0)),
  RootCardStats(verbs: WordTypeStats(total: 9, learned: 0, due: 0)),
];

class RootListPage extends ConsumerStatefulWidget {
  const RootListPage({super.key});

  @override
  ConsumerState<RootListPage> createState() => _RootListPageState();
}

class _RootListPageState extends ConsumerState<RootListPage> {
  RootFilter _filter = RootFilter.all;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _titleVisible = false;

  static const _toolbarPlaceholderHeight = 44.0;
  static const _largeTitleHeight = 41.0;
  static const _titleToSearchGap = 10.0;
  static const _searchFieldHeight = 38.0;
  static const _searchToFilterGap = 12.0;
  static const _filterHeight = 32.0;
  static const _filterBottomGap = 8.0;
  static const _expandedHeight = _toolbarPlaceholderHeight + _largeTitleHeight + _titleToSearchGap + _searchFieldHeight + _searchToFilterGap + _filterHeight + _filterBottomGap;
  static const _collapseThreshold = _expandedHeight - kToolbarHeight;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > _collapseThreshold;
      if (collapsed != _titleVisible) setState(() => _titleVisible = collapsed);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(rootListPageProvider);
    logger.d('RootListPage build: roots=${pageState.roots.length}, isLoading=${pageState.isLoading}');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        body: _buildBody(pageState),
      ),
    );
  }

  Widget _buildBody(RootListPageState state) {
    if (state.isLoading && state.roots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errMsg != null) {
      return Center(child: Text('Error: ${state.errMsg}'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(rootListPageProvider.notifier).refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent * 0.8) {
            ref.read(rootListPageProvider.notifier).loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildTitleAndSearchSliver(),
            _buildRootCardListSliver(state),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildTitleAndSearchSliver() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: _expandedHeight,
      floating: false,
      pinned: true,
      snap: false,
      centerTitle: true,
      title: AnimatedOpacity(
        opacity: _titleVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: const Text(
          'Roots',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {/* TODO: toggle niqqud */},
          tooltip: 'Toggle niqqud',
          icon: const Text(
            'אָ',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.tekhelet),
          ),
        ),
        IconButton(
          onPressed: () {/* TODO: open settings */},
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined, size: 23, color: AppColors.tekhelet),
        ),
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            color: AppColors.navBarBackground,
            child: FlexibleSpaceBar(
        title: const SizedBox.shrink(),
        collapseMode: CollapseMode.pin,
        background: Container(
          color: AppColors.pageBackground,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: _toolbarPlaceholderHeight),
                const Text(
                  'Roots',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AppColors.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: _titleToSearchGap),
                RootSearchField(controller: _searchController),
                const SizedBox(height: _searchToFilterGap),
                RootFilterBar(
                  filter: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                // const SizedBox(height: _filterBottomGap),
              ],
            ),
          ),
        ),
        ),
      ),
          ),
        ),
      ),
    );
  }


  Widget _buildRootCardListSliver(RootListPageState state) {
    if (state.roots.isEmpty) {
      return const SliverFillRemaining(
          child: Center(child: Text('No roots — try syncing first.'))
      );
    }
    else {
      final roots = state.roots.where((r) {
        if (_filter == RootFilter.saved) return state.isBookmarked(r.id);
        // TODO: toReview filter needs due count from word_progress
        return true;
      }).toList();
      return SliverPadding(
        padding: const EdgeInsets.only(/*top: 11, */bottom: 110),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == roots.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final root = roots[index];
              return RootCard(
                hebrewText: root.value,
                isBookmarked: state.isBookmarked(root.id),
                stats: _mockStats[index % _mockStats.length],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WordPage(root: root)),
                ),
                onBookmarkToggle: () =>
                    ref.read(rootListPageProvider.notifier).toggleBookmark(root.id),
              );
            },
            childCount: roots.length + (state.isLoading ? 1 : 0),
          ),
        ),
      );
    }
  }
}
