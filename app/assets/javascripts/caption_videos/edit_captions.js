// テロップ編集画面: 各テロップの開始時間ボタンをクリックすると動画の該当位置へ移動する。
// cocoonで動的追加される行にも対応するため、コンテナへのイベント委譲で処理する。
(function() {
  function initCaptionSeek() {
    var list = document.getElementById('video-captions-list');
    var player = document.getElementById('caption-video-edit-player');
    if (!list || !player) return;

    list.addEventListener('click', function(event) {
      var btn = event.target.closest('.video-caption-fields__seek-btn');
      if (!btn) return;

      var row = btn.closest('.video-caption-fields');
      if (!row) return;

      var input = row.querySelector('.video-caption-fields__start-time');
      if (!input) return;

      var seconds = parseFloat(input.value);
      if (isNaN(seconds)) return;

      player.currentTime = seconds;
      player.play();
    });
  }

  document.addEventListener('DOMContentLoaded', initCaptionSeek);
  document.addEventListener('turbolinks:load', initCaptionSeek);
})();
