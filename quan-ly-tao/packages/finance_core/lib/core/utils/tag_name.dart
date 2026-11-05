/// Stored without #; presentation adds the prefix. Never changes tag IDs.
String normalizeTagName(String value) {
  var result = value.toLowerCase();
  result = result.replaceAll(RegExp('[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
  result = result.replaceAll(RegExp('[èéẹẻẽêềếệểễ]'), 'e');
  result = result.replaceAll(RegExp('[ìíịỉĩ]'), 'i');
  result = result.replaceAll(RegExp('[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
  result = result.replaceAll(RegExp('[ùúụủũưừứựửữ]'), 'u');
  result = result.replaceAll(RegExp('[ỳýỵỷỹ]'), 'y');
  result = result.replaceAll(RegExp('[đ]'), 'd');
  return result.replaceAll(RegExp(r'[^a-z0-9]'), '');
}
