import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/muse_colors.dart';
import '../../features/pairing/pairing_sheet.dart';
import 'mini_player_bar.dart';
import 'muse_header.dart';
import 'muse_nav_bar.dart';
import 'muse_sidebar.dart';

/// Root scaffold for the tab sections. The [StatefulNavigationShell] keeps
/// each branch (tab) alive so switching tabs never loses their state.
///
/// Portrait shows the collapsing wordmark header + floating marble nav bar;
/// landscape/desktop swaps the nav bar for a slim marble sidebar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return orientation == Orientation.landscape
            ? _LandscapeShell(navigationShell: navigationShell)
            : _PortraitShell(navigationShell: navigationShell);
      },
    );
  }
}

class _PortraitShell extends StatefulWidget {
  const _PortraitShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_PortraitShell> createState() => _PortraitShellState();
}

class _PortraitShellState extends State<_PortraitShell>
    with SingleTickerProviderStateMixin {
  bool _headerVisible = true;
  double _lastScrollY = 0;
  double _pullProgress = 0;
  bool _refreshing = false;
  bool _pullActive = false;
  bool _isSnapping = false;
  AnimationController? _snapController;
  double _snapStart = 0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _snapController?.removeListener(_onSnapTick);
    _snapController?.dispose();
    super.dispose();
  }

  void _onSnapTick() {
    final ctrl = _snapController;
    if (ctrl == null) return;
    setState(() {
      _pullProgress = lerpDouble(_snapStart, 0, ctrl.value) ?? 0;
    });
    if (ctrl.isCompleted) {
      _isSnapping = false;
    }
  }

  void _animateSnapBack() {
    _isSnapping = true;
    _snapStart = _pullProgress;
    _snapController?.forward(from: 0);
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _refreshing = true;
      _pullActive = false;
      _pullProgress = 0.7;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _refreshing = false;
        _pullProgress = 0;
      });
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentPixels = notification.metrics.pixels;
      if (currentPixels >= 0) {
        final delta = currentPixels - _lastScrollY;
        const threshold = 10.0;

        if (delta > threshold && _headerVisible && !_pullActive) {
          setState(() => _headerVisible = false);
        } else if ((delta < -threshold || currentPixels <= 0) &&
            !_headerVisible) {
          setState(() => _headerVisible = true);
        }
      }
      _lastScrollY = currentPixels;
    }

    if (notification is OverscrollNotification &&
        notification.overscroll < 0 &&
        !_refreshing) {
      if (_isSnapping) {
        _snapController?.stop();
        _isSnapping = false;
      }
      _pullActive = true;
      if (!_headerVisible) setState(() => _headerVisible = true);
      setState(() {
        _pullProgress = (notification.overscroll.abs() / 120).clamp(0.0, 1.5);
      });
    }

    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels < 0 &&
        !_refreshing) {
      if (_isSnapping) {
        _snapController?.stop();
        _isSnapping = false;
      }
      _pullActive = true;
      if (!_headerVisible) setState(() => _headerVisible = true);
      setState(() {
        _pullProgress = (notification.metrics.pixels.abs() / 120).clamp(0.0, 1.5);
      });
    }

    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle &&
        _pullActive) {
      _pullActive = false;
      if (_pullProgress >= 0.7 && !_refreshing) {
        _triggerRefresh();
      } else if (_pullProgress > 0) {
        _animateSnapBack();
      }
    }

    return false;
  }

  void _selectTab(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final headerTotalHeight = padding.top + MuseHeader.contentHeight;
    final bottomInset = padding.bottom;

    return Scaffold(
      backgroundColor: MuseColors.baseSurface,
      body: Stack(
        children: [
          AnimatedPadding(
            padding: EdgeInsets.only(
              top: _headerVisible ? headerTotalHeight : 0,
              bottom: bottomInset + 84,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: widget.navigationShell,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MuseHeader(
              visible: _headerVisible,
              pullProgress: _pullProgress,
              refreshing: _refreshing,
              onPairTap: () => openPairingSheet(context),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: MuseNavBar(
              activeIndex: widget.navigationShell.currentIndex,
              onSelect: _selectTab,
            ),
          ),
          // Mini player floats just above the nav pill while a song plays.
          Positioned(
            bottom: bottomInset + 84,
            left: 20,
            right: 20,
            child: const MiniPlayerBar(),
          ),
        ],
      ),
    );
  }
}

class _LandscapeShell extends StatelessWidget {
  const _LandscapeShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _selectTab(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final sidebarWidth = math.max(padding.left, 12.0) + 72.0;

    return Scaffold(
      backgroundColor: MuseColors.baseSurface,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(left: sidebarWidth),
            child: Material(
              type: MaterialType.transparency,
              child: navigationShell,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: MuseSidebar(
              activeIndex: navigationShell.currentIndex,
              onSelect: (i) => _selectTab(context, i),
            ),
          ),
          // Mini player along the bottom of the content area (right of the
          // sidebar) while a song plays.
          Positioned(
            bottom: padding.bottom + 16,
            left: sidebarWidth + 16,
            right: 16,
            child: const MiniPlayerBar(),
          ),
        ],
      ),
    );
  }
}