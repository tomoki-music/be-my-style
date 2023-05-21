window.addEventListener('DOMContentLoaded', function() {
  let chatArea = document.getElementById('chat-area'),
  chatAreaHeight = chatArea.scrollHeight;
  chatArea.scrollTop = chatAreaHeight;
})