/// Onboarding item entity
class OnboardingItem {
  final String title;
  final String description;
  final String? imagePath;

  const OnboardingItem({
    required this.title,
    required this.description,
    this.imagePath,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OnboardingItem &&
        other.title == title &&
        other.description == description &&
        other.imagePath == imagePath;
  }

  @override
  int get hashCode {
    return title.hashCode ^ description.hashCode ^ imagePath.hashCode;
  }

  @override
  String toString() {
    return 'OnboardingItem(title: $title, description: $description)';
  }
}
