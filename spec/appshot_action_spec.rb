require "tmpdir"

describe Fastlane::Actions::AppshotAction do
  let(:project) { Dir.mktmpdir("appshot-plugin") }
  let(:studio) { File.join(project, "appshot") }
  let(:raw_screenshots) { File.join(project, "fastlane", "raw_screenshots") }
  let(:output_directory) { File.join(project, "fastlane", "screenshots") }
  let(:fake_appshot) { File.join(project, "fake-appshot") }
  let(:render_log) { File.join(project, "render.log") }

  # Stands in for the appshot binary: answers --version and, on render, writes one PNG per locale and slot
  # whose content names the asset it was made from, so tests can tell which capture ended up where.
  let(:fake_appshot_source) do
    <<~RUBY
      #!/usr/bin/env ruby
      require 'json'
      require 'fileutils'
      if ARGV == ["--version"]
        puts "1.3.0"
        exit 0
      end
      File.write(#{render_log.inspect}, ARGV.join(" "))
      root = ARGV[ARGV.index("--root") + 1]
      app = ARGV[ARGV.index("--app") + 1]
      locales = ARGV.each_index.select { |index| ARGV[index] == "--locale" }.map { |index| ARGV[index + 1] }
      config = JSON.parse(File.read(File.join(root, "apps", app, "config.json")))
      locales.each do |locale|
        FileUtils.mkdir_p(File.join(root, "output", app, locale))
        config["slots"].each do |slot|
          localized_asset = File.join(root, "apps", app, "assets", locale, slot["screenshot"])
          asset = File.exist?(localized_asset) ? localized_asset : File.join(root, "apps", app, "assets", slot["screenshot"])
          File.write(File.join(root, "output", app, locale, slot["name"] + ".png"), "framed " + File.read(asset))
        end
      end
    RUBY
  end

  before do
    FileUtils.mkdir_p(File.join(studio, "apps", "plants", "assets"))
    config = {
      "locales" => %w[en-US de-DE],
      "slots" => [
        { "name" => "01-home", "screenshot" => "home.png", "caption" => "home" },
        { "name" => "02-care", "screenshot" => "care.png", "caption" => "care" }
      ]
    }
    File.write(File.join(studio, "apps", "plants", "config.json"), JSON.generate(config))
    ["home.png", "care.png"].each do |file|
      File.write(File.join(studio, "apps", "plants", "assets", file), "studio #{file}")
    end
    File.write(fake_appshot, fake_appshot_source)
    FileUtils.chmod("+x", fake_appshot)
  end

  after { FileUtils.rm_rf(project) }

  def add_capture(locale, file, content = "#{locale} #{file}")
    FileUtils.mkdir_p(File.join(raw_screenshots, locale))
    File.write(File.join(raw_screenshots, locale, file), content)
  end

  def run_action(options = {})
    described_class.run(FastlaneCore::Configuration.create(described_class.available_options,
                                                           { studio: studio, appshot_path: fake_appshot,
                                                             output_directory: output_directory }.merge(options)))
  end

  it "imports snapshot captures per locale, renders and copies the framed PNGs for deliver" do
    %w[en-US de-DE].each do |locale|
      add_capture(locale, "iPhone 17 Pro Max-home.png")
      add_capture(locale, "iPhone 17 Pro Max-care.png")
    end

    copied_paths_by_locale = run_action(raw_screenshots: raw_screenshots)

    expect(File.read(File.join(studio, "apps", "plants", "assets", "de-DE", "care.png")))
      .to eq("de-DE iPhone 17 Pro Max-care.png")
    expect(File.read(File.join(output_directory, "de-DE",
                               "02-care.png"))).to eq("framed de-DE iPhone 17 Pro Max-care.png")
    expect(copied_paths_by_locale.keys).to eq(%w[en-US de-DE])
    expect(copied_paths_by_locale["en-US"]).to eq([File.join(output_directory, "en-US", "01-home.png"),
                                                   File.join(output_directory, "en-US", "02-care.png")])
    expect(File.read(render_log)).to eq("render --root #{studio} --app plants --locale en-US --locale de-DE")
  end

  it "renders the studio's own screenshots when there are no raw captures" do
    run_action

    expect(File.read(File.join(output_directory, "en-US", "01-home.png"))).to eq("framed studio home.png")
  end

  it "keeps the studio's screenshots for a locale snapshot didn't capture" do
    add_capture("en-US", "iPhone 17 Pro Max-home.png")
    add_capture("en-US", "iPhone 17 Pro Max-care.png")
    expect(Fastlane::UI).to receive(:important).with(/de-DE keeps the screenshots already in the studio/)

    run_action(raw_screenshots: raw_screenshots)

    expect(File.read(File.join(output_directory, "de-DE", "01-home.png"))).to eq("framed studio home.png")
  end

  it "matches simulator names that contain hyphens" do
    add_capture("en-US", "iPad Pro 13-inch (M4)-home.png")

    run_action(raw_screenshots: raw_screenshots, locales: ["en-US"])

    expect(File.read(File.join(output_directory, "en-US",
                               "01-home.png"))).to eq("framed en-US iPad Pro 13-inch (M4)-home.png")
  end

  it "asks for a device when captures from several simulators match" do
    add_capture("en-US", "iPhone 17 Pro Max-home.png")
    add_capture("en-US", "iPad Pro 13-inch (M4)-home.png")

    expect { run_action(raw_screenshots: raw_screenshots) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /end in -home.png .* set device: to the simulator name/)
  end

  it "takes only the chosen device's captures" do
    add_capture("en-US", "iPhone 17 Pro Max-home.png")
    add_capture("en-US", "iPad Pro 13-inch (M4)-home.png")

    run_action(raw_screenshots: raw_screenshots, device: "iPad Pro 13-inch (M4)", locales: ["en-US"])

    expect(File.read(File.join(output_directory, "en-US",
                               "01-home.png"))).to eq("framed en-US iPad Pro 13-inch (M4)-home.png")
  end

  it "refuses to read raw captures from the folder deliver uploads" do
    expect { run_action(raw_screenshots: output_directory) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /deliver would upload the raw captures/)
  end

  it "warns about other PNGs deliver would upload alongside" do
    FileUtils.mkdir_p(File.join(output_directory, "en-US"))
    File.write(File.join(output_directory, "en-US", "iPhone 17 Pro Max-home.png"), "raw")
    allow(Fastlane::UI).to receive(:important)

    run_action(locales: ["en-US"])

    expect(Fastlane::UI).to have_received(:important).with(/so these go up too: iPhone 17 Pro Max-home.png/)
  end

  it "rejects locales the app doesn't have" do
    expect { run_action(locales: ["fr-FR"]) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /fr-FR not in the app's locales \(en-US, de-DE\)/)
  end

  it "explains how to install appshot when it is missing" do
    expect { run_action(appshot_path: File.join(project, "no-such-appshot")) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, %r{brew install jems19s/tap/appshot})
  end

  it "points to appshot init when the studio has no app" do
    FileUtils.rm_rf(File.join(studio, "apps"))
    FileUtils.mkdir_p(File.join(studio, "apps"))

    expect { run_action }.to raise_error(FastlaneCore::Interface::FastlaneError, /create one with `appshot init`/)
  end
end
