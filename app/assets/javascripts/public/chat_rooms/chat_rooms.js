'use strict';

if (document.URL.match(/chat_rooms/)){
  window.addEventListener('DOMContentLoaded', function() {
    // 通知経由で特定メッセージへスクロールする場合(#chat-message-<id>)は、
    // chat_message_scroll_highlight.js側の遷移に任せて末尾スクロールを行わない。
    if (/^#chat-message-\d+$/.test(window.location.hash)) return;

    let chatArea = document.getElementById('chat-area');
    chatAreaHeight = chatArea.scrollHeight;
    chatArea.scrollTop = chatAreaHeight;
  })
}
