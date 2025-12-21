import 'package:admin_design_system/admin_design_system.dart';
import 'package:dag_domain/dag_domain.dart';
import 'package:flutter/material.dart';

/// Centralized DAG color definitions (DRY principle)
abstract final class DagColors {
  /// Chain block (blue) - on consensus chain
  static const Color chainBlock = AdminColors.info;

  /// Off-chain block (red) - not on consensus chain
  static const Color offChainBlock = AdminColors.error;

  /// Sink block - selected parent of virtual
  static const Color sink = AdminColors.warning;

  /// Tip blocks - leaf nodes of DAG
  static const Color tip = AdminColors.success;

  /// Virtual block - conceptual block at DAG top
  static const Color virtualBlock = AdminColors.primaryLight;

  /// Selected parent edge
  static const Color selectedParentEdge = AdminColors.primary;

  /// Normal edge
  static const Color normalEdge = AdminColors.textTertiaryLight;

  /// Get background color for a block
  static Color getBlockBackground(DagBlock block) {
    return switch (block.blockType) {
      DagBlockType.sink => sink.withValues(alpha: 0.2),
      DagBlockType.tip => tip.withValues(alpha: 0.2),
      DagBlockType.virtual => virtualBlock.withValues(alpha: 0.2),
      DagBlockType.regular when block.isChainBlock =>
        chainBlock.withValues(alpha: 0.2),
      DagBlockType.regular => offChainBlock.withValues(alpha: 0.2),
    };
  }

  /// Get border color for a block
  static Color getBlockBorder(DagBlock block) {
    return switch (block.blockType) {
      DagBlockType.sink => sink,
      DagBlockType.tip => tip,
      DagBlockType.virtual => virtualBlock,
      DagBlockType.regular when block.isChainBlock => chainBlock,
      DagBlockType.regular => offChainBlock,
    };
  }

  /// Get text color for a block (contrast with background)
  static Color getBlockText(DagBlock block) {
    return switch (block.blockType) {
      DagBlockType.sink => sink,
      DagBlockType.tip => tip,
      DagBlockType.virtual => virtualBlock,
      DagBlockType.regular when block.isChainBlock => chainBlock,
      DagBlockType.regular => offChainBlock,
    };
  }

  /// Get edge color based on whether it's a selected parent edge
  static Color getEdgeColor({required bool isSelectedParent}) {
    return isSelectedParent ? selectedParentEdge : normalEdge;
  }
}
