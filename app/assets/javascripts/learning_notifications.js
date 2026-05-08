document.addEventListener('turbolinks:load', function() {
  document.querySelectorAll('.learning-copy-button').forEach(function(button) {
    if (button.dataset.copyReady === 'true') return;

    button.dataset.copyReady = 'true';
    button.addEventListener('click', function() {
      const text = button.dataset.learningCopyText || '';
      const item = button.closest('.learning-voice-item');
      const status = item ? item.querySelector('.learning-copy-status') : null;
      const sendLinks = item ? item.querySelector('.learning-send-links') : null;

      copyText(text).then(function() {
        if (status) status.textContent = 'コピーしました！';
        if (sendLinks) sendLinks.hidden = false;
      }).catch(function() {
        if (status) status.textContent = 'コピーできませんでした';
      });
    });
  });
});

function copyText(text) {
  if (navigator.clipboard && window.isSecureContext) {
    return navigator.clipboard.writeText(text);
  }

  return new Promise(function(resolve, reject) {
    const textarea = document.createElement('textarea');
    textarea.value = text;
    textarea.setAttribute('readonly', '');
    textarea.style.position = 'fixed';
    textarea.style.opacity = '0';
    document.body.appendChild(textarea);
    textarea.select();

    try {
      document.execCommand('copy') ? resolve() : reject();
    } catch (error) {
      reject(error);
    } finally {
      document.body.removeChild(textarea);
    }
  });
}
