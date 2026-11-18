package com.marantrix.hominode.resident

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Optional Android UPI activity result. An intent result is NOT bank evidence:
 * returned status/reference fields are advisory and must be Admin-verified.
 */
class MainActivity : FlutterActivity() {
    private val upiChannel = "hominode/upi"
    private val upiRequestCode = 7641
    private var pendingUpiResult: MethodChannel.Result? = null

    @Suppress("DEPRECATION")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, upiChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "launchPayment") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingUpiResult != null) {
                    result.error("IN_PROGRESS", "A UPI handoff is already active.", null)
                    return@setMethodCallHandler
                }
                val paymentUri = call.argument<String>("uri")
                if (paymentUri.isNullOrBlank() ||
                    !paymentUri.startsWith("upi://pay?", ignoreCase = true)) {
                    result.error("INVALID_URI", "Invalid UPI payment intent.", null)
                    return@setMethodCallHandler
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(paymentUri))
                    pendingUpiResult = result
                    startActivityForResult(intent, upiRequestCode)
                } catch (_: ActivityNotFoundException) {
                    pendingUpiResult = null
                    result.error("NO_UPI_APP", "No compatible UPI application was found.", null)
                } catch (_: Exception) {
                    pendingUpiResult = null
                    result.error("UPI_LAUNCH_FAILED", "UPI application could not be opened.", null)
                }
            }
    }

    @Deprecated("Android activity result callback for optional UPI app responses")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != upiRequestCode) return
        val result = pendingUpiResult ?: return
        pendingUpiResult = null
        // Apps differ widely: some return 'response', some separate extras, some nothing.
        val response = data?.getStringExtra("response")
            ?: data?.getStringExtra("Response")
            ?: ""
        val status = data?.getStringExtra("Status") ?: data?.getStringExtra("status") ?: ""
        val reference = data?.getStringExtra("txnId")
            ?: data?.getStringExtra("ApprovalRefNo")
            ?: data?.getStringExtra("txnRef")
            ?: ""
        result.success(mapOf(
            "returnedToApp" to true,
            "androidResultOk" to (resultCode == Activity.RESULT_OK),
            "response" to response.take(2048),
            "status" to status.take(64),
            "reference" to reference.take(200),
        ))
    }

    override fun onDestroy() {
        pendingUpiResult?.error("UPI_INTERRUPTED", "The UPI handoff was interrupted.", null)
        pendingUpiResult = null
        super.onDestroy()
    }
}
