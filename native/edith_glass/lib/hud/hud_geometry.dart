/// HUD の幾何を **論理256×256（Halo の円形ディスプレイと同じ）** で定義する。
/// Flutter の [ReticlePainter] と Halo 実機用の [haloReticleLua] が
/// この同一定数を使うことで、プレビューと実機の見た目を一致させる。
///
/// レティクルは「ドットサイト」= 中央を小さく示すだけのミニマル表示。
class HudGeometry {
  static const double size = 256; // Halo display: 256x256 circular
  static const double cx = 128;
  static const double cy = 128;

  // ドットサイト：細いリング＋中心ドット
  static const double dotRing = 9; // 中心リングの半径
  static const double dotCore = 2.4; // 中心ドットの半径

  // テキスト位置（上部ステータス／下部の名前タグ・補足）
  static const double statusY = 24;
  static const double nameY = 196;
  static const double subY = 216;
}
