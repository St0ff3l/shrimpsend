package dev.ultrasend.app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * Resolves all URIs from a share/open [Intent] into local cache paths.
 * Used for [Intent.ACTION_SEND_MULTIPLE] and clipData-only senders that
 * [fl_shared_link] does not fully support.
 */
class ShareIntentBridge(
    private val activity: MainActivity,
) {
    companion object {
        const val CHANNEL = "dev.ultrasend/share_intent"
        private const val TAG = "ShareIntentBridge"
    }

    private var lastHandledIntentKey: String? = null

    fun register(messenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "resolveShareIntent" -> {
                try {
                    val intent = activity.intent
                    if (wasHandled(intent)) {
                        result.success(emptyList<String>())
                        return@onMethodCall
                    }
                    val cacheRoot = call.argument<String>("cacheRoot")
                    val paths = resolveShareIntent(intent, cacheRoot)
                    result.success(paths)
                } catch (e: Exception) {
                    Log.e(TAG, "resolveShareIntent failed: ${e.message}", e)
                    result.error("RESOLVE_FAILED", e.message, null)
                }
            }
            "getIntentDedupeKey" -> {
                result.success(intentDedupeKey(activity.intent))
            }
            "markShareIntentHandled" -> {
                markHandled(activity.intent)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    fun intentDedupeKey(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action ?: return null
        if (action != Intent.ACTION_SEND &&
            action != Intent.ACTION_SEND_MULTIPLE &&
            action != Intent.ACTION_VIEW
        ) {
            return null
        }
        val uris = collectUris(intent)
        if (uris.isEmpty()) return null
        val hashes = uris.map { it.toString().hashCode() }.sorted().joinToString(",")
        return "$action|$hashes"
    }

    fun wasHandled(intent: Intent?): Boolean {
        val key = intentDedupeKey(intent) ?: return false
        return lastHandledIntentKey == key
    }

    fun resolveShareIntent(intent: Intent?, cacheRoot: String? = null): List<String> {
        if (intent == null) return emptyList()
        val action = intent.action ?: return emptyList()
        // Single-file SEND/VIEW stays on fl_shared_link (WeChat/QQ optimized path).
        if (action != Intent.ACTION_SEND_MULTIPLE) {
            return emptyList()
        }

        val uris = collectUris(intent).distinctBy { it.toString() }
        if (uris.isEmpty()) return emptyList()

        val cacheDir = resolveCacheDir(cacheRoot)
        val useShareLayout = !cacheRoot.isNullOrBlank()
        val out = mutableListOf<String>()
        for (uri in uris) {
            resolveUriToCachePath(uri, cacheDir, useShareLayout)?.let { out.add(it) }
        }
        if (out.isNotEmpty()) {
            markHandled(intent)
        }
        return out
    }

    private fun resolveCacheDir(cacheRoot: String?): File {
        if (!cacheRoot.isNullOrBlank()) {
            val dir = File(cacheRoot)
            if (!dir.exists()) {
                dir.mkdirs()
            }
            return dir
        }
        return activity.externalCacheDir ?: activity.cacheDir
    }

    private fun markHandled(intent: Intent?) {
        lastHandledIntentKey = intentDedupeKey(intent)
        intent?.action = null
        intent?.replaceExtras(android.os.Bundle())
        intent?.clipData = null
        intent?.data = null
    }

    fun collectUris(intent: Intent): List<Uri> {
        val out = mutableListOf<Uri>()
        intent.data?.let { out.add(it) }
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let { out.add(it) }
            }
        }
        @Suppress("DEPRECATION")
        val stream: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        stream?.let { out.add(it) }
        @Suppress("DEPRECATION")
        val streams: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
        streams?.let { out.addAll(it) }
        return out
    }

    private fun resolveUriToCachePath(
        uri: Uri,
        cacheDir: File,
        useShareLayout: Boolean,
    ): String? {
        return when (uri.scheme) {
            ContentResolver.SCHEME_FILE -> uri.path?.let { File(it).absolutePath }
            ContentResolver.SCHEME_CONTENT -> copyContentUriToCache(uri, cacheDir, useShareLayout)
            else -> uri.path?.let { File(it).absolutePath }
                ?: copyContentUriToCache(uri, cacheDir, useShareLayout)
        }
    }

    private fun copyContentUriToCache(
        uri: Uri,
        cacheDir: File,
        useShareLayout: Boolean,
    ): String? {
        val displayName = queryDisplayName(uri) ?: "shared_${UUID.randomUUID()}"
        val safeName = sanitizeFileName(displayName)
        val targetDir = if (useShareLayout) {
            val messageDir = File(cacheDir, "share_${UUID.randomUUID()}")
            if (!messageDir.exists()) {
                messageDir.mkdirs()
            }
            messageDir
        } else {
            cacheDir
        }
        val target = uniqueCacheFile(targetDir, safeName, useShareLayout)
        return try {
            activity.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
            } ?: return null
            target.absolutePath
        } catch (e: Exception) {
            Log.w(TAG, "copyContentUriToCache failed for $uri: ${e.message}")
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val resolver = activity.contentResolver
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    return cursor.getString(index)
                }
            }
        }
        return uri.lastPathSegment
    }

    private fun sanitizeFileName(fileName: String): String {
        val cleaned = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_").trim()
        return cleaned.ifEmpty { "shared" }
    }

    private fun uniqueCacheFile(cacheDir: File, baseName: String, useShareLayout: Boolean): File {
        if (useShareLayout) {
            var candidate = File(cacheDir, baseName)
            if (!candidate.exists()) return candidate
            val dotIndex = baseName.lastIndexOf('.')
            val hasExt = dotIndex > 0 && dotIndex < baseName.length - 1
            val stem = if (hasExt) baseName.substring(0, dotIndex) else baseName
            val ext = if (hasExt) baseName.substring(dotIndex) else ""
            for (i in 1..9999) {
                candidate = File(cacheDir, "$stem ($i)$ext")
                if (!candidate.exists()) return candidate
            }
            return File(cacheDir, "${System.currentTimeMillis()}$ext")
        }

        val prefix = "share_${UUID.randomUUID().toString().take(8)}_"
        var candidate = File(cacheDir, prefix + baseName)
        if (!candidate.exists()) return candidate
        val dotIndex = baseName.lastIndexOf('.')
        val hasExt = dotIndex > 0 && dotIndex < baseName.length - 1
        val stem = if (hasExt) baseName.substring(0, dotIndex) else baseName
        val ext = if (hasExt) baseName.substring(dotIndex) else ""
        for (i in 1..9999) {
            candidate = File(cacheDir, prefix + "$stem ($i)$ext")
            if (!candidate.exists()) return candidate
        }
        return File(cacheDir, prefix + "${System.currentTimeMillis()}$ext")
    }
}
