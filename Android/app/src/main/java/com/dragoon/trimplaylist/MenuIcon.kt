package com.dragoon.trimplaylist

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.view.View

internal class MenuIcon(context: Context, color: Int) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    override fun onDraw(canvas: Canvas) {
        paint.strokeWidth = height * 0.08f
        val left = width * 0.22f
        val right = width * 0.78f
        canvas.drawLine(left, height * 0.32f, right, height * 0.32f, paint)
        canvas.drawLine(left, height * 0.50f, right, height * 0.50f, paint)
        canvas.drawLine(left, height * 0.68f, right, height * 0.68f, paint)
    }
}
