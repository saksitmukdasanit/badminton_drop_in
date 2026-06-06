/// แปลงค่าจาก API response (รองรับทั้ง camelCase และ PascalCase)
int parseResponseBillId(Map<String, dynamic>? data) {
  if (data == null) return 0;
  final value = data['billId'] ?? data['BillId'];
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

String? parseResponseQrCode(Map<String, dynamic>? data) {
  if (data == null) return null;
  final value = data['qrCode'] ?? data['QrCode'];
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}
