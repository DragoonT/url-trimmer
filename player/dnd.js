/** Drag reorder — in-flow placeholder (works for middle items, no overlap) */

const ACTIVATION_PX = 5;

export function initSortableList(
  container,
  { itemSelector, handleSelector = ".drag-handle", onReorder },
) {
  if (!container) return;

  let drag = null;

  function rows() {
    return [...container.querySelectorAll(itemSelector)];
  }

  function syncIndices() {
    rows().forEach((row, index) => {
      row.dataset.index = String(index);
      const badge = row.querySelector(".track-index");
      if (badge) badge.textContent = String(index + 1);
    });
  }

  function movePlaceholder(clientY) {
    const placeholder = drag.placeholder;
    const slots = [...container.children].filter(
      (el) => el === placeholder || el.matches(itemSelector),
    );

    for (const el of slots) {
      if (el === placeholder) continue;
      const rect = el.getBoundingClientRect();
      if (clientY < rect.top + rect.height / 2) {
        if (placeholder.nextElementSibling !== el) {
          container.insertBefore(placeholder, el);
        }
        return;
      }
    }

    if (container.lastElementChild !== placeholder) {
      container.appendChild(placeholder);
    }
  }

  function placeholderIndex() {
    const slots = [...container.children].filter(
      (el) => el === drag.placeholder || el.matches(itemSelector),
    );
    return slots.indexOf(drag.placeholder);
  }

  function unbindDragListeners() {
    document.removeEventListener("pointermove", onPointerMove, true);
    document.removeEventListener("pointerup", finishDrag, true);
    document.removeEventListener("pointercancel", finishDrag, true);
  }

  function resetFloater(row) {
    row.classList.remove("dragging", "animate-fade-up");
    row.style.animation = "none";
    row.style.animationDelay = "";
    row.style.position = "";
    row.style.left = "";
    row.style.top = "";
    row.style.width = "";
    row.style.zIndex = "";
    row.style.margin = "";
    row.style.pointerEvents = "";
    row.style.boxSizing = "";
    row.style.opacity = "";
    row.style.background = "";
    row.style.borderColor = "";
    row.style.boxShadow = "";
    row.style.transform = "";
  }

  function onPointerMove(e) {
    if (!drag || e.pointerId !== drag.pointerId) return;

    const dx = e.clientX - drag.startX;
    const dy = e.clientY - drag.startY;

    if (!drag.active) {
      if (Math.hypot(dx, dy) < ACTIVATION_PX) return;
      drag.active = true;

      const row = drag.row;
      const rect = row.getBoundingClientRect();

      drag.placeholder = document.createElement("div");
      drag.placeholder.className = "track-sort-placeholder";
      drag.placeholder.setAttribute("aria-hidden", "true");
      drag.placeholder.style.height = `${rect.height}px`;
      container.insertBefore(drag.placeholder, row);

      drag.floater = row;
      drag.offsetX = e.clientX - rect.left;
      drag.offsetY = e.clientY - rect.top;

      document.body.appendChild(row);
      row.classList.add("dragging");
      row.classList.remove("animate-fade-up");
      row.style.animation = "none";

      row.style.position = "fixed";
      row.style.left = `${rect.left}px`;
      row.style.top = `${rect.top}px`;
      row.style.width = `${rect.width}px`;
      row.style.zIndex = "1000";
      row.style.margin = "0";
      row.style.boxSizing = "border-box";
      row.style.pointerEvents = "none";
    }

    e.preventDefault();

    drag.floater.style.left = `${e.clientX - drag.offsetX}px`;
    drag.floater.style.top = `${e.clientY - drag.offsetY}px`;

    movePlaceholder(e.clientY);
  }

  async function finishDrag(e) {
    if (!drag || e.pointerId !== drag.pointerId) return;

    unbindDragListeners();

    if (drag.captureEl?.hasPointerCapture?.(e.pointerId)) {
      drag.captureEl.releasePointerCapture(e.pointerId);
    }

    const { fromIndex, active, floater, placeholder } = drag;

    if (!active) {
      container.classList.remove("is-sorting");
      drag = null;
      return;
    }

    const toIndex = placeholderIndex();
    const changed = fromIndex !== toIndex;

    resetFloater(floater);
    floater.classList.add("no-motion");
    container.insertBefore(floater, placeholder);
    placeholder.remove();
    syncIndices();
    container.classList.remove("is-sorting");

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        floater.classList.remove("no-motion");
        floater.style.animation = "";
      });
    });

    drag = null;

    if (changed) {
      await onReorder?.(fromIndex, toIndex);
    }
  }

  container.addEventListener(
    "pointerdown",
    (e) => {
      if (drag) return;

      const handle = e.target.closest(handleSelector);
      if (!handle) return;

      const row = handle.closest(itemSelector);
      if (!row || row.dataset.index == null) return;
      if (e.button !== 0) return;

      e.preventDefault();
      e.stopPropagation();

      container.classList.add("is-sorting");

      const captureEl = container;
      if (captureEl.setPointerCapture) {
        captureEl.setPointerCapture(e.pointerId);
      }

      drag = {
        row,
        floater: null,
        captureEl,
        pointerId: e.pointerId,
        fromIndex: Number(row.dataset.index),
        startX: e.clientX,
        startY: e.clientY,
        active: false,
        placeholder: null,
        offsetX: 0,
        offsetY: 0,
      };

      document.addEventListener("pointermove", onPointerMove, true);
      document.addEventListener("pointerup", finishDrag, true);
      document.addEventListener("pointercancel", finishDrag, true);
    },
    true,
  );
}
