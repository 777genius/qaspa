import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../layout/dag_layout.dart';
import '../stores/dag_store.dart';
import '../theme/dag_theme.dart';
import '../widgets/controls/dag_controls.dart';
import '../widgets/dag_block_tooltip.dart';
import '../widgets/dag_legend.dart';
import 'dag_painter.dart';

/// DAG visualization widget using CustomPainter with KGI-style layout
/// Reference: https://github.com/kaspa-live/kaspa-graph-inspector
class DagCanvasWidget extends StatefulWidget {
  final DagStore store;
  final bool showLegend;
  final bool showControls;

  const DagCanvasWidget({
    super.key,
    required this.store,
    this.showLegend = true,
    this.showControls = true,
  });

  @override
  State<DagCanvasWidget> createState() => _DagCanvasWidgetState();
}

class _DagCanvasWidgetState extends State<DagCanvasWidget> {
  final TransformationController _transformController =
      TransformationController();
  final DagLayout _layout = DagLayout(blockSize: 60.0);

  DagLayoutResult _layoutResult = DagLayoutResult.empty();
  String? _hoveredBlockHash;

  /// Flag to distinguish programmatic moves from user pan
  bool _isProgrammaticMove = false;

  /// Last known translation to detect pan changes
  Offset? _lastTranslation;

  /// Last scale to detect zoom vs pan
  double _lastScale = 1.0;

  /// Hash of last block we followed (to avoid repeated jumps)
  String? _lastFollowedBlockHash;

  @override
  void initState() {
    super.initState();
    _updateLayout();
    _transformController.addListener(_onTransformChanged);

    // Jump to latest block on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.store.sortedBlocks.isNotEmpty) {
        _jumpToLatest();
      }
    });
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  /// Detect user pan (not zoom, not programmatic)
  void _onTransformChanged() {
    if (_isProgrammaticMove) return;

    final matrix = _transformController.value;
    final translation = matrix.getTranslation();
    final currentTranslation = Offset(translation.x, translation.y);
    final currentScale = matrix.getMaxScaleOnAxis();

    // Only disable auto-follow on pan (translation change without scale change)
    final scaleChanged = (currentScale - _lastScale).abs() > 0.001;
    final translationChanged = _lastTranslation != null &&
        (currentTranslation - _lastTranslation!).distance > 1.0;

    if (translationChanged && !scaleChanged) {
      // User panned - disable auto-follow
      widget.store.disableAutoFollow();
    }

    _lastTranslation = currentTranslation;
    _lastScale = currentScale;
  }

  void _updateLayout() {
    _layoutResult = _layout.calculate(widget.store.blocks);
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.2).clamp(0.1, 3.0);
    _setScale(newScale);
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.2).clamp(0.1, 3.0);
    _setScale(newScale);
  }

  void _resetZoom() {
    _isProgrammaticMove = true;
    _transformController.value = Matrix4.identity();
    _lastTranslation = Offset.zero;
    _lastScale = 1.0;
    Future.microtask(() {
      _isProgrammaticMove = false;
    });
  }

  void _setScale(double scale) {
    _isProgrammaticMove = true;

    final center = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );

    final currentMatrix = _transformController.value.clone();
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final scaleChange = scale / currentScale;

    final translation = currentMatrix.getTranslation();
    final focalPoint = center;

    final newTranslation = Offset(
      focalPoint.dx - (focalPoint.dx - translation.x) * scaleChange,
      focalPoint.dy - (focalPoint.dy - translation.y) * scaleChange,
    );

    _transformController.value = Matrix4.identity()
      ..translate(newTranslation.dx, newTranslation.dy)
      ..scale(scale);

    _lastTranslation = newTranslation;
    _lastScale = scale;

    Future.microtask(() {
      _isProgrammaticMove = false;
    });
  }

  void _jumpToLatest() {
    final sorted = widget.store.sortedBlocks;
    if (sorted.isEmpty) return;

    final latestHash = sorted.first.hash.value;
    final blockPos = _layoutResult[latestHash];
    if (blockPos == null) return;

    _isProgrammaticMove = true;

    final center = blockPos.center(_layout.blockSize);
    final screenCenter = Offset(
      MediaQuery.of(context).size.width / 2,
      MediaQuery.of(context).size.height / 2,
    );

    final offset = _layoutResult.centerOffset();
    final currentScale = _transformController.value.getMaxScaleOnAxis();

    // Calculate target position, preserving current zoom
    final targetX = screenCenter.dx - (center.dx + offset.dx) * currentScale;
    final targetY = screenCenter.dy - (center.dy + offset.dy) * currentScale;

    _transformController.value = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(currentScale);

    // Update tracking variables
    _lastTranslation = Offset(targetX, targetY);
    _lastScale = currentScale;
    _lastFollowedBlockHash = latestHash;

    // Reset flag after microtask to allow transform listener to settle
    Future.microtask(() {
      _isProgrammaticMove = false;
    });
  }

  void _handleTap(TapUpDetails details) {
    final painter = DagPainter(
      layout: _layoutResult,
      panOffset: Offset(
        _transformController.value.getTranslation().x,
        _transformController.value.getTranslation().y,
      ),
      scale: _transformController.value.getMaxScaleOnAxis(),
    );

    final blockHash = painter.getBlockAtPosition(details.localPosition);
    widget.store.selectBlock(blockHash);
  }

  void _handleHover(PointerHoverEvent event) {
    final painter = DagPainter(
      layout: _layoutResult,
      panOffset: Offset(
        _transformController.value.getTranslation().x,
        _transformController.value.getTranslation().y,
      ),
      scale: _transformController.value.getMaxScaleOnAxis(),
    );

    final blockHash = painter.getBlockAtPosition(event.localPosition);
    if (blockHash != _hoveredBlockHash) {
      setState(() {
        _hoveredBlockHash = blockHash;
      });
      widget.store.hoverBlock(blockHash);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        final store = widget.store;

        // Update layout when blocks change
        _updateLayout();

        // Auto-follow: jump to latest block when new blocks arrive
        if (store.isAutoFollowEnabled && store.sortedBlocks.isNotEmpty) {
          final latestHash = store.sortedBlocks.first.hash.value;
          if (latestHash != _lastFollowedBlockHash) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _jumpToLatest();
            });
          }
        }

        if (store.isLoading && store.blocks.isEmpty) {
          return const Center(
            child: LoadingIndicator(message: 'Loading DAG...'),
          );
        }

        if (store.error != null && store.blocks.isEmpty) {
          return ErrorView(
            title: 'Failed to load DAG',
            message: store.error,
            onRetry: () => store.connect(store.connectedNodeId ?? ''),
          );
        }

        if (store.blocks.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'No blocks',
              message: 'Connect to a node to view the DAG',
            ),
          );
        }

        return Stack(
          children: [
            // Background
            Container(color: DagBackgroundColors.dark),

            // Interactive DAG canvas
            MouseRegion(
              onHover: _handleHover,
              onExit: (_) {
                setState(() => _hoveredBlockHash = null);
                widget.store.hoverBlock(null);
              },
              child: GestureDetector(
                onTapUp: _handleTap,
                child: InteractiveViewer(
                  constrained: false,
                  transformationController: _transformController,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  minScale: 0.1,
                  maxScale: 3.0,
                  child: CustomPaint(
                    size: _layoutResult.canvasSize(),
                    painter: DagPainter(
                      layout: _layoutResult,
                      newBlockHashes: store.newBlockHashes,
                      hoveredBlockHash: _hoveredBlockHash,
                      selectedBlockHash: store.selectedBlockHash,
                    ),
                  ),
                ),
              ),
            ),

            // Legend (top left)
            if (widget.showLegend)
              const Positioned(
                top: 16,
                left: 16,
                child: DagLegend(),
              ),

            // Controls
            if (widget.showControls)
              DagControls(
                store: store,
                onJumpToLatest: _jumpToLatest,
                onZoomIn: _zoomIn,
                onZoomOut: _zoomOut,
                onResetZoom: _resetZoom,
              ),

            // Selected block details (bottom left)
            if (store.selectedBlock case final block?)
              Positioned(
                bottom: 60,
                left: 16,
                child: DagBlockTooltip(block: block),
              ),

            // Status bar (bottom)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _StatusBar(store: store),
            ),
          ],
        );
      },
    );
  }
}

/// Status bar widget
class _StatusBar extends StatelessWidget {
  final DagStore store;

  const _StatusBar({required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AdminColors.surfaceDark.withValues(alpha: 0.9),
      ),
      child: Row(
        children: [
          // Connection status
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: store.isConnected ? AdminColors.success : AdminColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            store.isConnected
                ? 'Connected to ${store.connectedNodeId}'
                : 'Disconnected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 24),

          // Block count
          Text(
            'Blocks: ${store.blocks.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),

          const SizedBox(width: 24),

          // Tips count
          Text(
            'Tips: ${store.tipBlocks.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),

          const Spacer(),

          // DAA Score range
          if (store.dagState case final state?)
            Text(
              'DAA: ${state.virtualDaaScore.value}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),

          const SizedBox(width: 16),

          // Live mode indicator
          if (store.isLiveMode)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AdminColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AdminColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
