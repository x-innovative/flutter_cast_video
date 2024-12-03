package it.aesys.flutter_cast_video

import android.content.Context
import android.net.Uri
import android.view.ContextThemeWrapper
import android.view.View
import androidx.mediarouter.app.MediaRouteButton
import com.google.android.gms.cast.*
import com.google.android.gms.cast.framework.*
import com.google.android.gms.cast.framework.media.RemoteMediaClient
import com.google.android.gms.common.api.PendingResult
import com.google.android.gms.common.api.Status
import com.google.android.gms.common.images.WebImage
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import org.json.JSONArray
import org.json.JSONObject
import java.lang.Exception


class ChromeCastController(
	messenger: BinaryMessenger, viewId: Int, context: Context?
) : PlatformView, MethodChannel.MethodCallHandler, SessionManagerListener<Session>,
	PendingResult.StatusListener {
	private val channel = MethodChannel(messenger, "flutter_cast_video/chromeCast_$viewId")
	private val chromeCastButton =
		MediaRouteButton(ContextThemeWrapper(context, R.style.Theme_AppCompat_NoActionBar))
	private var sessionManager : SessionManager? = null

	init {
		CastButtonFactory.setUpMediaRouteButton(context as Context, chromeCastButton)
		chromeCastButton.visibility = View.GONE
		channel.setMethodCallHandler(this)
		try {
			sessionManager = CastContext.getSharedInstance()?.sessionManager
		} catch (ignored: Exception){}
	}

	private fun loadMedia(args: Any?) {
		if (args is Map<*, *>) {
			val url = args["url"] as? String ?: ""
			val title = args["title"] as? String ?: ""
			val subtitle = args["subtitle"] as? String ?: ""
			val imageUrl = args["image"] as? String ?: ""
			val contentType = args["contentType"] as? String ?: "videos/mp4"
			val hlsVideoSegmentFormat = args["hlsVideoSegmentFormat"] as? Int ?: 0
			val customData = (args["customData"] as Map<*, *>?)?.run {
				JSONObject(this)
			} ?: JSONObject()
			
			val liveStream = args["live"] as? Boolean ?: false

			val movieMetadata = MediaMetadata(MediaMetadata.MEDIA_TYPE_MOVIE)

			val streamType =
				if (liveStream) MediaInfo.STREAM_TYPE_LIVE else MediaInfo.STREAM_TYPE_BUFFERED

			movieMetadata.putString(MediaMetadata.KEY_TITLE, title)
			movieMetadata.putString(MediaMetadata.KEY_SUBTITLE, subtitle)
			movieMetadata.addImage(WebImage(Uri.parse(imageUrl)))
			//movieMetadata.addImage(WebImage(Uri.parse(imageUrl)))

			val media = MediaInfo.Builder(url).setStreamType(streamType).setContentType(contentType)
				.setMetadata(movieMetadata).setCustomData(customData).build()
			val options = MediaLoadOptions.Builder().setCustomData(customData).build()
			val request =
				sessionManager?.currentCastSession?.remoteMediaClient?.load(media, options)

			request?.addStatusListener(this)
		}
	}

	private fun play() {
		val request = sessionManager?.currentCastSession?.remoteMediaClient?.play()
		request?.addStatusListener(this)
	}

	private fun pause() {
		val request = sessionManager?.currentCastSession?.remoteMediaClient?.pause()
		request?.addStatusListener(this)
	}

	/*private fun mediaQueue(args: Any?) : List<HashMap<String,String>>{
	   val items : List<HashMap<String,String>> = mutableListOf()
		val client = sessionManager?.currentCastSession?.remoteMediaClient ?: return items
	   val queue = client.getMediaQueue()
	   val status = client.mediaStatus
	   val qlen = queue.getItemCount()

	   var start = 0
	   var batch = 5
	   var page = 1;
	   if (args is Map<*, *>) {
		   batch = (args["batch"] as? Int) ?: batch
		   page = (args["page"] as? Int) ?: page
	   }
		start = page * batch
		var end = (page+1) * batch
		if (start >= qlen){
			return items
		}
		if (end > qlen){
			end = qlen
		}
		batch = end - start

		var ret = queue.fetchMoreItemsRelativeToIndex(start, batch, 0)
		ret.setResultCallback {

		}
	}
	 */
	private fun seek(args: Any?) {
		if (args is Map<*, *>) {
			val relative = (args["relative"] as? Boolean) ?: false
			var interval = args["interval"] as? Double
			interval = interval?.times(1000)
			if (relative) {
				interval = interval?.plus(
					sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.streamPosition
						?: 0
				)
			}
			val request = sessionManager?.currentCastSession?.remoteMediaClient?.seek(
				MediaSeekOptions.Builder().setPosition(interval?.toLong() ?: 0).build()
			)
			request?.addStatusListener(this)
		}
	}

	private fun mediaInfoToMap(mediaInfo: MediaInfo?): HashMap<String, Any?>? {
		return mediaInfo?.let {
			val info = hashMapOf<String, Any?>()
			val id = mediaInfo.contentId
			info["id"] = id
			info["url"] = mediaInfo.contentUrl ?: id
			info["contentType"] = mediaInfo.contentType ?: ""
			info["customData"] = mediaInfo.customData?.toMap()
			info["audioTracks"] =
				mediaInfo.mediaTracks?.filter { track -> track.type == MediaTrack.TYPE_AUDIO }
					?.map { track -> track.language }?.toList()
			info["subtitleTracks"] =
				mediaInfo.mediaTracks?.filter { track -> track.type == MediaTrack.TYPE_TEXT || track.subtype == MediaTrack.SUBTYPE_SUBTITLES }
					?.map { track -> track.language }?.toList()
			mediaInfo.metadata?.apply {
				info["title"] = getString(MediaMetadata.KEY_TITLE) ?: ""
				info["subtitle"] = getString(MediaMetadata.KEY_SUBTITLE) ?: ""
				val imgs = images
				if (imgs.size > 0) {
					info["image"] = imgs[0].url.toString()
				}
			}

			info
		}
	}

	private fun getMediaInfo(): HashMap<String, Any?>? =
		mediaInfoToMap(sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo)


	private fun setVolume(args: Any?) {
		if (args is Map<*, *>) {
			val volume = args["volume"] as? Double
			val request = sessionManager?.currentCastSession?.remoteMediaClient?.setStreamVolume(
				volume ?: 0.0
			)
			request?.addStatusListener(this)
		}
	}

	private fun getVolume() = sessionManager?.currentCastSession?.volume ?: 0.0

	private fun stop() {
		val request = sessionManager?.currentCastSession?.remoteMediaClient?.stop()
		request?.addStatusListener(this)
	}

	private fun isPlaying() =
		sessionManager?.currentCastSession?.remoteMediaClient?.isPlaying ?: false

	private fun isConnected() = sessionManager?.currentCastSession?.isConnected ?: false

	private fun endSession() = sessionManager?.endCurrentSession(true)

	private fun position() =
		sessionManager?.currentCastSession?.remoteMediaClient?.approximateStreamPosition ?: 0

	private fun duration() =
		sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo?.streamDuration ?: 0

	private fun getSubtitleTrack() =
		sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo?.mediaTracks?.filter { track -> track.type == MediaTrack.TYPE_TEXT || track.subtype == MediaTrack.SUBTYPE_SUBTITLES }
			?.let { tracks ->
				sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.activeTrackIds?.toList()
					?.let { ids ->
						tracks.firstOrNull { track -> ids.contains(track.id) }?.language ?: ""
					}

			}

	private fun getAudioTrackLang() =
		sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo?.mediaTracks?.filter { track -> track.type == MediaTrack.TYPE_AUDIO }
			?.let { tracks ->
				sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.activeTrackIds?.toList()
					?.let { ids ->
						tracks.firstOrNull { track -> ids.contains(track.id) }?.language ?: ""
					}

			}

	private fun setSubtitleTrack(args: Any?) = (args as Map<*, *>?)?.apply {
		(this["lang"] as String?)?.let { lang ->
			sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo?.mediaTracks?.filter { track -> track.type == MediaTrack.TYPE_TEXT || track.subtype == MediaTrack.SUBTYPE_SUBTITLES }
				?.also { tracks ->
					if(lang.isEmpty()) {
						sessionManager?.currentCastSession?.remoteMediaClient?.apply {
							setActiveMediaTracks(
								LongArray(0)
							).addStatusListener { status -> onComplete(status) }
						}
					} else if (tracks.isNotEmpty()) {
						tracks.firstOrNull { track -> track.language == lang }?.also { track ->

							(sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.activeTrackIds?.toMutableList()
								?: mutableListOf()).also { ids ->
								ids.removeAll(tracks.map { track -> track.id }.toSet())
								ids.add(track.id)

								sessionManager?.currentCastSession?.remoteMediaClient?.apply {
									setActiveMediaTracks(
										ids.toLongArray()
									).addStatusListener { status -> onComplete(status) }
								}
							}
						}
					}
				}
		}
	}


	private fun setAudioTrack(args: Any?) = (args as Map<*, *>?)?.apply {
		(this["lang"] as String?)?.let { lang ->
			sessionManager?.currentCastSession?.remoteMediaClient?.mediaInfo?.mediaTracks?.filter { track -> track.type == MediaTrack.TYPE_AUDIO }
				?.also { tracks ->
					if (tracks.isNotEmpty()) {
						tracks.firstOrNull { track -> track.language == lang }?.also { track ->

							(sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.activeTrackIds?.toMutableList()
								?: mutableListOf()).also { ids ->
								ids.removeAll(tracks.map { track -> track.id }.toSet())
								ids.add(track.id)

								sessionManager?.currentCastSession?.remoteMediaClient?.apply {
									setActiveMediaTracks(
										ids.toLongArray()
									).addStatusListener { status -> onComplete(status) }
								}
							}
						}
					}
				}
		}
	}


	private fun getPlaybackRate() =
		sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus?.playbackRate

	private fun setPlaybackRate(args: Any?) = (args as Map<*, *>?)?.apply {
		(this["rate"] as Double?)?.apply {
			sessionManager?.currentCastSession?.remoteMediaClient?.setPlaybackRate(this)
				?.addStatusListener { status -> onComplete(status) }
		}
	}


	private fun addSessionListener() {
		sessionManager?.addSessionManagerListener(this)
		if (isConnected()) {
			onSessionStarted(sessionManager!!.currentCastSession!!, "");
		}
	}

	private fun removeSessionListener() {
		sessionManager?.removeSessionManagerListener(this)
		sessionManager?.currentCastSession?.remoteMediaClient?.unregisterCallback(
			mRemoteMediaClientListener
		)
	}

	private val mRemoteMediaClientListener: RemoteMediaClient.Callback =
		object : RemoteMediaClient.Callback() {
			override fun onStatusUpdated() {
				val mediaStatus: MediaStatus? =
					sessionManager?.currentCastSession?.remoteMediaClient?.mediaStatus
				val retCode = when (mediaStatus?.playerState ?: MediaStatus.PLAYER_STATE_UNKNOWN) {
					MediaStatus.PLAYER_STATE_BUFFERING -> 0
					MediaStatus.PLAYER_STATE_PLAYING -> 1
					MediaStatus.PLAYER_STATE_IDLE -> 2
					MediaStatus.PLAYER_STATE_PAUSED -> 3
					else -> if (mediaStatus?.idleReason === MediaStatus.IDLE_REASON_FINISHED) 2 else 4
				}
				channel.invokeMethod("chromeCast#didPlayerStatusUpdated", retCode)
			}

			override fun onMediaError(mediaError: MediaError) {
				val errorCode: Int = mediaError.detailedErrorCode ?: 100
				channel.invokeMethod("chromeCast#didPlayerStatusUpdated", errorCode)
			}
		}

	override fun getView() = chromeCastButton

	override fun dispose() {

	}

	// Flutter methods handling

	override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"chromeCast#wait" -> result.success(null)
			"chromeCast#loadMedia" -> {
				loadMedia(call.arguments)
				result.success(null)
			}
			"chromeCast#play" -> {
				play()
				result.success(null)
			}
			"chromeCast#pause" -> {
				pause()
				result.success(null)
			}
			"chromeCast#seek" -> {
				seek(call.arguments)
				result.success(null)
			}
			"chromeCast#setVolume" -> {
				setVolume(call.arguments)
				result.success(null)
			}
			"chromeCast#getMediaInfo" -> result.success(getMediaInfo())
			"chromeCast#getVolume" -> result.success(getVolume())
			"chromeCast#stop" -> {
				stop()
				result.success(null)
			}
			"chromeCast#isPlaying" -> result.success(isPlaying())
			"chromeCast#isConnected" -> result.success(isConnected())
			"chromeCast#endSession" -> {
				endSession()
				result.success(null)
			}
			"chromeCast#position" -> result.success(position())
			"chromeCast#duration" -> result.success(duration())
			"chromeCast#addSessionListener" -> {
				addSessionListener()
				result.success(null)
			}
			"chromeCast#removeSessionListener" -> {
				removeSessionListener()
				result.success(null)
			}
			"chromeCast#getPlaybackRate" -> {
				result.success(getPlaybackRate())
			}
			"chromeCast#setPlaybackRate" -> {
				setPlaybackRate(call.arguments)
				result.success(null)
			}
			"chromeCast#getSubtitleTrack" -> {
				result.success(getSubtitleTrack())
			}
			"chromeCast#setSubtitleTrack" -> {
				setSubtitleTrack(call.arguments)
				result.success(null)
			}
			"chromeCast#getAudioTrack" -> {
				result.success(getAudioTrackLang())
			}
			"chromeCast#setAudioTrack" -> {
				setAudioTrack(call.arguments)
				result.success(null)
			}
			"chromeCast#performClick" -> {
				chromeCastButton.performClick()
				result.success(null)
			}
		}
	}

	// SessionManagerListener

	override fun onSessionStarted(p0: Session, p1: String) {
		if (p0 is CastSession) {
			p0.remoteMediaClient?.registerCallback(mRemoteMediaClientListener)
		}
		channel.invokeMethod("chromeCast#didStartSession", null)
	}

	override fun onSessionEnded(p0: Session, p1: Int) {
		channel.invokeMethod("chromeCast#didEndSession", null)
	}

	override fun onSessionResuming(p0: Session, p1: String) {

	}

	override fun onSessionResumed(p0: Session, p1: Boolean) {

	}

	override fun onSessionResumeFailed(p0: Session, p1: Int) {

	}

	override fun onSessionSuspended(p0: Session, p1: Int) {

	}

	override fun onSessionStarting(p0: Session) {

	}

	override fun onSessionEnding(p0: Session) {

	}

	override fun onSessionStartFailed(p0: Session, p1: Int) {

	}

	// PendingResult.StatusListener

	override fun onComplete(status: Status) {
		if (status.isSuccess) {
			channel.invokeMethod("chromeCast#requestDidComplete", null)
		}
	}
}

fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { key ->
	when (val value = this[key]) {
		is JSONArray -> {
			val map =
				(0 until value.length()).associate { index -> Pair(index.toString(), value[index]) }
			JSONObject(map).toMap().values.toList()
		}
		is JSONObject -> value.toMap()
		JSONObject.NULL -> null
		else -> value
	}
}