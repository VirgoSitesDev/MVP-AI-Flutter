// Stub for non-web platforms
// This file provides dummy classes when dart:html is not available

class Blob {
  Blob(List data);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String href = '';
  String download = '';
  CssStyleDeclaration style = CssStyleDeclaration();

  void click() {}
}

class CssStyleDeclaration {
  String display = '';
}

class _Document {
  final _Body? body = _Body();

  dynamic createElement(String tag) => AnchorElement();
}

class _Body {
  final _Children children = _Children();
}

class _Children {
  void add(dynamic element) {}
  void remove(dynamic element) {}
}

final document = _Document();
