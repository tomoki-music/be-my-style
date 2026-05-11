function setupLearningBulkLineMessages() {
  document.querySelectorAll('[data-bulk-line-form]').forEach(function(form) {
    if (form.dataset.bulkLineInitialized === 'true') return;
    form.dataset.bulkLineInitialized = 'true';

    var checkboxes = Array.prototype.slice.call(form.querySelectorAll('[data-bulk-line-checkbox]'));
    var summary = form.querySelector('[data-bulk-line-summary]');
    var message = form.querySelector('[data-bulk-line-message]');
    var remaining = form.querySelector('[data-bulk-line-remaining]');

    var isConnected = function(checkbox) {
      return checkbox.dataset.lineConnected === 'true';
    };

    var isDuplicateRecentlySent = function(checkbox) {
      return checkbox.dataset.duplicateRecentlySent === 'true';
    };

    var updateSummary = function() {
      var selected = checkboxes.filter(function(checkbox) { return checkbox.checked; });
      var connected = selected.filter(isConnected).length;
      var unconnected = selected.length - connected;
      var duplicate = selected.filter(function(checkbox) {
        return isConnected(checkbox) && isDuplicateRecentlySent(checkbox);
      }).length;

      if (summary) {
        var text = '選択中：' + selected.length + '名 / LINE連携済み：' + connected + '名 / 未連携：' + unconnected + '名。送信対象はLINE連携済みの' + connected + '名です。';
        if (duplicate > 0) {
          text += ' 24時間以内送信済み：' + duplicate + '名はサーバー側でスキップされます。';
        }
        summary.textContent = text;
      }
    };

    var updateRemaining = function() {
      if (!message || !remaining) return;

      remaining.textContent = '残り' + (500 - message.value.length) + '文字';
    };

    form.querySelectorAll('[data-bulk-line-select]').forEach(function(button) {
      button.addEventListener('click', function() {
        var mode = button.dataset.bulkLineSelect;
        checkboxes.forEach(function(checkbox) {
          checkbox.checked = mode === 'all' || (mode === 'connected' && isConnected(checkbox));
        });
        updateSummary();
      });
    });

    checkboxes.forEach(function(checkbox) {
      checkbox.addEventListener('change', updateSummary);
    });

    if (message) {
      message.addEventListener('input', updateRemaining);
    }

    updateSummary();
    updateRemaining();
  });

  document.querySelectorAll('[data-line-template-select]').forEach(function(select) {
    if (select.dataset.lineTemplateInitialized === 'true') return;
    select.dataset.lineTemplateInitialized = 'true';

    select.addEventListener('change', function() {
      var targetId = select.dataset.lineTemplateTarget;
      var target = document.getElementById(targetId);
      var selectedOption = select.options[select.selectedIndex];
      var body = selectedOption ? selectedOption.dataset.templateBody : '';
      if (!target || !body) return;

      target.value = body;
      target.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });
}

document.addEventListener('DOMContentLoaded', setupLearningBulkLineMessages);
document.addEventListener('turbolinks:load', setupLearningBulkLineMessages);
document.addEventListener('turbo:load', setupLearningBulkLineMessages);
