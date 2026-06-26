import 'dart:convert';
import 'dart:io';

enum ContentPartKind { text, image, audio, custom }

sealed class ContentPart {
  const ContentPart();

  ContentPartKind get kind;

  Map<String, dynamic> toJson();
}

class TextPart extends ContentPart {
  const TextPart(this.text);

  final String text;

  @override
  ContentPartKind get kind => ContentPartKind.text;

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
  ContentPartKind get kind => ContentPartKind.image;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'image_url',
    'image_url': {'url': dataUrl},
  };
}

class AudioPart extends ContentPart {
  const AudioPart.base64({required this.data, required this.format});

  final String data;
  final String format;

  static Future<AudioPart> file(File file, {String? format}) async {
    if (!await file.exists()) {
      throw ArgumentError.value(file.path, 'file', 'File does not exist.');
    }
    final extension = file.path.split('.').last.toLowerCase();
    final audioFormat =
        format ??
        switch (extension) {
          'mp3' => 'mp3',
          'm4a' => 'm4a',
          'flac' => 'flac',
          'aac' => 'aac',
          _ => 'wav',
        };
    final encoded = base64Encode(await file.readAsBytes());
    return AudioPart.base64(data: encoded, format: audioFormat);
  }

  @override
  ContentPartKind get kind => ContentPartKind.audio;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'input_audio',
    'input_audio': {'data': data, 'format': format},
  };
}
