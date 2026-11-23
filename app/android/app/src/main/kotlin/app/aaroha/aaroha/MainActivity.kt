package app.aaroha.aaroha

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "aaroha/audio_route")
            .setMethodCallHandler { call, result ->
                if (call.method == "outputRoute") result.success(outputRoute()) else result.notImplemented()
            }
    }

    // Where media sound goes now: Android sends it to Bluetooth or wired
    // headphones whenever they are connected, else to the phone's speaker
    // (docs/08 M3-C).
    private fun outputRoute(): String {
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val types = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS).map { it.type }.toSet()
        val bluetooth = setOf(
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLE_HEADSET,
            AudioDeviceInfo.TYPE_BLE_SPEAKER,
            AudioDeviceInfo.TYPE_HEARING_AID,
        )
        val wired = setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
        )
        return when {
            types.any { it in bluetooth } -> "bluetooth"
            types.any { it in wired } -> "wired"
            else -> "speaker"
        }
    }
}
