package id.deckoflife.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Menerima teks/tautan dari Android Share Sheet (ACTION_SEND, text/plain) dan
 * meneruskannya ke Dart lewat MethodChannel. Tidak memakai plugin pihak ketiga.
 *
 * Yang diteruskan hanya yang benar-benar dikirim aplikasi sumber:
 *  - text    : EXTRA_TEXT
 *  - subject : EXTRA_SUBJECT atau EXTRA_TITLE (bila ada)
 * Aplikasi sumber tidak dilaporkan karena Android tidak menjaminnya.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String?>? = null
    private var initialHandled = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Setelah rotasi / recreate, intent awal dikirim ulang oleh sistem.
        // Jangan menangkap share yang sama dua kali.
        initialHandled = savedInstanceState != null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    val payload = pending ?: if (!initialHandled) extractShare(intent) else null
                    pending = null
                    initialHandled = true
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractShare(intent) ?: return
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("onShare", payload)
        } else {
            pending = payload
        }
    }

    private fun extractShare(intent: Intent?): Map<String, String?>? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (text.isNullOrBlank()) return null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: intent.getStringExtra(Intent.EXTRA_TITLE)
        return mapOf("text" to text, "subject" to subject)
    }

    companion object {
        const val CHANNEL = "deck_of_life/share"
    }
}
