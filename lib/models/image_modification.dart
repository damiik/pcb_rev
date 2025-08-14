class ImageModification {
  double rotation = 0; // in degrees
  bool flipHorizontal = false;
  bool flipVertical = false;
  double contrast = 0; // -1 to 1
  double brightness = 0; // -1 to 1
  bool invertColors = false;

  ImageModification();

  Map<String, dynamic> toJson() => {
    'rotation': rotation,
    'flipHorizontal': flipHorizontal,
    'flipVertical': flipVertical,
    'contrast': contrast,
    'brightness': brightness,
    'invertColors': invertColors,
  };

  factory ImageModification.fromJson(Map<String, dynamic> json) {
    final mod = ImageModification();
    mod.rotation = json['rotation'] ?? 0;
    mod.flipHorizontal = json['flipHorizontal'] ?? false;
    mod.flipVertical = json['flipVertical'] ?? false;
    mod.contrast = json['contrast'] ?? 0;
    mod.brightness = json['brightness'] ?? 0;
    mod.invertColors = json['invertColors'] ?? false;
    return mod;
  }
}
