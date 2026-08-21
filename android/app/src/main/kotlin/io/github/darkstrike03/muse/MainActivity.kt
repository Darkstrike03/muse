package io.github.darkstrike03.muse

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.torproject.jni.TorService
import java.io.File

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "muse/tor"
        const val DEFAULT_SHARE_PORT = 42800
    }

    private var boundService: TorService? = null
    private var serviceBound = false

    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            boundService = (binder as TorService.LocalBinder).getService()
        }

        override fun onServiceDisconnected(name: ComponentName) {
            boundService = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> startTor(call.argument<Int>("sharePort")
                        ?: DEFAULT_SHARE_PORT, result)
                    "stop" -> {
                        stopTor()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startTor(sharePort: Int, result: MethodChannel.Result) {
        try {
            writeTorrc(sharePort)
            val intent = Intent(this, MuseTorService::class.java)
            startForegroundService(intent)
            if (!serviceBound) {
                bindService(intent, connection, Context.BIND_AUTO_CREATE)
                serviceBound = true
            }
            // Poll for Tor to come up on a background thread, then reply.
            Thread {
                try {
                    val hostnameFile = File(torDataDir(this), "hidden_service/hostname")
                    var onion: String? = null
                    val deadline = System.currentTimeMillis() + 60_000
                    while (System.currentTimeMillis() < deadline) {
                        val service = boundService
                        if (service != null &&
                            service.getSocksPort() > 0 &&
                            hostnameFile.exists()
                        ) {
                            val candidate = hostnameFile
                                .readText()
                                .trim()
                                .removeSuffix(".onion")
                            if (candidate.length == 56) {
                                onion = candidate
                                break
                            }
                        }
                        Thread.sleep(1000)
                    }
                    if (onion == null) {
                        throw IllegalStateException("Tor did not start (no onion address)")
                    }
                    val socksPort = boundService?.getSocksPort() ?: 0
                    runOnUiThread {
                        result.success(mapOf("onion" to onion, "socksPort" to socksPort))
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        result.error("TOR_START_FAILED", e.message, null)
                    }
                }
            }.start()
        } catch (e: Exception) {
            result.error("TOR_START_FAILED", e.message, null)
        }
    }

    private fun stopTor() {
        if (serviceBound) {
            unbindService(connection)
            serviceBound = false
            boundService = null
        }
        stopService(Intent(this, MuseTorService::class.java))
    }

    private fun writeTorrc(sharePort: Int) {
        val dataDir = torDataDir(this)
        val hiddenDir = File(dataDir, "hidden_service")
        hiddenDir.mkdirs()
        File(torServiceDir(this), "torrc").writeText(
            "HiddenServiceDir ${hiddenDir.absolutePath}\n" +
                "HiddenServicePort 80 127.0.0.1:$sharePort\n"
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        if (serviceBound) {
            unbindService(connection)
            serviceBound = false
            boundService = null
        }
    }
}

private fun torServiceDir(context: Context): File =
    context.getDir("TorService", Context.MODE_PRIVATE)

private fun torDataDir(context: Context): File =
    File(torServiceDir(context), "data")