package com.yourcompany.janus_mobile

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class Application : FlutterApplication(), PluginRegistrantCallback {
    override fun onCreate() {
        super.onCreate()
        //FlutterFirebaseMessagingService.setPluginRegistrant(this);
    }
    override fun registerWith(registry: PluginRegistry?) {
        io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin.registerWith(registry?.registrarFor("io.flutter.plugins.firebasemessaging.FirebaseMessagingPlugin"));
    }
}