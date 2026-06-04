package dev.ultrasend.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.documentfile.provider.DocumentFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.Locale

/**
 * Storage Access Framework (SAF) helpers for custom save directory on Android.
 * Persists document-tree URIs and mirrors received files into user-selected folders.
 */
class SafStorageHandler(private val activity: ComponentActivity) {
    private var pendingPickResult: MethodChannel.Result? = null

    private val pickTreeLauncher = activity.registerForActivityResult(
        ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        val pending = pendingPickResult
        pendingPickResult = null
        if (pending == null) return@registerForActivityResult
        if (result.resultCode != Activity.RESULT_OK) {
            pending.success(null)
            return@registerForActivityResult
        }
        val uri = result.data?.data
        if (uri == null) {
            pending.success(null)
            return@registerForActivityResult
        }
        try {
            val takeFlags = result.data?.flags?.and(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            ) ?: 0
            if (takeFlags != 0) {
                activity.contentResolver.takePersistableUriPermission(uri, takeFlags)
            }
            pending.success(uri.toString())
        } catch (e: Exception) {
            pending.error("PICK_FAILED", e.message, null)
        }
    }

    fun registerChannel(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickSaveTree" -> pickSaveTree(result)
                "probeWritable" -> {
                    val treeUri = call.argument<String>("treeUri")
                    if (treeUri.isNullOrBlank()) {
                        result.error("INVALID_ARG", "treeUri required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(probeWritable(treeUri))
                    } catch (e: Exception) {
                        result.error("PROBE_FAILED", e.message, null)
                    }
                }
                "getDisplayName" -> {
                    val treeUri = call.argument<String>("treeUri")
                    if (treeUri.isNullOrBlank()) {
                        result.error("INVALID_ARG", "treeUri required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(getDisplayName(treeUri))
                    } catch (e: Exception) {
                        result.error("NAME_FAILED", e.message, null)
                    }
                }
                "copyFileToTree" -> {
                    val treeUri = call.argument<String>("treeUri")
                    val sourcePath = call.argument<String>("sourcePath")
                    val displayName = call.argument<String>("displayName")
                    if (treeUri.isNullOrBlank() || sourcePath.isNullOrBlank() ||
                        displayName.isNullOrBlank()
                    ) {
                        result.error("INVALID_ARG", "treeUri/sourcePath/displayName required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(
                            copyFileToTree(treeUri, sourcePath, displayName),
                        )
                    } catch (e: Exception) {
                        result.error("COPY_FAILED", e.message, null)
                    }
                }
                "listFilesInTree" -> {
                    val treeUri = call.argument<String>("treeUri")
                    if (treeUri.isNullOrBlank()) {
                        result.error("INVALID_ARG", "treeUri required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(listFilesInTree(treeUri))
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", e.message, null)
                    } catch (e: Exception) {
                        result.error("LIST_FAILED", e.message, null)
                    }
                }
                "deleteFileInTree" -> {
                    val fileUri = call.argument<String>("fileUri")
                    if (fileUri.isNullOrBlank()) {
                        result.error("INVALID_ARG", "fileUri required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(deleteFileInTree(fileUri))
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", e.message, null)
                    } catch (e: Exception) {
                        result.error("DELETE_FAILED", e.message, null)
                    }
                }
                "copyFileUriToPath" -> {
                    val fileUri = call.argument<String>("fileUri")
                    val targetPath = call.argument<String>("targetPath")
                    if (fileUri.isNullOrBlank() || targetPath.isNullOrBlank()) {
                        result.error("INVALID_ARG", "fileUri/targetPath required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(copyFileUriToPath(fileUri, targetPath))
                    } catch (e: Exception) {
                        result.error("COPY_FAILED", e.message, null)
                    }
                }
                "restorePersistedTreeUris" -> {
                    restorePersistedTreeUris()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        restorePersistedTreeUris()
    }

    private fun pickSaveTree(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("BUSY", "Another picker is active", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        pickTreeLauncher.launch(intent)
    }

    private fun treeDocument(treeUri: String): DocumentFile {
        val uri = Uri.parse(treeUri)
        return DocumentFile.fromTreeUri(activity, uri)
            ?: throw IllegalStateException("Invalid tree URI: $treeUri")
    }

    private fun probeWritable(treeUri: String): Boolean {
        val tree = treeDocument(treeUri)
        val probeName = ".shrimpsend_probe_${System.nanoTime()}"
        val created = tree.createFile("application/octet-stream", probeName)
            ?: return false
        return created.delete()
    }

    private fun getDisplayName(treeUri: String): String {
        val tree = treeDocument(treeUri)
        tree.name?.takeIf { it.isNotBlank() }?.let { return it }
        return decodeTreeUriLabel(treeUri)
    }

    private fun decodeTreeUriLabel(treeUri: String): String {
        return try {
            val uri = Uri.parse(treeUri)
            val docId = DocumentsContract.getTreeDocumentId(uri)
            val decoded = Uri.decode(docId)
            decoded.substringAfter(':', decoded)
        } catch (_: Exception) {
            treeUri
        }
    }

    private fun copyFileToTree(
        treeUri: String,
        sourcePath: String,
        displayName: String,
    ): Map<String, String?> {
        val source = File(sourcePath)
        if (!source.isFile) {
            throw IllegalArgumentException("Source file not found: $sourcePath")
        }
        val tree = treeDocument(treeUri)
        val safeName = sanitizeFileName(displayName)
        val destName = uniqueNameInTree(tree, safeName)
        val mime = mimeTypeForName(destName)
        val dest = tree.createFile(mime, destName)
            ?: throw IllegalStateException("Could not create file in tree")
        activity.contentResolver.openOutputStream(dest.uri)?.use { output ->
            FileInputStream(source).use { input -> input.copyTo(output) }
        } ?: throw IllegalStateException("Could not open output stream")
        return mapOf(
            "displayName" to destName,
            "uri" to dest.uri.toString(),
        )
    }

    private fun uniqueNameInTree(tree: DocumentFile, baseName: String): String {
        if (!nameExistsInTree(tree, baseName)) return baseName
        val dotIndex = baseName.lastIndexOf('.')
        val hasExtension = dotIndex > 0 && dotIndex < baseName.length - 1
        val stem = if (hasExtension) baseName.substring(0, dotIndex) else baseName
        val extension = if (hasExtension) baseName.substring(dotIndex) else ""
        for (i in 1..9999) {
            val candidate = "$stem ($i)$extension"
            if (!nameExistsInTree(tree, candidate)) return candidate
        }
        return "$stem ${System.currentTimeMillis()}$extension"
    }

    private fun nameExistsInTree(tree: DocumentFile, name: String): Boolean {
        return tree.listFiles().any { it.name == name }
    }

    private fun listFilesInTree(treeUri: String): List<Map<String, Any?>> {
        val tree = treeDocument(treeUri)
        return tree.listFiles()
            .filter { it.isFile }
            .mapNotNull { file ->
                val name = file.name ?: return@mapNotNull null
                mapOf(
                    "name" to name,
                    "uri" to file.uri.toString(),
                    "size" to file.length(),
                    "lastModified" to file.lastModified(),
                )
            }
    }

    private fun deleteFileInTree(fileUri: String): Boolean {
        val doc = DocumentFile.fromSingleUri(activity, Uri.parse(fileUri))
            ?: return false
        return doc.delete()
    }

    private fun copyFileUriToPath(fileUri: String, targetPath: String): String {
        val source = DocumentFile.fromSingleUri(activity, Uri.parse(fileUri))
            ?: throw IllegalArgumentException("Invalid file URI: $fileUri")
        if (!source.isFile) {
            throw IllegalArgumentException("URI is not a file: $fileUri")
        }
        val target = File(targetPath)
        target.parentFile?.mkdirs()
        activity.contentResolver.openInputStream(source.uri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("Could not open input stream")
        return target.absolutePath
    }

    private fun sanitizeFileName(fileName: String): String {
        val cleaned = fileName.replace(Regex("""[\\/:*?"<>|]"""), "_").trim()
        return cleaned.ifEmpty { "received" }
    }

    private fun mimeTypeForName(fileName: String): String {
        val extension = fileName.substringAfterLast('.', "").lowercase(Locale.ROOT)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private fun restorePersistedTreeUris() {
        // Persisted grants are re-applied by the system; touch resolver to validate.
        activity.contentResolver.persistedUriPermissions
    }

    companion object {
        const val CHANNEL = "dev.ultrasend/saf_storage"
    }
}
