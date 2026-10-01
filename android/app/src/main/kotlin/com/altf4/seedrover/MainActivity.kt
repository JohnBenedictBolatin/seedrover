package com.altf4.seedrover

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.messaging.FirebaseMessaging

class MainActivity : FlutterActivity() {
    private val wifiPermissionRequestCode = 2401
    private val pushPermissionRequestCode = 2402
    private var roverWifiCallback: ConnectivityManager.NetworkCallback? = null
    private var pendingWifiResult: MethodChannel.Result? = null
    private var pendingWifiSsid: String? = null
    private var pendingWifiPassword: String? = null
    private var pendingPushPermissionResult: MethodChannel.Result? = null
    private var pendingPushRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        pendingPushRoute = routeFromIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seedrover/wifi"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectToRoverWifi" -> {
                    val ssid = call.argument<String>("ssid")
                    val password = call.argument<String>("password")
                    if (ssid.isNullOrBlank() || password.isNullOrBlank()) {
                        result.error("invalid_arguments", "Rover Wi-Fi settings are missing.", null)
                        return@setMethodCallHandler
                    }
                    connectToRoverWifi(ssid, password, result)
                }
                "disconnectFromRoverWifi" -> disconnectFromRoverWifi(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seedrover/push"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> requestPushPermission(
                    call.argument<Boolean>("requestIfDenied") == true,
                    result
                )
                "getPushToken" -> getPushToken(result)
                "consumePendingRoute" -> {
                    result.success(pendingPushRoute)
                    pendingPushRoute = null
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seedrover/push/tokenRefresh"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                SeedRoverPushEvents.tokenSink = events
            }

            override fun onCancel(arguments: Any?) {
                SeedRoverPushEvents.tokenSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seedrover/push/foregroundMessages"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                SeedRoverPushEvents.foregroundMessageSink = events
            }

            override fun onCancel(arguments: Any?) {
                SeedRoverPushEvents.foregroundMessageSink = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "seedrover/push/taps"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                SeedRoverPushEvents.notificationTapSink = events
            }

            override fun onCancel(arguments: Any?) {
                SeedRoverPushEvents.notificationTapSink = null
            }
        })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        routeFromIntent(intent)?.let { route ->
            if (SeedRoverPushEvents.notificationTapSink != null) {
                SeedRoverPushEvents.notificationTapped(route)
            } else {
                pendingPushRoute = route
            }
        }
    }

    private fun routeFromIntent(intent: Intent?): String? {
        return intent?.getStringExtra("route")
            ?: intent?.getStringExtra("deep_link")
    }

    private fun requestPushPermission(
        requestIfDenied: Boolean,
        result: MethodChannel.Result
    ) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (!requestIfDenied) {
            result.success(false)
            return
        }

        pendingPushPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            pushPermissionRequestCode
        )
    }

    private fun getPushToken(result: MethodChannel.Result) {
        try {
            FirebaseMessaging.getInstance().token.addOnCompleteListener(this) { task ->
                if (!task.isSuccessful) {
                    result.error(
                        "push_token_unavailable",
                        task.exception?.message ?: "Unable to obtain an FCM token.",
                        null
                    )
                } else {
                    result.success(task.result)
                }
            }
        } catch (error: Exception) {
            result.error("push_unavailable", error.message, null)
        }
    }

    private fun disconnectFromRoverWifi(result: MethodChannel.Result) {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        connectivity.bindProcessToNetwork(null)
        roverWifiCallback?.let { callback ->
            runCatching { connectivity.unregisterNetworkCallback(callback) }
        }
        roverWifiCallback = null
        result.success(true)
    }

    private fun connectToRoverWifi(
        ssid: String,
        password: String,
        result: MethodChannel.Result
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "unsupported_android_version",
                "Automatic rover Wi-Fi connection requires Android 10 or newer.",
                null
            )
            return
        }

        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.NEARBY_WIFI_DEVICES
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (checkSelfPermission(permission) != PackageManager.PERMISSION_GRANTED) {
            pendingWifiResult = result
            pendingWifiSsid = ssid
            pendingWifiPassword = password
            requestPermissions(arrayOf(permission), wifiPermissionRequestCode)
            return
        }

        requestRoverNetwork(ssid, password, result)
    }

    private fun requestRoverNetwork(
        ssid: String,
        password: String,
        result: MethodChannel.Result
    ) {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()
        var resultSent = false
        lateinit var callback: ConnectivityManager.NetworkCallback
        callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                connectivity.bindProcessToNetwork(network)
                roverWifiCallback = this
                if (!resultSent) {
                    resultSent = true
                    result.success(true)
                }
            }

            override fun onUnavailable() {
                if (roverWifiCallback === this) roverWifiCallback = null
                runCatching { connectivity.unregisterNetworkCallback(this) }
                if (!resultSent) {
                    resultSent = true
                    result.error(
                        "rover_wifi_unavailable",
                        "SeedRover-01 was not selected or could not be reached.",
                        null
                    )
                }
            }

            override fun onLost(network: Network) {
                connectivity.bindProcessToNetwork(null)
                if (roverWifiCallback === this) roverWifiCallback = null
            }
        }

        try {
            roverWifiCallback?.let { connectivity.unregisterNetworkCallback(it) }
            roverWifiCallback = callback
            connectivity.requestNetwork(request, callback, 30_000)
        } catch (error: Exception) {
            roverWifiCallback = null
            result.error("rover_wifi_connection_failed", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android API, retained for the Wi-Fi permission callback")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == pushPermissionRequestCode) {
            val result = pendingPushPermissionResult
            pendingPushPermissionResult = null
            result?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            )
            return
        }
        if (requestCode != wifiPermissionRequestCode) return

        val result = pendingWifiResult
        val ssid = pendingWifiSsid
        val password = pendingWifiPassword
        pendingWifiResult = null
        pendingWifiSsid = null
        pendingWifiPassword = null
        if (result == null || ssid == null || password == null) return

        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            requestRoverNetwork(ssid, password, result)
        } else {
            result.error(
                "wifi_permission_denied",
                "Nearby Wi-Fi permission is needed to find SeedRover-01.",
                null
            )
        }
    }

    override fun onDestroy() {
        val connectivity = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        roverWifiCallback?.let {
            connectivity.bindProcessToNetwork(null)
            runCatching { connectivity.unregisterNetworkCallback(it) }
        }
        roverWifiCallback = null
        super.onDestroy()
    }
}
