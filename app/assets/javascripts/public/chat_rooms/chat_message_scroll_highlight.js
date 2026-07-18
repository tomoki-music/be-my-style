// 通知経由で `#chat-message-<id>` へ遷移してきた場合、該当メッセージまでスクロールし
// 一時的にハイライトする。対象が存在しない場合は何もしない(エラーにしない)。
//
// 自分宛てメンションの強調(.chat-mention--self)もここで付与する。
// Chat::MarkdownRendererの出力はRails.cacheでメッセージ単位・全閲覧者共有でキャッシュされるため、
// 「閲覧者ごとに見た目を変える」処理はレンダラー側に入れずクライアントJSで行う。
document.addEventListener('turbolinks:load', function () {
  if (!document.URL.match(/chat_rooms/)) return;

  var container = document.querySelector('.chat-rooms-show-container');
  var currentCustomerId = container ? container.dataset.currentCustomerId : null;
  if (currentCustomerId) {
    document.querySelectorAll('.chat-mention[data-customer-id="' + currentCustomerId + '"]').forEach(function (el) {
      el.classList.add('chat-mention--self');
    });
  }

  var match = window.location.hash.match(/^#(chat-message-\d+)$/);
  if (!match) return;

  var target = document.getElementById(match[1]);
  if (!target) return;

  target.scrollIntoView({ block: 'center' });
  target.classList.add('chat-message-highlight');
  setTimeout(function () {
    target.classList.remove('chat-message-highlight');
  }, 3000);
});
