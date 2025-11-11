import 'package:flutter/material.dart';

/// A widget that shows scroll indicators (up/down arrows) when content is scrollable
class ScrollIndicatorWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final bool showTopIndicator;
  final bool showBottomIndicator;
  final Color? indicatorColor;
  final double indicatorSize;

  const ScrollIndicatorWrapper({
    super.key,
    required this.child,
    this.controller,
    this.showTopIndicator = true,
    this.showBottomIndicator = true,
    this.indicatorColor,
    this.indicatorSize = 32.0,
  });

  @override
  State<ScrollIndicatorWrapper> createState() => _ScrollIndicatorWrapperState();
}

class _ScrollIndicatorWrapperState extends State<ScrollIndicatorWrapper> {
  late ScrollController _scrollController;
  bool _showTopIndicator = false;
  bool _showBottomIndicator = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_updateIndicators);

    // Check indicators after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateIndicators();
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_updateIndicators);
    }
    super.dispose();
  }

  void _updateIndicators() {
    if (!_scrollController.hasClients) return;

    setState(() {
      final position = _scrollController.position;

      // Show top indicator if we can scroll up
      _showTopIndicator = widget.showTopIndicator && position.pixels > 10;

      // Show bottom indicator if we can scroll down
      _showBottomIndicator = widget.showBottomIndicator &&
          position.pixels < position.maxScrollExtent - 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = widget.indicatorColor ?? theme.colorScheme.primary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,

        // Top scroll indicator - positioned above content with higher elevation
        if (_showTopIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.9),
                        theme.colorScheme.surface.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            0.0,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: indicatorColor.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Colors.white,
                          size: widget.indicatorSize - 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Bottom scroll indicator - positioned above content with higher elevation
        if (_showBottomIndicator)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        theme.colorScheme.surface.withValues(alpha: 0.9),
                        theme.colorScheme.surface.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        if (_scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: indicatorColor.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: widget.indicatorSize - 8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
