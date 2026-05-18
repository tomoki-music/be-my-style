document.addEventListener("turbolinks:load", () => {
  const section = document.getElementById("rmp-generate-section");
  if (!section) return;

  const year       = section.dataset.year;
  const requestUrl = section.dataset.requestUrl;
  const statusUrl  = section.dataset.statusUrl;
  const csrfToken  = () => { var m = document.querySelector('meta[name="csrf-token"]'); return m && m.content; };

  let pollTimer = null;

  const el = {
    intro:       document.getElementById("rmp-intro"),
    generateBtn: document.getElementById("rmp-generate-btn"),
    retryBtn:    document.getElementById("rmp-retry-btn"),
    statusArea:  document.getElementById("rmp-status-area"),
    statusMsg:   document.getElementById("rmp-status-msg"),
    spinner:     document.getElementById("rmp-spinner"),
    videoArea:   document.getElementById("rmp-video-area"),
    videoLink:   document.getElementById("rmp-video-link"),
    retryArea:   document.getElementById("rmp-retry-area"),
    emptyMsg:    document.getElementById("rmp-empty-msg"),
  };

  const show = (e) => e && (e.style.display = "");
  const hide = (e) => e && (e.style.display = "none");

  const setState = (state, data) => {
    data = data || {};
    hide(el.intro);
    hide(el.generateBtn);
    hide(el.statusArea);
    hide(el.videoArea);
    hide(el.retryArea);
    hide(el.emptyMsg);

    switch (state) {
      case "idle":
        show(el.intro);
        show(el.generateBtn);
        break;
      case "loading":
        show(el.statusArea);
        show(el.spinner);
        if (el.statusMsg) el.statusMsg.textContent = "Recap Movieを生成中です…";
        break;
      case "completed":
        show(el.statusArea);
        hide(el.spinner);
        if (el.statusMsg) el.statusMsg.textContent = "Recap Movieが完成しました！";
        if (data.videoUrl) {
          show(el.videoArea);
          if (el.videoLink) el.videoLink.href = data.videoUrl;
        }
        break;
      case "failed":
        show(el.statusArea);
        hide(el.spinner);
        if (el.statusMsg) el.statusMsg.textContent = "生成に失敗しました。もう一度お試しください。";
        show(el.retryArea);
        break;
      case "empty_source":
        show(el.emptyMsg);
        break;
    }
  };

  const stopPolling = () => {
    clearInterval(pollTimer);
    pollTimer = null;
  };

  const startPolling = () => {
    stopPolling();
    pollTimer = setInterval(checkStatus, 4000);
  };

  const checkStatus = () => {
    fetch(statusUrl + "?year=" + year, { headers: { Accept: "application/json" } })
      .then((r) => r.json())
      .then((data) => {
        if (data.status === "completed") {
          stopPolling();
          setState("completed", { videoUrl: data.movie && data.movie.video_url });
        } else if (data.status === "failed" || data.status === "expired") {
          stopPolling();
          setState("failed");
        }
        // pending / processing: 引き続き polling、表示はそのまま
      })
      .catch(() => {
        stopPolling();
        setState("failed");
      });
  };

  const requestGenerate = () => {
    setState("loading");
    fetch(requestUrl + "?year=" + year, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken(),
        Accept: "application/json",
        "Content-Type": "application/json",
      },
    })
      .then((r) => r.json())
      .then((data) => {
        if (data.status === "empty_source") {
          setState("empty_source");
        } else if (data.status === "reused_completed" || data.status === "completed") {
          stopPolling();
          setState("completed", { videoUrl: data.movie && data.movie.video_url });
        } else if (
          data.status === "created_pending"  ||
          data.status === "reset_pending"    ||
          data.status === "already_pending"  ||
          data.status === "already_processing"
        ) {
          startPolling();
        } else {
          setState("failed");
        }
      })
      .catch(() => setState("failed"));
  };

  // ページ読み込み時に既存ステータスを確認
  fetch(statusUrl + "?year=" + year, { headers: { Accept: "application/json" } })
    .then((r) => r.json())
    .then((data) => {
      if (data.status === "completed") {
        setState("completed", { videoUrl: data.movie && data.movie.video_url });
      } else if (data.status === "pending" || data.status === "processing") {
        setState("loading");
        startPolling();
      } else {
        setState("idle");
      }
    })
    .catch(() => setState("idle"));

  el.generateBtn && el.generateBtn.addEventListener("click", requestGenerate);
  el.retryBtn    && el.retryBtn.addEventListener("click", requestGenerate);
});
