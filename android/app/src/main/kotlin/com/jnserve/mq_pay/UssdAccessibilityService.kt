package com.jnserve.mq_pay

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import io.flutter.plugin.common.MethodChannel

class UssdAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "UssdAccessibility"
        var methodChannel: MethodChannel? = null
        var instance: UssdAccessibilityService? = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this

        val info = AccessibilityServiceInfo().apply {
            // Listen for all events
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                        AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED

            // Target all package names (to catch system USSD dialogs)
            packageNames = null

            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                   AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS

            notificationTimeout = 100
        }

        serviceInfo = info
        Log.d(TAG, "Accessibility service connected and configured")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        try {
            // Check if this is a USSD dialog
            val packageName = event.packageName?.toString() ?: return
            val className = event.className?.toString() ?: return

            Log.d(TAG, "Event - Package: $packageName, Class: $className")

            // USSD dialogs typically come from:
            // - com.android.phone
            // - android (system UI)
            // - AlertDialog or similar
            if (isUssdDialog(packageName, className)) {
                Log.d(TAG, "Potential USSD dialog detected!")

                when (event.eventType) {
                    AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                        handleUssdDialog(event)
                    }
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                        handleUssdContentChanged(event)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing accessibility event", e)
        }
    }

    private fun isUssdDialog(packageName: String, className: String): Boolean {
        // USSD dialogs commonly appear from these sources
        val ussdPackages = listOf(
            "com.android.phone",
            "android",
            "com.google.android.apps.telephony"
        )

        val ussdClassNames = listOf(
            "android.app.AlertDialog",
            "androidx.appcompat.app.AlertDialog",
            "android.app.Dialog"
        )

        return ussdPackages.any { packageName.contains(it, ignoreCase = true) } &&
               ussdClassNames.any { className.contains(it, ignoreCase = true) }
    }

    private fun handleUssdDialog(event: AccessibilityEvent) {
        Log.d(TAG, "Handling USSD dialog state change")

        // Notify Flutter that USSD dialog opened
        methodChannel?.invokeMethod("onUssdDialogOpened", null)

        // Extract text from the dialog
        val ussdText = extractTextFromEvent(event)
        if (ussdText.isNotEmpty()) {
            Log.d(TAG, "Extracted USSD text: $ussdText")
            sendUssdResponseToFlutter(ussdText)
        }
    }

    private fun handleUssdContentChanged(event: AccessibilityEvent) {
        // Content changed - might be a response update
        val ussdText = extractTextFromEvent(event)
        if (ussdText.isNotEmpty()) {
            Log.d(TAG, "USSD content updated: $ussdText")
            sendUssdResponseToFlutter(ussdText)
        }
    }

    private fun extractTextFromEvent(event: AccessibilityEvent): String {
        val textBuilder = StringBuilder()

        // Try to get text from the event itself
        event.text?.forEach { text ->
            if (text != null && text.isNotEmpty()) {
                textBuilder.append(text).append(" ")
            }
        }

        // If no text in event, try to traverse the node tree
        if (textBuilder.isEmpty()) {
            event.source?.let { rootNode ->
                extractTextFromNode(rootNode, textBuilder)
                rootNode.recycle()
            }
        }

        return textBuilder.toString().trim()
    }

    private fun extractTextFromNode(node: AccessibilityNodeInfo?, textBuilder: StringBuilder) {
        if (node == null) return

        try {
            // Get text from current node
            node.text?.let { text ->
                if (text.isNotEmpty()) {
                    textBuilder.append(text).append(" ")
                }
            }

            // Recursively extract from child nodes
            for (i in 0 until node.childCount) {
                extractTextFromNode(node.getChild(i), textBuilder)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error extracting text from node", e)
        }
    }

    private fun sendUssdResponseToFlutter(ussdText: String) {
        try {
            methodChannel?.invokeMethod("onUssdResponse", ussdText)
            Log.d(TAG, "Sent USSD response to Flutter: $ussdText")
        } catch (e: Exception) {
            Log.e(TAG, "Error sending USSD response to Flutter", e)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "Accessibility service interrupted")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        Log.d(TAG, "Accessibility service unbound")
        return super.onUnbind(intent)
    }
}
