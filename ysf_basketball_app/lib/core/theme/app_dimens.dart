/// Spacing, radius and border tokens.
///
/// The logo is hand-drawn with a thick marker, so the UI uses heavy 2.5px
/// outlines and chunky radii rather than thin corporate hairlines
/// (spec Section 8: "rounded corners, generous spacing, bold labels").
abstract final class AppDimens {
  // Spacing scale.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard screen padding.
  static const double screen = 20;

  // Corner radii.
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusPill = 999;

  /// Marker-weight outline used on cards and buttons.
  static const double border = 2;

  /// Thinner outline for quiet rows.
  static const double hairline = 1.5;

  /// Diagonal offset of the hard "sticker" shadow under pressable surfaces.
  static const double stickerDrop = 4;

  /// Minimum tap target — organizers use this one-handed, courtside.
  static const double tapTarget = 52;
}
