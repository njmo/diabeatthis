enum ApplicationTheme {
  classic,
  cream;

  static ApplicationTheme fromName(String? name) =>
      values.firstWhere((theme) => theme.name == name, orElse: () => classic);
}
