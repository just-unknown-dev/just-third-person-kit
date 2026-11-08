/// The models the kit's prefabs show; the third-person template's by
/// default.
final class ThirdPersonModels {
  /// Models at these paths.
  const ThirdPersonModels({
    this.hero = 'assets/models/hero.glb',
    this.ground = 'assets/models/ground.glb',
    this.block = 'assets/models/block.glb',
    this.platform = 'assets/models/platform.glb',
    this.coin = 'assets/models/coin.glb',
    this.flag = 'assets/models/flag.glb',
    this.heroAnimator = 'assets/animators/hero.animator.json',
    this.heroCombos = 'assets/models/hero.combos.json',
  });

  /// The hero: in the template, JustHumanoid, with idle, walk, run, jump,
  /// crouch_idle and crouch_walk.
  final String hero;

  /// The ground: its top at the model's origin.
  final String ground;

  /// A unit cube about its origin.
  final String block;

  /// A unit cube about its origin, for moving platforms.
  final String platform;

  /// A coin about its origin.
  final String coin;

  /// A checkpoint's flag about its origin.
  final String flag;

  /// The hero's animator graph: in the template, its moves by speed, the
  /// jump in the air and the crouch.
  final String heroAnimator;

  /// The hero's strikes and their chains: in the template, JustHumanoid's
  /// punch and kick combos.
  final String heroCombos;
}
