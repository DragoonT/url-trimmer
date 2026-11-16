package com.dragoon.trimplaylist

import android.graphics.Color
import android.view.Gravity
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Dismiss the current project-styled overlay modal. */
internal fun MainActivity.dismissAppModal() {
    appModal?.let { overlay -> (overlay.parent as? ViewGroup)?.removeView(overlay) }
    appModal = null
    updateOverlay = null
    notesDialog = null
}

/**
 * In-app modal matching the desktop overlay + card UI.
 * Prefer this over system AlertDialog everywhere.
 */
internal fun MainActivity.showAppModal(
    cancelOnScrim: Boolean = true,
    build: LinearLayout.(close: () -> Unit) -> Unit,
) {
    dismissAppModal()
    val close = { dismissAppModal() }
    val overlay = FrameLayout(this).apply {
        setBackgroundColor(Color.argb(170, 0, 0, 0))
        isClickable = true
        isFocusable = true
        if (cancelOnScrim) setOnClickListener { close() }
    }
    val card = column(px(20), px(20), px(20), px(16)).apply {
        background = rounded(dialogBg(), 16)
        elevation = px(8).toFloat()
        isClickable = true
        setOnClickListener { /* keep card taps from closing */ }
        build(close)
    }
    overlay.addView(card, FrameLayout.LayoutParams(MATCH, WRAP).apply {
        gravity = Gravity.CENTER
        marginStart = px(28)
        marginEnd = px(28)
    })
    shell.addView(overlay, FrameLayout.LayoutParams(MATCH, MATCH))
    appModal = overlay
    updateOverlay = overlay
}

internal fun MainActivity.appConfirm(
    title: String,
    message: String,
    confirmLabel: String = "OK",
    cancelLabel: String = "Cancel",
    onConfirm: () -> Unit,
    onCancel: (() -> Unit)? = null,
) {
    showAppModal { close ->
        addView(label(title, 20f, ink(), true))
        if (message.isNotBlank()) {
            addView(spaceH(8))
            addView(muted(message))
        }
        addView(spaceH(12))
        addView(solid(confirmLabel) {
            close()
            onConfirm()
        })
        addView(pill(cancelLabel, false) {
            close()
            onCancel?.invoke()
        }.apply {
            layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(8) }
        })
    }
}

internal fun MainActivity.appChoices(title: String, items: Array<String>, onPick: (Int) -> Unit) {
    showAppModal { close ->
        addView(label(title, 20f, ink(), true))
        addView(spaceH(10))
        items.forEachIndexed { index, item ->
            addView(TextView(this@appChoices).apply {
                text = item
                setTextColor(ink())
                textSize = 16f
                setPadding(px(12), px(14), px(12), px(14))
                background = rounded(if (index % 2 == 0) selectedBg() else dialogBg(), 10)
                layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = if (index == 0) 0 else px(6) }
                setOnClickListener {
                    close()
                    onPick(index)
                }
            })
        }
        addView(pill("Cancel", false) { close() }.apply {
            layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(12) }
        })
    }
}

internal fun MainActivity.appMultiChoice(
    title: String,
    labels: Array<String>,
    checked: BooleanArray,
    confirmLabel: String = "Add",
    cancelLabel: String = "Cancel",
    onConfirm: (BooleanArray) -> Unit,
) {
    val state = checked.copyOf()
    showAppModal { close ->
        addView(label(title, 20f, ink(), true))
        addView(spaceH(10))
        val list = column(0, 0, 0, 0)
        labels.forEachIndexed { index, line ->
            val row = row().apply {
                gravity = Gravity.CENTER_VERTICAL
                setPadding(px(10), px(12), px(10), px(12))
                background = rounded(selectedBg(), 10)
                layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = if (index == 0) 0 else px(6) }
            }
            val mark = TextView(this@appMultiChoice).apply {
                text = if (state[index]) "✓" else "○"
                setTextColor(if (state[index]) BRAND else soft())
                textSize = 18f
                setPadding(0, 0, px(10), 0)
            }
            val text = TextView(this@appMultiChoice).apply {
                this.text = line
                setTextColor(ink())
                textSize = 14f
            }
            fun paint() {
                mark.text = if (state[index]) "✓" else "○"
                mark.setTextColor(if (state[index]) BRAND else soft())
            }
            row.setOnClickListener {
                state[index] = !state[index]
                paint()
            }
            row.addView(mark)
            row.addView(text, LinearLayout.LayoutParams(0, WRAP, 1f))
            list.addView(row)
        }
        val scroll = ScrollView(this@appMultiChoice).apply {
            addView(list)
            layoutParams = LinearLayout.LayoutParams(MATCH, px(280))
        }
        addView(scroll)
        addView(spaceH(12))
        addView(solid(confirmLabel) {
            close()
            onConfirm(state)
        })
        addView(pill(cancelLabel, false) { close() }.apply {
            layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(8) }
        })
    }
}

internal fun MainActivity.appPrompt(
    title: String,
    value: String,
    ok: String,
    hint: String = "Name",
    done: (String) -> Unit,
) {
    showAppModal(cancelOnScrim = false) { close ->
        addView(label(title, 20f, ink(), true))
        addView(spaceH(12))
        val input = EditText(this@appPrompt).apply {
            setText(value)
            this.hint = hint
            setTextColor(ink())
            setHintTextColor(soft())
            background = rounded(fieldBg(), 10)
            setPadding(px(12), px(12), px(12), px(12))
            setSingleLine(true)
        }
        addView(input)
        addView(spaceH(12))
        addView(solid(ok) {
            done(input.text.toString().trim())
            close()
        })
        addView(pill("Cancel", false) { close() }.apply {
            layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(8) }
        })
        input.post { input.requestFocus(); input.setSelection(input.text.length) }
    }
}

internal fun MainActivity.appContentModal(
    title: String,
    message: String = "",
    confirmLabel: String = "Save",
    cancelLabel: String = "Cancel",
    onConfirm: () -> Unit,
    onCancel: (() -> Unit)? = null,
    content: LinearLayout.() -> Unit,
) {
    showAppModal(cancelOnScrim = false) { close ->
        addView(label(title, 20f, ink(), true))
        if (message.isNotBlank()) {
            addView(spaceH(8))
            addView(muted(message))
        }
        addView(spaceH(10))
        content()
        addView(spaceH(12))
        addView(solid(confirmLabel) {
            close()
            onConfirm()
        })
        addView(pill(cancelLabel, false) {
            close()
            onCancel?.invoke()
        }.apply {
            layoutParams = LinearLayout.LayoutParams(MATCH, WRAP).apply { topMargin = px(8) }
        })
    }
}
