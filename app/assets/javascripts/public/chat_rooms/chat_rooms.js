'use strict';

if (document.URL.match(/chat_rooms/)){
  window.addEventListener('DOMContentLoaded', function() {
    let chatArea = document.getElementById('chat-area');
    chatAreaHeight = chatArea.scrollHeight;
    chatArea.scrollTop = chatAreaHeight;
  })
}
