// AIテロップ動画の処理状況ポーリング。
// singing/diagnoses.js の既存パターン(data属性 + setIntervalによるフルリロード)を踏襲する。
// 完了・失敗時はサーバー側でdata属性自体を出力しなくなるため、ポーリングは自然に止まる。
(function() {
  var timerId = null;

  function stopPolling() {
    if (!timerId) return;

    clearInterval(timerId);
    timerId = null;
  }

  function startPolling() {
    stopPolling();

    var target = document.querySelector('[data-caption-video-polling]');
    if (!target) return;

    var interval = parseInt(target.dataset.captionVideoPollingInterval, 10) || 5000;

    timerId = setInterval(function() {
      window.location.reload();
    }, interval);
  }

  document.addEventListener('DOMContentLoaded', startPolling);
  document.addEventListener('turbolinks:load', startPolling);
  document.addEventListener('turbolinks:before-cache', stopPolling);
  window.addEventListener('pagehide', stopPolling);
})();
