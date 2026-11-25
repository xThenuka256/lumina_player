package dev.lumina.player

import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import androidx.documentfile.provider.DocumentFile
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private val channelName = "dev.lumina.player/mediastore"
    private val supportedExtensions = setOf("mp3", "flac", "wav", "ogg", "m4a")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "queryAudioTracks" -> {
                        Thread {
                            val tracks = queryMediaStoreAudio()
                            Handler(Looper.getMainLooper()).post {
                                result.success(tracks)
                            }
                        }.start()
                    }
                    "querySafFolder" -> {
                        val treeUri = call.argument<String>("treeUri")
                        if (treeUri.isNullOrEmpty()) {
                            result.success(emptyList<Map<String, Any?>>())
                        } else {
                            Thread {
                                val tracks = querySafTree(treeUri)
                                Handler(Looper.getMainLooper()).post {
                                    result.success(tracks)
                                }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getArtCacheDir(): File {
        val dir = File(cacheDir, "art_cache")
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun cacheThumbnailForTrack(contentUri: Uri, cacheKey: String): String? {
        val outFile = File(getArtCacheDir(), "$cacheKey.jpg")
        if (outFile.exists() && outFile.length() > 0) return outFile.absolutePath

        return try {
            val bitmap: Bitmap = contentResolver.loadThumbnail(contentUri, Size(512, 512), null)
            FileOutputStream(outFile).use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 88, stream)
            }
            outFile.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun queryMediaStoreAudio(): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.RELATIVE_PATH,
            MediaStore.Audio.Media.DATE_ADDED
        )

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        try {
            contentResolver.query(collection, projection, selection, null, sortOrder)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val trackCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
                val displayCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
                val relPathCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.RELATIVE_PATH)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val displayName = cursor.getString(displayCol) ?: ""
                    val ext = displayName.substringAfterLast('.', "").lowercase()
                    val mimeType = cursor.getString(mimeCol) ?: ""
                    if (ext !in supportedExtensions && !mimeType.startsWith("audio/")) {
                        continue
                    }

                    val contentUri = ContentUris.withAppendedId(collection, id)
                    val albumId = cursor.getLong(albumIdCol)
                    val artPath = cacheThumbnailForTrack(contentUri, "album_$albumId")
                    val rawTrack = cursor.getInt(trackCol)
                    val trackNum = if (rawTrack >= 1000) rawTrack % 1000 else rawTrack
                    val relPath = (cursor.getString(relPathCol) ?: "Music/").trimEnd('/')

                    results.add(
                        mapOf(
                            "uri" to contentUri.toString(),
                            "title" to (cursor.getString(titleCol) ?: displayName),
                            "artist" to (cursor.getString(artistCol) ?: "Unknown Artist"),
                            "album" to (cursor.getString(albumCol) ?: "Unknown Album"),
                            "albumArtist" to (cursor.getString(artistCol) ?: "Unknown Artist"),
                            "durationMs" to cursor.getLong(durationCol).toInt(),
                            "trackNumber" to trackNum,
                            "folderPath" to relPath,
                            "displayName" to displayName,
                            "mimeType" to mimeType,
                            "artworkPath" to artPath,
                            "dateAddedMs" to (cursor.getLong(dateCol) * 1000L).toInt()
                        )
                    )
                }
            }
        } catch (_: Exception) {
            // Permission may have been revoked mid-scan
        }
        return results
    }

    private fun querySafTree(treeUriString: String): List<Map<String, Any?>> {
        val results = mutableListOf<Map<String, Any?>>()
        val uri = Uri.parse(treeUriString)
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
            // Ignore if URI does not support persistable grants
        }

        val root = DocumentFile.fromTreeUri(this, uri) ?: return results
        walkDocumentTree(root, root.name ?: "SAF Folder", results)
        return results
    }

    private fun walkDocumentTree(
        dir: DocumentFile,
        folderLabel: String,
        out: MutableList<Map<String, Any?>>
    ) {
        for (child in dir.listFiles()) {
            if (child.isDirectory) {
                walkDocumentTree(child, "$folderLabel/${child.name ?: ""}", out)
            } else if (child.isFile) {
                val name = child.name ?: continue
                val ext = name.substringAfterLast('.', "").lowercase()
                if (ext !in supportedExtensions) continue

                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(this, child.uri)
                    val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                        ?: name.substringBeforeLast('.')
                    val artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                        ?: "Unknown Artist"
                    val album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                        ?: "Unknown Album"
                    val durMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                        ?.toIntOrNull() ?: 0
                    val trackNum = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)
                        ?.substringBefore('/')?.toIntOrNull() ?: 0

                    var artPath: String? = null
                    val embedded = retriever.embeddedPicture
                    if (embedded != null && embedded.isNotEmpty()) {
                        val file = File(getArtCacheDir(), "saf_${child.uri.toString().hashCode()}.jpg")
                        if (!file.exists()) {
                            file.writeBytes(embedded)
                        }
                        artPath = file.absolutePath
                    }

                    out.add(
                        mapOf(
                            "uri" to child.uri.toString(),
                            "title" to title,
                            "artist" to artist,
                            "album" to album,
                            "albumArtist" to artist,
                            "durationMs" to durMs,
                            "trackNumber" to trackNum,
                            "folderPath" to folderLabel,
                            "displayName" to name,
                            "mimeType" to (child.type ?: "audio/*"),
                            "artworkPath" to artPath,
                            "dateAddedMs" to child.lastModified().toInt()
                        )
                    )
                } catch (_: Exception) {
                    // Skip unreadable entry
                } finally {
                    retriever.release()
                }
            }
        }
    }
}
