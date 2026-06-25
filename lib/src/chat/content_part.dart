import 'dart:convert';
import 'dart:io';

sealed class ContentPart {
  const ContentPart();

  Map<String, dynamic> toJson();
}

class TextPart extends ContentPart {
  const TextPart(this.text);

  final String text;

  @override
  Map<String, dynamic> toJson() => {'type': 'text', 'text': text};
}

class ImagePart extends ContentPart {
  const ImagePart.dataUrl(this.dataUrl);

  final String dataUrl;

  static Future<ImagePart> file(File file) async {
    if (!await file.exists()) {
      throw ArgumentError.value(file.path, 'file', 'File does not exist.');
    }
    final extension = file.path.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final encoded = base64Encode(await file.readAsBytes());
    return ImagePart.dataUrl('data:$mime;base64,$encoded');
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image_url',
    'image_url': {'url': dataUrl},
  };
}
