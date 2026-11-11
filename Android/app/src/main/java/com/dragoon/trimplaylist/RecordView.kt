package com.dragoon.trimplaylist

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.view.View

internal class RecordView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    var art: Bitmap? = null
        set(value) {
            field = value
            invalidate()
        }

    override fun onDraw(canvas: Canvas) {
        val bitmap = art
        val radius = minOf(width, height) / 16f
        if (bitmap != null && !bitmap.isRecycled) {
            val dest = RectF(0f, 0f, width.toFloat(), height.toFloat())
            val path = Path().apply { addRoundRect(dest, radius, radius, Path.Direction.CW) }
            canvas.save()
            canvas.clipPath(path)
            val scale = maxOf(width.toFloat() / bitmap.width, height.toFloat() / bitmap.height)
            val drawW = bitmap.width * scale
            val drawH = bitmap.height * scale
            val left = (width - drawW) / 2f
            val top = (height - drawH) / 2f
            canvas.drawBitmap(bitmap, null, RectF(left, top, left + drawW, top + drawH), paint)
            canvas.restore()
            return
        }
        val c = width / 2f
        val r = minOf(width, height) / 2f
        paint.color = Color.rgb(58, 58, 58)
        canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), r / 8f, r / 8f, paint)
        paint.color = Color.rgb(30, 30, 30)
        canvas.drawCircle(c, height / 2f, r * 0.72f, paint)
        paint.color = Color.rgb(70, 70, 70)
        canvas.drawCircle(c, height / 2f, r * 0.28f, paint)
        paint.color = Color.rgb(20, 20, 20)
        canvas.drawCircle(c, height / 2f, r * 0.08f, paint)
    }
}
