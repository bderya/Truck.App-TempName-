/// User-facing error messages in simple Turkish (non-technical).
class ErrorMessagesTr {
  ErrorMessagesTr._();

  /// Converts exception or technical message to a short Turkish explanation.
  static String from(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('socket') || s.contains('connection') || s.contains('network') || s.contains('connection refused')) {
      return 'Bağlantı sorunu oluştu. İnternet bağlantınızı kontrol edin.';
    }
    if (s.contains('timeout') || s.contains('timed out')) {
      return 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin.';
    }
    if (s.contains('unauthorized') || s.contains('401')) {
      return 'Oturum süreniz dolmuş olabilir. Lütfen tekrar giriş yapın.';
    }
    if (s.contains('forbidden') || s.contains('403')) {
      return 'Bu işlem için yetkiniz yok.';
    }
    if (s.contains('not found') || s.contains('404')) {
      return 'İstenen sayfa veya bilgi bulunamadı.';
    }
    if (s.contains('server') || s.contains('500') || s.contains('502') || s.contains('503')) {
      return 'Sunucu geçici olarak yanıt veremiyor. Lütfen kısa süre sonra tekrar deneyin.';
    }
    if (s.contains('insufficient') || s.contains('bakiye')) {
      return 'Yetersiz bakiye. Lütfen başka kart deneyin veya bakiye ekleyin.';
    }
    if (s.contains('declined') || s.contains('reddedildi')) {
      return 'Kartınız reddedildi. Lütfen başka kart deneyin.';
    }
    if (s.contains('expired') || s.contains('süresi dolmuş')) {
      return 'Kartınızın süresi dolmuş. Lütfen ödeme yöntemini güncelleyin.';
    }
    if (s.contains('invalid') || s.contains('geçersiz')) {
      return 'Girilen bilgiler geçersiz. Lütfen kontrol edip tekrar deneyin.';
    }
    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }

  static const String offline = 'İnternet bağlantısı yok. Yeniden bağlanmaya çalışılıyor...';
  static const String paymentFailed = 'Ödeme işlemi başarısız oldu.';
  static const String updatePaymentMethod = 'Ödeme Yöntemini Güncelle';
  static const String stillSearchingTitle = 'Hala arıyoruz';
  static const String stillSearchingBody =
      'Bir sürücü bulunamadı. Beklemeye devam etmek ister misiniz yoksa destek hattımızı mı arayalım?';
  static const String keepWaiting = 'Beklemeye devam et';
  static const String callSupport = 'Destek hattını ara';
}
