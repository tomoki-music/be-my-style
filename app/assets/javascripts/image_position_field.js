// 画像の表示位置の調整（shared/_image_position_field）。
// 位置は object-position の横・縦 %（0〜100）。object-fit: cover の枠では、はみ出した分の
// どこを見せるかを決める値なので、ドラッグ量をはみ出し量で割って % に換算する。
(function () {
  var KEY_STEP = 2;
  var KEY_STEP_LARGE = 10;

  function clamp(value) {
    return Math.min(100, Math.max(0, value));
  }

  function round(value) {
    return Math.round(value * 100) / 100;
  }

  function parse(value) {
    var number = parseFloat(value);
    return isNaN(number) ? null : clamp(number);
  }

  // 枠に cover で収めたときに、はみ出す幅・高さ（px）。はみ出しが無い向きには動かせない。
  function overflowOf(frame, image) {
    var width = frame.clientWidth;
    var height = frame.clientHeight;
    var naturalWidth = image.naturalWidth;
    var naturalHeight = image.naturalHeight;
    if (!width || !height || !naturalWidth || !naturalHeight) return { x: 0, y: 0 };

    var scale = Math.max(width / naturalWidth, height / naturalHeight);
    return { x: naturalWidth * scale - width, y: naturalHeight * scale - height };
  }

  function setup(root) {
    if (root.dataset.imagePositionReady === "true") return;
    root.dataset.imagePositionReady = "true";

    var input = root.querySelector("[data-image-position-input]");
    var fieldX = root.querySelector("[data-image-position-x]");
    var fieldY = root.querySelector("[data-image-position-y]");
    var editor = root.querySelector("[data-image-position-editor]");
    var resetButton = root.querySelector("[data-image-position-reset]");
    var status = root.querySelector("[data-image-position-status]");
    var frames = Array.prototype.slice.call(root.querySelectorAll("[data-image-position-frame]"));
    var images = Array.prototype.slice.call(root.querySelectorAll("[data-image-position-image]"));
    if (!input || !fieldX || !fieldY || !editor) return;

    var position = { x: parse(fieldX.value), y: parse(fieldY.value) };
    if (position.x === null) position.x = 50;
    if (position.y === null) position.y = 50;
    var objectUrl = null;

    function setStatus(text) {
      if (status) status.textContent = text;
    }

    function render() {
      var value = round(position.x) + "% " + round(position.y) + "%";
      images.forEach(function (image) {
        image.style.objectPosition = value;
      });
    }

    function commit() {
      fieldX.value = round(position.x);
      fieldY.value = round(position.y);
      render();
      setStatus("横 " + Math.round(position.x) + "%・縦 " + Math.round(position.y) + "% の位置で表示します。保存すると反映されます。");
    }

    function move(frame, image, start, dx, dy) {
      var overflow = overflowOf(frame, image);
      var changed = false;
      // 画像を右へ動かす＝左側を見せる＝横の % を小さくする。
      if (overflow.x > 0.5) {
        position.x = clamp(start.x - (dx / overflow.x) * 100);
        changed = true;
      }
      if (overflow.y > 0.5) {
        position.y = clamp(start.y - (dy / overflow.y) * 100);
        changed = true;
      }
      if (changed) commit();
    }

    frames.forEach(function (frame) {
      var image = frame.querySelector("[data-image-position-image]");
      if (!image) return;

      frame.addEventListener("pointerdown", function (event) {
        if (event.pointerType === "mouse" && event.button !== 0) return;
        event.preventDefault();
        frame.focus({ preventScroll: true });

        var start = { x: position.x, y: position.y, clientX: event.clientX, clientY: event.clientY };
        var pointerId = event.pointerId;
        if (frame.setPointerCapture) frame.setPointerCapture(pointerId);
        frame.classList.add("is-dragging");

        function onMove(moveEvent) {
          if (moveEvent.pointerId !== pointerId) return;
          move(frame, image, start, moveEvent.clientX - start.clientX, moveEvent.clientY - start.clientY);
        }

        function onEnd(endEvent) {
          if (endEvent.pointerId !== pointerId) return;
          frame.classList.remove("is-dragging");
          frame.removeEventListener("pointermove", onMove);
          frame.removeEventListener("pointerup", onEnd);
          frame.removeEventListener("pointercancel", onEnd);
        }

        frame.addEventListener("pointermove", onMove);
        frame.addEventListener("pointerup", onEnd);
        frame.addEventListener("pointercancel", onEnd);
      });

      frame.addEventListener("keydown", function (event) {
        var step = event.shiftKey ? KEY_STEP_LARGE : KEY_STEP;
        var overflow = overflowOf(frame, image);
        var dx = 0;
        var dy = 0;
        if (event.key === "ArrowLeft") dx = -step;
        else if (event.key === "ArrowRight") dx = step;
        else if (event.key === "ArrowUp") dy = -step;
        else if (event.key === "ArrowDown") dy = step;
        else return;

        event.preventDefault();
        // ドラッグと同じく、矢印の向きへ画像を動かす（→で画像が右へ寄り、左側が見える）。
        if (dx && overflow.x > 0.5) position.x = clamp(position.x - dx);
        if (dy && overflow.y > 0.5) position.y = clamp(position.y - dy);
        commit();
      });
    });

    if (resetButton) {
      resetButton.addEventListener("click", function () {
        position = { x: 50, y: 50 };
        commit();
      });
    }

    input.addEventListener("change", function () {
      var file = input.files && input.files[0];
      if (!file) return;

      if (objectUrl) URL.revokeObjectURL(objectUrl);
      objectUrl = URL.createObjectURL(file);

      // 新しい画像には前の画像の位置を持ち越さない（未調整のまま保存すると中央基準）。
      position = { x: 50, y: 50 };
      fieldX.value = "";
      fieldY.value = "";
      images.forEach(function (image) {
        image.src = objectUrl;
      });
      render();
      editor.hidden = false;
      setStatus("中央を基準に表示しています。ドラッグで位置を調整できます。");
    });

    images.forEach(function (image) {
      image.addEventListener("error", function () {
        if (!objectUrl || image.src !== objectUrl) return;
        setStatus("この画像はブラウザでプレビューできません。保存はできますが、表示位置の調整は保存後にもう一度お試しください。");
      });
    });

    render();
  }

  function setupAll() {
    var roots = document.querySelectorAll("[data-image-position-field]");
    Array.prototype.forEach.call(roots, setup);
  }

  // Turbolinks はページを複製して保存するため、印を消しておかないと戻ったときにイベントが付かない。
  document.addEventListener("turbolinks:before-cache", function () {
    var roots = document.querySelectorAll("[data-image-position-field]");
    Array.prototype.forEach.call(roots, function (root) {
      delete root.dataset.imagePositionReady;
    });
  });

  document.addEventListener("turbolinks:load", setupAll);
  if (document.readyState !== "loading") setupAll();
  else document.addEventListener("DOMContentLoaded", setupAll);
})();
