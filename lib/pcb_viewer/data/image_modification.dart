typedef ImageModification = ({
  double rotation,
  bool flipHorizontal,
  bool flipVertical,
  double contrast,
  double brightness,
  bool invertColors
});

ImageModification createDefaultImageModification() => (
      rotation: 0.0,
      flipHorizontal: false,
      flipVertical: false,
      contrast: 0.0,
      brightness: 0.0,
      invertColors: false,
    );

Map<String, dynamic> imageModificationToJson(ImageModification m) => {
      'rotation': m.rotation,
      'flipHorizontal': m.flipHorizontal,
      'flipVertical': m.flipVertical,
      'contrast': m.contrast,
      'brightness': m.brightness,
      'invertColors': m.invertColors,
    };

ImageModification imageModificationFromJson(Map<String, dynamic> json) => (
      rotation: json['rotation'] as double,
      flipHorizontal: json['flipHorizontal'] as bool,
      flipVertical: json['flipVertical'] as bool,
      contrast: json['contrast'] as double,
      brightness: json['brightness'] as double,
      invertColors: json['invertColors'] as bool,
    );

extension ImageModificationCopyWith on ImageModification {
  ImageModification copyWith({
    double? rotation,
    bool? flipHorizontal,
    bool? flipVertical,
    double? contrast,
    double? brightness,
    bool? invertColors,
  }) {
    return (
      rotation: rotation ?? this.rotation,
      flipHorizontal: flipHorizontal ?? this.flipHorizontal,
      flipVertical: flipVertical ?? this.flipVertical,
      contrast: contrast ?? this.contrast,
      brightness: brightness ?? this.brightness,
      invertColors: invertColors ?? this.invertColors,
    );
  }
}
