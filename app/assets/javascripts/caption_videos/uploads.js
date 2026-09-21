// AIテロップ動画アップロード画面: Active Storage Direct Upload の進捗表示。
// 二重送信防止は f.submit の data-disable-with (rails-ujs 標準機能) に任せる。
(function() {
  function initUploadProgress() {
    var progressWrap = document.getElementById('caption-video-upload-progress');
    var progressBar = document.getElementById('caption-video-upload-progress-bar');
    if (!progressWrap || !progressBar) return;

    document.addEventListener('direct-upload:initialize', function() {
      progressWrap.hidden = false;
      progressBar.style.width = '0%';
    });

    document.addEventListener('direct-upload:progress', function(event) {
      var progress = event.detail && event.detail.progress;
      if (typeof progress === 'number') {
        progressBar.style.width = progress + '%';
      }
    });

    document.addEventListener('direct-upload:error', function(event) {
      event.preventDefault();
      progressWrap.hidden = true;
      var message = (event.detail && event.detail.error) || 'アップロードに失敗しました。';
      window.alert(message);
    });

    document.addEventListener('direct-upload:end', function() {
      progressBar.style.width = '100%';
    });
  }

  document.addEventListener('DOMContentLoaded', initUploadProgress);
  document.addEventListener('turbolinks:load', initUploadProgress);
})();
