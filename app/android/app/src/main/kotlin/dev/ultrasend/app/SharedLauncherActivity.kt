package dev.ultrasend.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity

/**
 * Receives [Intent.ACTION_SEND] / [Intent.ACTION_SEND_MULTIPLE] / [Intent.ACTION_VIEW] in a
 * separate task so QQ/WeChat/Telegram task stacks are not replaced when sharing into the app
 * (see fl_shared_link docs). Forwards the intent to [MainActivity] **preserving flags, clipData,
 * extras, and granting URI read permission** so the receiver can actually open the stream.
 *
 * Combined with `noHistory + excludeFromRecents` in the manifest and the
 * `CLEAR_TOP | SINGLE_TOP` flags below, the existing `MainActivity` instance is reused
 * (`onNewIntent`) instead of spawning a new one for every share.
 */
class SharedLauncherActivity : ComponentActivity() {

    companion object {
        private const val TAG = "ShareLauncher"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Do the forwarding as early as possible so the relay window is not user-visible.
        forwardToMain(intent, source = "onCreate")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        forwardToMain(intent, source = "onNewIntent")
    }

    private fun forwardToMain(original: Intent?, source: String) {
        if (original == null) {
            Log.w(TAG, "$source: no intent, finishing")
            finish()
            return
        }
        logIncoming(original, source)

        // Clone the whole intent (action / data / type / extras / flags / clipData) and only
        // change the target component. This is critical for FLAG_GRANT_READ_URI_PERMISSION to
        // carry over so MainActivity (and Flutter plugins) can openInputStream on QQ/WeChat URIs.
        //
        // NEW_TASK + CLEAR_TOP + SINGLE_TOP ensure the existing MainActivity instance in the
        // virtual task (default affinity) is brought to front and receives onNewIntent rather
        // than a fresh instance being created for every share.
        val forwarded = Intent(original).apply {
            setClass(this@SharedLauncherActivity, MainActivity::class.java)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            // Re-assert URI read perm on the new intent in case the original missed it.
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        // For some senders (e.g. WeChat) the temporary grant is only valid for the receiver
        // component the system resolved. After we forward, also grant explicitly to our own
        // package so the plugin can read the URI.
        grantUriPermissionsToSelf(original)

        try {
            startActivity(forwarded)
            Log.i(
                TAG,
                "$source: forwarded to MainActivity action=${forwarded.action} type=${forwarded.type} " +
                    "data=${forwarded.data} flags=0x${Integer.toHexString(forwarded.flags)} " +
                    "extras=${forwarded.extras?.keySet()?.toList()}",
            )
        } catch (e: Throwable) {
            Log.e(TAG, "$source: startActivity failed: ${e.message}", e)
        } finally {
            finish()
        }
    }

    private fun grantUriPermissionsToSelf(intent: Intent) {
        val pkg = packageName
        val toGrant = mutableListOf<Uri>()
        intent.data?.let { toGrant.add(it) }
        intent.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let { toGrant.add(it) }
            }
        }
        @Suppress("DEPRECATION")
        val stream: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        stream?.let { toGrant.add(it) }
        @Suppress("DEPRECATION")
        val streams: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        }
        streams?.let { toGrant.addAll(it) }

        for (uri in toGrant.distinct()) {
            try {
                grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                Log.d(TAG, "granted READ to $pkg for $uri")
            } catch (e: Throwable) {
                Log.w(TAG, "grantUriPermission failed for $uri: ${e.message}")
            }
        }
    }

    private fun logIncoming(intent: Intent, source: String) {
        val data = intent.data
        val clip = intent.clipData
        val clipUris = mutableListOf<Uri>()
        if (clip != null) {
            for (i in 0 until clip.itemCount) {
                clip.getItemAt(i).uri?.let { clipUris.add(it) }
            }
        }
        Log.i(
            TAG,
            "$source: incoming action=${intent.action} type=${intent.type} data=$data " +
                "scheme=${data?.scheme} authority=${data?.authority} " +
                "flags=0x${Integer.toHexString(intent.flags)} " +
                "clipItems=${clipUris.size} extras=${intent.extras?.keySet()?.toList()}",
        )
        if (clipUris.isNotEmpty()) {
            Log.i(TAG, "$source: clipData uris=$clipUris")
        }
    }
}
