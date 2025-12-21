import 'package:admin_design_system/admin_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';

import '../../stores/dag_store.dart';

/// Control panel for DAG visualization (zoom, play/pause, jump to latest)
class DagControls extends StatelessWidget {
  final DagStore store;
  final VoidCallback? onJumpToLatest;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetZoom;

  const DagControls({
    super.key,
    required this.store,
    this.onJumpToLatest,
    this.onZoomIn,
    this.onZoomOut,
    this.onResetZoom,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Jump to latest / Auto-follow toggle (top right corner)
        Positioned(
          top: 16,
          right: 16,
          child: Observer(
            builder: (_) {
              final isFollowing = store.isAutoFollowEnabled;
              return FloatingActionButton(
                mini: true,
                heroTag: 'jump_to_latest',
                onPressed: () {
                  store.enableAutoFollow();
                  onJumpToLatest?.call();
                },
                backgroundColor:
                    isFollowing ? AdminColors.success : AdminColors.surfaceDark,
                tooltip: isFollowing
                    ? 'Following latest (click to re-center)'
                    : 'Jump to latest and follow',
                child: Icon(
                  isFollowing ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),

        // Zoom controls (bottom right corner)
        Positioned(
          bottom: 80,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ZoomButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: onZoomIn ?? () {},
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: onZoomOut ?? () {},
              ),
              const SizedBox(height: 8),
              _ZoomButton(
                icon: Icons.fit_screen,
                tooltip: 'Reset zoom',
                onPressed: onResetZoom ?? () {},
              ),
            ],
          ),
        ),

        // Play/Pause (bottom right corner)
        Positioned(
          bottom: 16,
          right: 16,
          child: Observer(
            builder: (_) => FloatingActionButton(
              heroTag: 'live_mode_toggle',
              onPressed: store.toggleLiveMode,
              backgroundColor: AdminColors.surfaceDark,
              tooltip: store.isLiveMode ? 'Pause updates' : 'Resume updates',
              child: Icon(
                store.isLiveMode ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // Zoom level indicator
        Positioned(
          bottom: 16,
          right: 80,
          child: Observer(
            builder: (_) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.surfaceDark.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(store.zoomLevel * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.surfaceDark,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
