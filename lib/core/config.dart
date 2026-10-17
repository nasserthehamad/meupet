/// Endereços públicos dos serviços grátis usados pelo app (não são segredos).
class AppConfig {
  /// Cloudinary: nome da conta e "upload preset" sem assinatura (arquivos do chat e exames).
  static const cloudinaryCloud = String.fromEnvironment('CLOUDINARY_CLOUD', defaultValue: '');
  static const cloudinaryPreset = String.fromEnvironment('CLOUDINARY_PRESET', defaultValue: 'meupet');

  /// Cloudflare Worker que envia as notificações (FCM).
  static const pushUrl = String.fromEnvironment('PUSH_URL', defaultValue: '');
}
