enum AvatarMood {
  crying,
  tired,
  neutral,
  happy,
  excited;

  String get emoji => switch (this) {
        AvatarMood.crying => '😭',
        AvatarMood.tired => '😴',
        AvatarMood.neutral => '🙂',
        AvatarMood.happy => '😄',
        AvatarMood.excited => '🤩',
      };

  String get label => switch (this) {
        AvatarMood.crying => 'Triste',
        AvatarMood.tired => 'Fatigué',
        AvatarMood.neutral => 'Calme',
        AvatarMood.happy => 'Heureux',
        AvatarMood.excited => 'Super motivé',
      };
}
