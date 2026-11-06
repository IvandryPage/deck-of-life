package id.deckoflife.app

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.os.Bundle
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Menerima teks/tautan dari Android Share Sheet (ACTION_SEND, text/plain) dan
 * meneruskannya ke Dart lewat MethodChannel. Tidak memakai plugin pihak ketiga.
 *
 * Yang diteruskan hanya yang benar-benar dikirim aplikasi sumber:
 *  - text    : EXTRA_TEXT
 *  - subject : EXTRA_SUBJECT atau EXTRA_TITLE (bila ada)
 * Aplikasi sumber tidak dilaporkan karena Android tidak menjaminnya.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String?>? = null
    private var initialHandled = false
    private var calendarPermissionResult: MethodChannel.Result? = null
    private var calendarWritePermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Setelah rotasi / recreate, intent awal dikirim ulang oleh sistem.
        // Jangan menangkap share yang sama dua kali.
        initialHandled = savedInstanceState != null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialShare" -> {
                    val payload = pending ?: if (!initialHandled) extractShare(intent) else null
                    pending = null
                    initialHandled = true
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALENDAR_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasCalendarReadPermission" -> result.success(hasCalendarReadPermission())
                "requestCalendarReadPermission" -> requestCalendarReadPermission(result)
                "hasCalendarWritePermission" -> result.success(hasCalendarWritePermission())
                "requestCalendarWritePermission" -> requestCalendarWritePermission(result)
                "getDeviceCalendars" -> withCalendarReadPermission(result) {
                    result.success(readCalendars())
                }
                "getDeviceCalendarEvents" -> withCalendarReadPermission(result) {
                    val args = call.arguments as? Map<*, *>
                    val calendarIds = (args?.get("calendarIds") as? List<*>)
                        ?.filterIsInstance<String>()
                        .orEmpty()
                    val startMillis = (args?.get("startMillis") as? Number)?.toLong()
                    val endMillis = (args?.get("endMillis") as? Number)?.toLong()
                    if (calendarIds.isEmpty() || startMillis == null || endMillis == null) {
                        result.success(emptyList<Map<String, Any?>>())
                    } else {
                        result.success(
                            readCalendarEvents(calendarIds, startMillis, endMillis),
                        )
                    }
                }
                "createDeviceCalendarEvent" -> withCalendarWritePermission(result) {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("invalid_event", "Event data is missing", null)
                    } else {
                        result.success(createCalendarEvent(args))
                    }
                }
                "updateDeviceCalendarEvent" -> withCalendarWritePermission(result) {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("invalid_event", "Event data is missing", null)
                    } else {
                        result.success(updateCalendarEvent(args))
                    }
                }
                "deleteDeviceCalendarEvent" -> withCalendarWritePermission(result) {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("invalid_event", "Event data is missing", null)
                    } else {
                        result.success(deleteCalendarEvent(args))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasCalendarReadPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestCalendarReadPermission(result: MethodChannel.Result) {
        if (hasCalendarReadPermission()) {
            result.success(true)
            return
        }
        if (calendarPermissionResult != null) {
            result.error("permission_pending", "Calendar permission request is already active", null)
            return
        }
        calendarPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), CALENDAR_PERMISSION_REQUEST)
    }

    private fun hasCalendarWritePermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestCalendarWritePermission(result: MethodChannel.Result) {
        if (hasCalendarWritePermission()) {
            result.success(true)
            return
        }
        if (calendarWritePermissionResult != null) {
            result.error("permission_pending", "Calendar write permission request is already active", null)
            return
        }
        calendarWritePermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.WRITE_CALENDAR), CALENDAR_WRITE_PERMISSION_REQUEST)
    }

    private fun withCalendarReadPermission(
        result: MethodChannel.Result,
        action: () -> Unit,
    ) {
        if (!hasCalendarReadPermission()) {
            result.error("permission_denied", "Calendar read permission has not been granted", null)
            return
        }
        try {
            action()
        } catch (error: Exception) {
            result.error("calendar_read_failed", error.message, null)
        }
    }

    private fun readCalendars(): List<Map<String, Any?>> {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
            CalendarContract.Calendars.CALENDAR_COLOR,
        )
        val calendars = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            "${CalendarContract.Calendars.VISIBLE} = ?",
            arrayOf("1"),
            "${CalendarContract.Calendars.CALENDAR_DISPLAY_NAME} COLLATE NOCASE ASC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(CalendarContract.Calendars._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
            val accountColumn = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_NAME)
            val typeColumn = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.ACCOUNT_TYPE)
            val colorColumn = cursor.getColumnIndexOrThrow(CalendarContract.Calendars.CALENDAR_COLOR)
            while (cursor.moveToNext()) {
                calendars.add(
                    mapOf(
                        "id" to cursor.getString(idColumn),
                        "name" to cursor.getString(nameColumn),
                        "accountName" to cursor.getString(accountColumn),
                        "accountType" to cursor.getString(typeColumn),
                        "color" to cursor.getInt(colorColumn),
                    ),
                )
            }
        }
        return calendars
    }

    private fun readCalendarEvents(
        calendarIds: List<String>,
        startMillis: Long,
        endMillis: Long,
    ): List<Map<String, Any?>> {
        val rangeUri = CalendarContract.Instances.CONTENT_URI.buildUpon().apply {
            ContentUris.appendId(this, startMillis)
            ContentUris.appendId(this, endMillis)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.ALL_DAY,
        )
        val placeholders = List(calendarIds.size) { "?" }.joinToString(",")
        val selectionArgs = (calendarIds + packageName).toTypedArray()
        val events = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            rangeUri,
            projection,
            "${CalendarContract.Instances.CALENDAR_ID} IN ($placeholders) " +
                "AND (${CalendarContract.Instances.CUSTOM_APP_PACKAGE} IS NULL " +
                "OR ${CalendarContract.Instances.CUSTOM_APP_PACKAGE} != ?)",
            selectionArgs,
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.EVENT_ID)
            val calendarColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.CALENDAR_ID)
            val titleColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.TITLE)
            val beginColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.BEGIN)
            val endColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.END)
            val locationColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.EVENT_LOCATION)
            val allDayColumn = cursor.getColumnIndexOrThrow(CalendarContract.Instances.ALL_DAY)
            while (cursor.moveToNext()) {
                events.add(
                    mapOf(
                        "id" to cursor.getString(idColumn),
                        "calendarId" to cursor.getString(calendarColumn),
                        "title" to cursor.getString(titleColumn),
                        "startMillis" to cursor.getLong(beginColumn),
                        "endMillis" to cursor.getLong(endColumn),
                        "location" to cursor.getString(locationColumn),
                        "allDay" to (cursor.getInt(allDayColumn) == 1),
                    ),
                )
            }
        }
        return events
    }

    private fun createCalendarEvent(args: Map<*, *>): String? {
        val calendarId = args["calendarId"] as? String ?: return null
        val appEventId = args["appEventId"] as? String ?: return null
        val values = eventValues(args, includeCalendarId = true).apply {
            put(CalendarContract.Events.CALENDAR_ID, calendarId.toLongOrNull())
            put(CalendarContract.Events.CUSTOM_APP_PACKAGE, packageName)
            put(CalendarContract.Events.CUSTOM_APP_URI, appEventUri(appEventId))
        }
        return contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            ?.lastPathSegment
    }

    private fun updateCalendarEvent(args: Map<*, *>): Boolean {
        val appEventId = args["appEventId"] as? String ?: return false
        val values = eventValues(args, includeCalendarId = false)
        val changed = contentResolver.update(
            CalendarContract.Events.CONTENT_URI,
            values,
            "${CalendarContract.Events.CUSTOM_APP_PACKAGE} = ? AND " +
                "${CalendarContract.Events.CUSTOM_APP_URI} = ?",
            arrayOf(packageName, appEventUri(appEventId)),
        )
        return changed > 0
    }

    private fun deleteCalendarEvent(args: Map<*, *>): Boolean {
        val appEventId = args["appEventId"] as? String ?: return false
        val deleted = contentResolver.delete(
            CalendarContract.Events.CONTENT_URI,
            "${CalendarContract.Events.CUSTOM_APP_PACKAGE} = ? AND " +
                "${CalendarContract.Events.CUSTOM_APP_URI} = ?",
            arrayOf(packageName, appEventUri(appEventId)),
        )
        return deleted > 0
    }

    private fun eventValues(args: Map<*, *>, includeCalendarId: Boolean): ContentValues {
        val title = args["title"] as? String ?: error("Event title is missing")
        val start = (args["startMillis"] as? Number)?.toLong()
            ?: error("Event start time is missing")
        val end = (args["endMillis"] as? Number)?.toLong()
            ?: error("Event end time is missing")
        val values = ContentValues().apply {
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DTSTART, start)
            put(CalendarContract.Events.DTEND, end)
            put(CalendarContract.Events.EVENT_TIMEZONE, java.util.TimeZone.getDefault().id)
            put(CalendarContract.Events.ALL_DAY, if (args["allDay"] == true) 1 else 0)
            val description = args["description"] as? String
            if (description.isNullOrBlank()) putNull(CalendarContract.Events.DESCRIPTION)
            else put(CalendarContract.Events.DESCRIPTION, description)
            val location = args["location"] as? String
            if (location.isNullOrBlank()) putNull(CalendarContract.Events.EVENT_LOCATION)
            else put(CalendarContract.Events.EVENT_LOCATION, location)
            val recurrenceRule = args["recurrenceRule"] as? String
            if (recurrenceRule == null) putNull(CalendarContract.Events.RRULE)
            else put(CalendarContract.Events.RRULE, recurrenceRule)
        }
        if (includeCalendarId) {
            val calendarId = args["calendarId"] as? String
                ?: error("Calendar id is missing")
            values.put(CalendarContract.Events.CALENDAR_ID, calendarId.toLongOrNull())
        }
        return values
    }

    private fun appEventUri(eventId: String): String =
        "deck-of-life://events/$eventId"

    private fun withCalendarWritePermission(
        result: MethodChannel.Result,
        action: () -> Unit,
    ) {
        if (!hasCalendarWritePermission()) {
            result.error("permission_denied", "Calendar write permission has not been granted", null)
            return
        }
        try {
            action()
        } catch (error: Exception) {
            result.error("calendar_write_failed", error.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST &&
            requestCode != CALENDAR_WRITE_PERMISSION_REQUEST
        ) return
        val result = when (requestCode) {
            CALENDAR_PERMISSION_REQUEST -> calendarPermissionResult.also {
                calendarPermissionResult = null
            }
            CALENDAR_WRITE_PERMISSION_REQUEST -> calendarWritePermissionResult.also {
                calendarWritePermissionResult = null
            }
            else -> null
        } ?: return
        result.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = extractShare(intent) ?: return
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("onShare", payload)
        } else {
            pending = payload
        }
    }

    private fun extractShare(intent: Intent?): Map<String, String?>? {
        if (intent == null || intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (text.isNullOrBlank()) return null
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: intent.getStringExtra(Intent.EXTRA_TITLE)
        return mapOf("text" to text, "subject" to subject)
    }

    companion object {
        const val CHANNEL = "deck_of_life/share"
        const val CALENDAR_CHANNEL = "deck_of_life/android_calendar"
        const val CALENDAR_PERMISSION_REQUEST = 7402
        const val CALENDAR_WRITE_PERMISSION_REQUEST = 7403
    }
}
