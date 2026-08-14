package com.example.everafter

import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), NfcAdapter.ReaderCallback {
    companion object {
        private const val channelName = "com.example.everafter/nfc"
        private const val scanTimeoutMillis = 60_000L
    }

    private var nfcAdapter: NfcAdapter? = null
    private var pendingScan: MethodChannel.Result? = null
    private val timeoutHandler = Handler(Looper.getMainLooper())
    private val timeoutRunnable = Runnable {
        finishWithError(
            "scan_timeout",
            "No magnet was found. Move the back of your phone closer and try again.",
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "scanMagnet") {
                    startMagnetScan(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun startMagnetScan(result: MethodChannel.Result) {
        val adapter = nfcAdapter
        if (adapter == null) {
            result.error(
                "unavailable",
                "NFC scanning is not available on this Android phone.",
                null,
            )
            return
        }
        if (!adapter.isEnabled) {
            result.error(
                "disabled",
                "Turn on NFC in Android Settings, then try again.",
                null,
            )
            return
        }
        if (pendingScan != null) {
            result.error(
                "already_scanning",
                "EverAfter is already looking for a magnet.",
                null,
            )
            return
        }

        pendingScan = result
        timeoutHandler.postDelayed(timeoutRunnable, scanTimeoutMillis)

        try {
            adapter.enableReaderMode(
                this,
                this,
                NfcAdapter.FLAG_READER_NFC_A or
                    NfcAdapter.FLAG_READER_NFC_B or
                    NfcAdapter.FLAG_READER_NFC_F or
                    NfcAdapter.FLAG_READER_NFC_V or
                    NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
                Bundle(),
            )
        } catch (_: RuntimeException) {
            finishWithError(
                "scan_failed",
                "EverAfter could not start the Android NFC reader.",
            )
        }
    }

    override fun onTagDiscovered(tag: Tag) {
        val identifier = tag.id
        if (identifier == null || identifier.isEmpty()) {
            runOnUiThread {
                finishWithError(
                    "unsupported_tag",
                    "This magnet does not expose a readable NFC identifier.",
                )
            }
            return
        }

        val uid = identifier.joinToString(":") { byte -> "%02X".format(byte.toInt() and 0xFF) }
        runOnUiThread { finishWithValue(uid) }
    }

    override fun onPause() {
        if (pendingScan != null) {
            finishWithError("cancelled", "The NFC scan was cancelled.")
        }
        super.onPause()
    }

    override fun onDestroy() {
        if (pendingScan != null) {
            finishWithError("cancelled", "The NFC scan was cancelled.")
        }
        super.onDestroy()
    }

    private fun finishWithValue(uid: String) {
        val result = pendingScan ?: return
        stopReader()
        pendingScan = null
        result.success(uid)
    }

    private fun finishWithError(code: String, message: String) {
        val result = pendingScan ?: return
        stopReader()
        pendingScan = null
        result.error(code, message, null)
    }

    private fun stopReader() {
        timeoutHandler.removeCallbacks(timeoutRunnable)
        try {
            nfcAdapter?.disableReaderMode(this)
        } catch (_: RuntimeException) {
            // The activity can already be paused while a pending scan is cancelled.
        }
    }
}
