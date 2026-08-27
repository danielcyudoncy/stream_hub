enum MultiViewLayoutMode {
  dualHorizontal('2 Screens (Side-by-Side)'),
  dualVertical('2 Screens (Stacked)'),
  triple('3 Screens (1 Main + 2 Small)'),
  quad('4 Screens (Quad View)');

  final String label;
  const MultiViewLayoutMode(this.label);

  int get slotCount {
    switch (this) {
      case MultiViewLayoutMode.dualHorizontal:
      case MultiViewLayoutMode.dualVertical:
        return 2;
      case MultiViewLayoutMode.triple:
        return 3;
      case MultiViewLayoutMode.quad:
        return 4;
    }
  }
}
