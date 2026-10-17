// (a linha "package" é copiada do MainActivity gerado pelo flutter create)
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Canais de notificação: avisos gerais e SOS (alarme, vibração forte).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            val general = NotificationChannel("meupet", "Avisos do Meu Pet+", NotificationManager.IMPORTANCE_HIGH)
            general.description = "Mensagens, agendamentos, receitas, corridas e pedidos"
            nm.createNotificationChannel(general)
            val sos = NotificationChannel("sos", "Emergências (SOS)", NotificationManager.IMPORTANCE_HIGH)
            sos.description = "Chamados de emergência para clínicas 24h"
            sos.enableVibration(true)
            sos.vibrationPattern = longArrayOf(0, 700, 300, 700, 300, 700)
            sos.setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            nm.createNotificationChannel(sos)
        }
    }
}
