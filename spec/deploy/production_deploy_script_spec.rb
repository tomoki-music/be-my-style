require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

# .github/workflows/rails.yml が本番サーバーへ渡すスクリプト(SSH の heredoc 部分)と script/deploy/production_deploy.sh を、
# 一時ディレクトリの疑似サーバーで実行する。本番には接続しない。
# git は本物を使い、bundle(precompile・migrate)・systemctl・curl などはスタブで置き換える。
# スタブの Puma は「ディスク上のコードのマイグレーションがすべて適用済み、かつ CSS がコンパイル済み」のときだけ正常応答する。
RSpec.describe "production deploy (.github/workflows/rails.yml + script/deploy/production_deploy.sh)" do
  REPO_ROOT = File.expand_path("../..", __dir__)

  STUBS = {
    "bundle" => <<~'SH',
      #!/usr/bin/env bash
      set -euo pipefail
      fail_at=$(cat "$SIM_DIR/fail_at" 2>/dev/null || true)
      case "$1" in
        config|check|install) exit 0 ;;
        exec) shift ;;
        *) exit 0 ;;
      esac
      [ "$1" = rails ] && shift
      for task in "$@"; do
        case "$task" in
          assets:clobber) rm -rf public/assets public/packs ;;
          assets:precompile)
            echo "precompile" >> "$SIM_DIR/events"
            if [ "$fail_at" = precompile ]; then mkdir -p public/assets; echo "stub precompile failed"; exit 1; fi
            mkdir -p public/assets public/packs
            echo '{}' > public/assets/.sprockets-manifest-stub.json
            echo '{}' > public/packs/manifest.json
            touch "public/assets/application-$(git rev-parse HEAD:app/assets).css"
            ;;
          db:migrate)
            echo "migrate" >> "$SIM_DIR/events"
            if [ "$fail_at" = migrate_connect ]; then echo "stub: cannot connect to database"; exit 1; fi
            for file in db/migrate/*.rb; do
              version=$(basename "$file" .rb)
              grep -qx "$version" "$SIM_DIR/db_applied" && continue
              if [ "$fail_at" = "migrate:$version" ]; then echo "stub: $version failed"; exit 1; fi
              echo "$version" >> "$SIM_DIR/db_applied"
              echo "migrated $version" >> "$SIM_DIR/events"
            done
            ;;
          db:abort_if_pending_migrations)
            for file in db/migrate/*.rb; do
              grep -qx "$(basename "$file" .rb)" "$SIM_DIR/db_applied" || { echo "pending migrations"; exit 1; }
            done
            ;;
          db:version) echo "Current version: $(tail -1 "$SIM_DIR/db_applied")" ;;
        esac
      done
    SH
    "sudo" => <<~'SH',
      #!/usr/bin/env bash
      [ "$1" = -n ] && shift
      if [ "$*" = "systemctl restart puma" ] && [ "$(cat "$SIM_DIR/fail_at" 2>/dev/null)" = sudo_restart ]; then
        echo "sudo: stub refused"; exit 1
      fi
      exec "$@"
    SH
    "systemctl" => <<~'SH',
      #!/usr/bin/env bash
      fail_at=$(cat "$SIM_DIR/fail_at" 2>/dev/null || true)
      [ "$2" = --quiet ] && set -- "$1" "$3"
      case "$1:$2" in
        show:puma) cat "$SIM_DIR/puma_pid" ;;
        restart:puma)
          echo "puma restart" >> "$SIM_DIR/events"
          if [ "$fail_at" = puma_start ]; then echo inactive > "$SIM_DIR/puma_state"; exit 0; fi
          echo active > "$SIM_DIR/puma_state"
          echo $(( $(cat "$SIM_DIR/puma_pid") + 1 )) > "$SIM_DIR/puma_pid"
          git -C "$DEPLOY_PATH" rev-parse HEAD > "$SIM_DIR/puma_commit"
          git -C "$DEPLOY_PATH" rev-parse HEAD:app/assets > "$SIM_DIR/puma_assets"
          ;;
        is-active:puma) [ "$(cat "$SIM_DIR/puma_state")" = active ] ;;
        status:puma) echo "puma: $(cat "$SIM_DIR/puma_state")"; [ "$(cat "$SIM_DIR/puma_state")" = active ] ;;
        restart:singing-analyzer) echo "analyzer restart" >> "$SIM_DIR/events" ;;
        is-active:singing-analyzer) exit 0 ;;
        *) exit 0 ;;
      esac
    SH
    "curl" => <<~'SH',
      #!/usr/bin/env bash
      out=/dev/stdout; format=""; url=""; socket=""
      while [ $# -gt 0 ]; do
        case "$1" in
          -o) out=$2; shift ;;
          -w) format=$2; shift ;;
          --unix-socket) socket=$2; shift ;;
          --max-time) shift ;;
          http*) url=$1 ;;
        esac
        shift
      done
      case "$url" in
        *:8000/health) echo '{"status":"ok"}'; exit 0 ;;
      esac
      if [ "$(cat "$SIM_DIR/puma_state")" != active ]; then printf 000; exit 7; fi
      path=${url#http://127.0.0.1}
      healthy=true
      for file in "$DEPLOY_PATH"/db/migrate/*.rb; do
        grep -qx "$(basename "$file" .rb)" "$SIM_DIR/db_applied" || healthy=false
      done
      [ "$(cat "$SIM_DIR/fail_at" 2>/dev/null)" = puma_health ] && healthy=false
      case "$path" in
        /assets/*)
          if [ -f "$DEPLOY_PATH/public$path" ]; then code=200; else code=404; fi
          : > "$out"
          ;;
        *)
          if [ "$healthy" = true ]; then
            code=200
            echo "<link href=\"/assets/application-$(cat "$SIM_DIR/puma_assets").css\">" > "$out"
          else
            code=500
            echo "error" > "$out"
          fi
          ;;
      esac
      echo "GET $path $code" >> "$SIM_DIR/events"
      printf '%s' "$code"
    SH
    "free" => "#!/usr/bin/env bash\necho 'Mem: 1.0Gi 2.0Gi'\n",
    "swapon" => "#!/usr/bin/env bash\necho swap\n",
    "dmesg" => "#!/usr/bin/env bash\nexit 0\n",
    "flock" => "#!/usr/bin/env bash\nexit 0\n",
  }.freeze

  attr_reader :root, :sim_dir, :server, :state_dir

  # false: このスクリプトを導入する前の main がサーバーに載っている状態(スクリプトも成功の記録も無い)
  let(:deploy_script_already_deployed) { true }

  around do |example|
    Dir.mktmpdir("deploy-spec") do |dir|
      @root = dir
      example.run
    end
  end

  before do
    @sim_dir = File.join(root, "sim")
    @server = File.join(root, "server")
    @home = File.join(root, "home")
    @state_dir = File.join(@home, ".be-my-style-deploy")
    @stub_bin = File.join(root, "bin")
    FileUtils.mkdir_p([sim_dir, @stub_bin, File.join(@home, ".rbenv/shims")])
    STUBS.each do |name, body|
      path = name == "bundle" ? File.join(@home, ".rbenv/shims/bundle") : File.join(@stub_bin, name)
      File.write(path, body)
      FileUtils.chmod(0o755, path)
    end

    @work = File.join(root, "work")
    git!(root, "init", "--bare", "-q", "-b", "main", "origin.git")
    git!(root, "clone", "-q", File.join(root, "origin.git"), "work")
    write_work("script/deploy/production_deploy.sh", File.read(File.join(REPO_ROOT, "script/deploy/production_deploy.sh"))) if deploy_script_already_deployed
    write_work("bin/yarn", "#!/usr/bin/env bash\necho yarn >> \"$SIM_DIR/events\"\n", mode: 0o755)
    write_work("db/migrate/001_base.rb", "")
    write_work("app/assets/stylesheets/a.scss", "a {}")
    write_work("singing_analyzer/app.py", "")
    write_work("singing_analyzer/requirements.txt", "")
    @base_commit = commit_and_push("base")

    # 前回のデプロイ(base)がすべて成功している状態のサーバー
    git!(root, "clone", "-q", File.join(root, "origin.git"), "server")
    FileUtils.mkdir_p([File.join(server, "node_modules"), File.join(server, "singing_analyzer/.venv/bin")])
    File.write(File.join(server, "singing_analyzer/.venv/bin/pip"), "#!/usr/bin/env bash\necho pip >> \"$SIM_DIR/events\"\n")
    FileUtils.chmod(0o755, File.join(server, "singing_analyzer/.venv/bin/pip"))
    File.write(File.join(sim_dir, "db_applied"), "001_base\n")
    File.write(File.join(sim_dir, "puma_pid"), "100\n")
    File.write(File.join(sim_dir, "puma_state"), "active\n")
    File.write(File.join(sim_dir, "puma_commit"), "#{@base_commit}\n")
    File.write(File.join(sim_dir, "puma_assets"), "#{git!(server, 'rev-parse', 'HEAD:app/assets')}\n")
    bash!(server, %(RAILS_ENV=production "$HOME/.rbenv/shims/bundle" exec rails assets:precompile))
    if deploy_script_already_deployed
      FileUtils.mkdir_p(state_dir)
      File.write(File.join(state_dir, "last_successful_commit"), "#{@base_commit}\n")
      File.write(File.join(state_dir, "assets_precompiled_commit"), "#{@base_commit}\n")
    end
    File.write(File.join(sim_dir, "events"), "")

    # 今回のリリース: マイグレーション2本 + CSS 変更
    write_work("db/migrate/002_add_column.rb", "")
    write_work("db/migrate/003_create_table.rb", "")
    write_work("app/assets/stylesheets/a.scss", "a { color: red; }")
    write_work("script/deploy/production_deploy.sh", File.read(File.join(REPO_ROOT, "script/deploy/production_deploy.sh")))
    @release_commit = commit_and_push("release")
  end

  def git!(dir, *args)
    out, status = Open3.capture2e("git", "-c", "user.name=spec", "-c", "user.email=spec@example.com", *args, chdir: dir)
    raise "git #{args.join(' ')} failed: #{out}" unless status.success?

    out.strip
  end

  def write_work(path, content, mode: nil)
    full = File.join(@work, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    FileUtils.chmod(mode, full) if mode
  end

  def commit_and_push(message)
    git!(@work, "add", "-A")
    git!(@work, "commit", "-q", "-m", message)
    git!(@work, "push", "-q", "origin", "HEAD:main")
    git!(@work, "rev-parse", "HEAD")
  end

  def env
    {
      "HOME" => @home,
      "PATH" => "#{@stub_bin}:#{ENV.fetch('PATH')}",
      "SIM_DIR" => sim_dir,
      "PUMA_SOCKET" => File.join(root, "puma.sock"),
      "RETRY_INTERVAL" => "0",
      "PRECOMPILE_POLL_INTERVAL" => "0.1",
      "PUMA_ACTIVE_ATTEMPTS" => "2",
      "PUMA_HEALTH_ATTEMPTS" => "2",
      "DB_PASSWORD" => "secret-sentinel-value",
    }
  end

  def bash!(dir, command)
    out, status = Open3.capture2e(env.merge("DEPLOY_PATH" => dir), "bash", "-c", command, chdir: dir)
    raise "#{command} failed: #{out}" unless status.success?
  end

  # SSH 先で `DEPLOY_PATH=... FORCE_...=... bash -s` に渡される heredoc を、ワークフローから取り出したもの。
  def remote_script
    run = YAML.load_file(File.join(REPO_ROOT, ".github/workflows/rails.yml"))
              .dig("jobs", "build", "steps").find { |step| step["name"] == "Deploy" }["run"]
    run[/bash -s" << 'EOF'\n(.*?)^EOF$/m, 1].gsub(/^  /, "")
  end

  def deploy(fail_at: nil, **extra_env)
    fail_file = File.join(sim_dir, "fail_at")
    fail_at ? File.write(fail_file, fail_at) : FileUtils.rm_f(fail_file)
    File.write(File.join(sim_dir, "events"), "")
    variables = { "DEPLOY_PATH" => server, "FORCE_ASSETS_CLOBBER" => "false", "FORCE_FULL_DEPLOY" => "false" }
    out, status = Open3.capture2e(env.merge(variables).merge(extra_env), "bash", "-s", stdin_data: remote_script, chdir: root)
    [out, status.success?]
  end

  def events = File.readlines(File.join(sim_dir, "events"), chomp: true)
  def applied = File.readlines(File.join(sim_dir, "db_applied"), chomp: true)
  def puma_commit = File.read(File.join(sim_dir, "puma_commit")).strip
  def last_success = File.read(File.join(state_dir, "last_successful_commit")).strip

  def expect_fully_deployed
    expect(applied).to eq(%w[001_base 002_add_column 003_create_table])
    expect(puma_commit).to eq(@release_commit)
    expect(events).to include("GET / 200")
    expect(events.grep(%r{\AGET /assets/application-\h+\.css 200\z})).not_to be_empty
    expect(last_success).to eq(@release_commit)
  end

  it "precompile → migrate → Puma 再起動 → HTTP 確認の順で実行し、成功を記録する" do
    out, ok = deploy

    expect(ok).to be(true), out
    expect(events.first(4)).to eq(%w[precompile migrate migrated\ 002_add_column migrated\ 003_create_table])
    expect(events[4]).to eq("puma restart")
    expect_fully_deployed
    expect(events).not_to include("analyzer restart")
    expect(out).not_to include("secret-sentinel-value")
  end

  it "precompile が失敗したら DB を変更せず Puma も再起動しない。同じコミットの再実行で復旧する" do
    out, ok = deploy(fail_at: "precompile")

    expect(ok).to be(false)
    expect(out).to include("::error::deploy failed at step 'assets check/precompile'")
    expect(events).to eq(["precompile"])
    expect(applied).to eq(["001_base"])
    expect(puma_commit).to eq(@base_commit)
    expect(git!(server, "rev-parse", "HEAD")).to eq(@release_commit)
    expect(last_success).to eq(@base_commit)

    out, ok = deploy
    expect(ok).to be(true), out
    expect(events).to include("precompile", "migrate", "puma restart")
    expect_fully_deployed
  end

  it "precompile 成功後に migrate が始められなくても、再実行では precompile をやり直さずに復旧する" do
    _, ok = deploy(fail_at: "migrate_connect")

    expect(ok).to be(false)
    expect(events).to eq(%w[precompile migrate])
    expect(puma_commit).to eq(@base_commit)

    out, ok = deploy
    expect(ok).to be(true), out
    expect(events).not_to include("precompile")
    expect(out).to include("Skip assets:precompile: already precompiled for #{@release_commit}")
    expect_fully_deployed
  end

  it "migrate が途中で失敗しても、再実行で残りのマイグレーションだけを適用して復旧する" do
    out, ok = deploy(fail_at: "migrate:003_create_table")

    expect(ok).to be(false)
    expect(out).to include("::error::deploy failed at step 'db:migrate'")
    expect(out).to include("Puma was NOT restarted")
    expect(applied).to eq(%w[001_base 002_add_column])
    expect(events).not_to include("puma restart")

    out, ok = deploy
    expect(ok).to be(true), out
    expect(events).to include("migrated 003_create_table")
    expect(events).not_to include("migrated 002_add_column")
    expect_fully_deployed
  end

  it "migrate 成功後、Puma 再起動の前に失敗しても、再実行で(migrate は空振りして)Puma を再起動して復旧する" do
    _, ok = deploy(fail_at: "sudo_restart")

    expect(ok).to be(false)
    expect(applied).to eq(%w[001_base 002_add_column 003_create_table])
    expect(puma_commit).to eq(@base_commit)
    expect(last_success).to eq(@base_commit)

    out, ok = deploy
    expect(ok).to be(true), out
    expect(events).to include("migrate", "puma restart")
    expect(events.grep(/\Amigrated /)).to be_empty
    expect_fully_deployed
  end

  it "Puma が起動しなければ失敗として扱い、成功を記録しない。再実行で復旧する" do
    out, ok = deploy(fail_at: "puma_start")

    expect(ok).to be(false)
    expect(out).to include("Puma is not active after restart")
    expect(out).to include("::error::deploy failed at step 'puma restart'")
    expect(last_success).to eq(@base_commit)

    out, ok = deploy
    expect(ok).to be(true), out
    expect_fully_deployed
  end

  it "Puma は起動したが HTTP 応答が異常なら失敗として扱い、成功を記録しない。再実行で復旧する" do
    out, ok = deploy(fail_at: "puma_health")

    expect(ok).to be(false)
    expect(out).to include("::error::deploy failed at step 'puma health check'")
    expect(out).to include("HTTP 500")
    expect(last_success).to eq(@base_commit)

    out, ok = deploy
    expect(ok).to be(true), out
    expect_fully_deployed
  end

  it "Puma が参照する CSS が配信できなければ失敗として扱い、再実行では precompile をやり直して復旧する" do
    deploy
    Dir.glob(File.join(server, "public/assets/application-*.css")).each { |file| File.delete(file) }

    out, ok = deploy
    expect(ok).to be(false)
    expect(out).to include("compiled stylesheet")
    expect(out).to include("::error::deploy failed at step 'puma health check'")

    out, ok = deploy
    expect(ok).to be(true), out
    expect(events).to include("precompile")
    expect_fully_deployed
  end

  it "全工程が成功した後の再実行でも migrate・Puma 再起動・確認を省略せず、precompile は行わない" do
    deploy
    out, ok = deploy

    expect(ok).to be(true), out
    expect(events).to include("migrate", "puma restart", "GET / 200")
    expect(events).not_to include("precompile")
    expect(last_success).to eq(@release_commit)
  end

  it "成功の記録が無いとき(このワークフローでの初回)はすべて変更ありとして扱う" do
    FileUtils.rm_f(File.join(state_dir, "last_successful_commit"))
    FileUtils.rm_f(File.join(state_dir, "assets_precompiled_commit"))

    out, ok = deploy

    expect(ok).to be(true), out
    expect(out).to include("No successful deploy recorded; treating everything as changed")
    expect(events).to include("yarn", "precompile", "pip", "analyzer restart")
    expect_fully_deployed
  end

  it "記録されたコミットがサーバーに無い(履歴の書き換え等)ときもすべて変更ありとして扱う" do
    File.write(File.join(state_dir, "last_successful_commit"), "#{'0' * 40}\n")

    out, ok = deploy

    expect(ok).to be(true), out
    expect(out).to include("is not available locally; treating everything as changed")
    expect(events).to include("analyzer restart")
  end

  context "このスクリプトを導入するデプロイ(サーバーにはスクリプトも成功の記録も無い)" do
    let(:deploy_script_already_deployed) { false }

    it "git reset 後の新しいスクリプトがすべての工程を実行し、途中で失敗しても再実行で復旧する" do
      expect(File.exist?(File.join(server, "script/deploy/production_deploy.sh"))).to be(false)

      out, ok = deploy(fail_at: "migrate:003_create_table")
      expect(ok).to be(false)
      expect(out).to include("No successful deploy recorded; treating everything as changed")
      expect(File.exist?(File.join(state_dir, "last_successful_commit"))).to be(false)

      out, ok = deploy
      expect(ok).to be(true), out
      expect(events).to include("yarn", "analyzer restart")
      expect_fully_deployed
    end
  end

  it "古いコミットで起動した実行を再実行しても、デプロイするのはその時点の origin/main" do
    out, ok = deploy("TRIGGER_COMMIT" => @base_commit)

    expect(ok).to be(true), out
    expect(out).to include("::notice::this run was triggered by #{@base_commit} but deploys the current origin/main #{@release_commit}")
    expect_fully_deployed
  end

  it "singing_analyzer の変更は、Puma 側の失敗で中断しても再実行時に反映される" do
    write_work("singing_analyzer/app.py", "changed")
    @release_commit = commit_and_push("analyzer change")

    _, ok = deploy(fail_at: "puma_health")
    expect(ok).to be(false)
    expect(events).not_to include("analyzer restart")

    out, ok = deploy
    expect(ok).to be(true), out
    expect(events).to include("analyzer restart")
  end
end
