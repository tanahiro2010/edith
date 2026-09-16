/// レティクルの幾何を **論理256×256（Halo の円形ディスプレイと同じ）** で定義する。
/// Flutter の [ReticlePainter] と Halo 実機用の [haloReticleLua] が
/// この同一定数を使うことで、プレビューと実機の見た目を一致させる。
class HudGeometry {
  static const double size = 256; // Halo display: 256x256 circular
  static const double cx = 128;
  static const double cy = 128;

  // 円形ディスプレイの縁
  static const double edgeRadius = 126;

  // 外周の目盛りリング
  static const double ringRadius = 96;
  static const double ringTickInner = 88;
  static const int ringTicks = 12;

  // 中央を囲むコーナーブラケット
  static const double bracket = 40; // 中心からブラケット角までの距離
  static const double bracketArm = 16; // 腕の長さ

  // 中央クロスヘア
  static const double crossGap = 10;
  static const double crossTick = 22;

  // 中央の照準リング・ドット
  static const double aimRing = 6;
  static const double aimDot = 1.6;
}
