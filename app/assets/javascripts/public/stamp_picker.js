// スタンプ選択パネルの開閉・タブ切替の制御。
// マークアップは app/views/shared/_stamp_picker.html.haml。
// - トグルボタンでパネルを開閉し、aria-expanded / hidden を同期する
// - パネル外クリック・Escape で閉じる
// - 開いたら選択中のタブへフォーカスを移す（キーボード操作への配慮）
// - 「シンプル / 人物 / どうぶつ」タブの切替（aria-selected / tabindex / パネルの hidden を同期）。
//   タブ切替では送信しない。矢印キー・Home / End でのタブ移動に対応する。
// イベントは document へ委譲するため、Ajax でフォームが再描画されても動作し続ける。
// スタンプ送信自体は各 mini フォームの submit（rails-ujs の confirm 経由）に任せる。
(function () {
  'use strict';

  function closePicker(picker) {
    var toggle = picker.querySelector('[data-stamp-picker-toggle]');
    var panel = picker.querySelector('[data-stamp-picker-panel]');
    if (!toggle || !panel) return;
    panel.hidden = true;
    toggle.setAttribute('aria-expanded', 'false');
  }

  function openPicker(picker) {
    var toggle = picker.querySelector('[data-stamp-picker-toggle]');
    var panel = picker.querySelector('[data-stamp-picker-panel]');
    if (!toggle || !panel) return;
    panel.hidden = false;
    toggle.setAttribute('aria-expanded', 'true');
    var selectedTab = panel.querySelector('[role="tab"][aria-selected="true"]') || panel.querySelector('[role="tab"]');
    if (selectedTab) selectedTab.focus();
  }

  function closeAll(except) {
    document.querySelectorAll('[data-stamp-picker]').forEach(function (picker) {
      if (picker !== except) closePicker(picker);
    });
  }

  function tabsOf(picker) {
    return Array.prototype.slice.call(picker.querySelectorAll('[role="tab"][data-stamp-tab]'));
  }

  function selectTab(picker, category, focusTab) {
    tabsOf(picker).forEach(function (tab) {
      var isTarget = tab.dataset.stampTab === category;
      tab.setAttribute('aria-selected', isTarget ? 'true' : 'false');
      tab.tabIndex = isTarget ? 0 : -1;
      if (isTarget && focusTab) tab.focus();
    });
    picker.querySelectorAll('[data-stamp-tabpanel]').forEach(function (panel) {
      panel.hidden = panel.dataset.stampTabpanel !== category;
    });
  }

  function onToggleClick(event) {
    var toggle = event.target.closest('[data-stamp-picker-toggle]');
    if (!toggle) return;
    var picker = toggle.closest('[data-stamp-picker]');
    if (!picker) return;
    var isOpen = toggle.getAttribute('aria-expanded') === 'true';
    closeAll(picker);
    if (isOpen) {
      closePicker(picker);
    } else {
      openPicker(picker);
    }
  }

  function onTabClick(event) {
    var tab = event.target.closest('[role="tab"][data-stamp-tab]');
    if (!tab) return;
    var picker = tab.closest('[data-stamp-picker]');
    if (!picker) return;
    event.preventDefault();
    selectTab(picker, tab.dataset.stampTab, false);
  }

  function onDocumentClick(event) {
    if (event.target.closest('[data-stamp-picker]')) return;
    closeAll(null);
  }

  function onTablistKeydown(event) {
    var tab = event.target.closest('[role="tab"][data-stamp-tab]');
    if (!tab) return;
    var picker = tab.closest('[data-stamp-picker]');
    if (!picker) return;
    var tabs = tabsOf(picker);
    var current = tabs.indexOf(tab);
    var next = null;
    switch (event.key) {
      case 'ArrowRight':
      case 'ArrowDown':
        next = (current + 1) % tabs.length;
        break;
      case 'ArrowLeft':
      case 'ArrowUp':
        next = (current - 1 + tabs.length) % tabs.length;
        break;
      case 'Home':
        next = 0;
        break;
      case 'End':
        next = tabs.length - 1;
        break;
      default:
        return;
    }
    event.preventDefault();
    selectTab(picker, tabs[next].dataset.stampTab, true);
  }

  function onKeydown(event) {
    if (event.key === 'Escape' || event.key === 'Esc') {
      var openToggle = document.querySelector('[data-stamp-picker] [data-stamp-picker-toggle][aria-expanded="true"]');
      if (!openToggle) return;
      var picker = openToggle.closest('[data-stamp-picker]');
      closePicker(picker);
      openToggle.focus();
      return;
    }
    onTablistKeydown(event);
  }

  function bind() {
    if (document.body.dataset.stampPickerBound === 'true') return;
    document.body.dataset.stampPickerBound = 'true';
    document.addEventListener('click', onToggleClick);
    document.addEventListener('click', onTabClick);
    document.addEventListener('click', onDocumentClick);
    document.addEventListener('keydown', onKeydown);
  }

  document.addEventListener('turbolinks:load', bind);
  document.addEventListener('DOMContentLoaded', bind);
})();
