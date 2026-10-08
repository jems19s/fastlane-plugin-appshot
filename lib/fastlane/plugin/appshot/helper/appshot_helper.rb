require "fastlane_core/ui/ui"
require "fileutils"
require "json"
require "open3"

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class AppshotHelper
      INSTALL_HINT = "Install it with `brew install jems19s/tap/appshot`, or point appshot_path at the binary.".freeze

      def self.appshot_version(appshot_path)
        version_output, status = Open3.capture2e(appshot_path, "--version")
        unless status.success?
          UI.user_error!("`#{appshot_path} --version` failed: #{version_output.strip}. #{INSTALL_HINT}")
        end
        version_output.strip
      rescue Errno::ENOENT
        UI.user_error!("appshot not found at '#{appshot_path}'. #{INSTALL_HINT}")
      end

      def self.app_name(studio, requested_app)
        return requested_app if requested_app

        apps_folder = File.join(studio, "apps")
        app_names = Dir.exist?(apps_folder) ? Dir.children(apps_folder) : []
        app_names = app_names.select { |entry| File.exist?(File.join(apps_folder, entry, "config.json")) }.sort
        return app_names.first if app_names.count == 1

        UI.user_error!("No appshot app in #{apps_folder} yet — create one with `appshot init`") if app_names.empty?
        UI.user_error!("Several apps in #{apps_folder}: #{app_names.join(', ')} — pick one with app:")
      end

      def self.load_config(studio, app)
        config_path = File.join(studio, "apps", app, "config.json")
        unless File.exist?(config_path)
          UI.user_error!("No appshot app at #{config_path} — create one with `appshot init`")
        end
        JSON.parse(File.read(config_path))
      end

      def self.selected_locales(config, requested_locales)
        configured_locales = config.fetch("locales")
        return configured_locales if requested_locales.nil? || requested_locales.empty?

        unknown_locales = requested_locales - configured_locales
        unless unknown_locales.empty?
          UI.user_error!("#{unknown_locales.join(', ')} not in the app's locales (#{configured_locales.join(', ')})")
        end
        requested_locales
      end

      def self.import_captures(raw_screenshots:, assets_folder:, locales:, slots:, device:)
        imported_paths = []
        locales.each do |locale|
          capture_folder = File.join(raw_screenshots, locale)
          unless File.directory?(capture_folder)
            UI.important("No #{capture_folder} — #{locale} keeps the screenshots already in the studio")
            next
          end
          capture_files = Dir.children(capture_folder).select { |file| file.end_with?(".png") }
          slots.each do |slot|
            screenshot = slot.fetch("screenshot")
            capture = capture_for(screenshot, capture_files, capture_folder, device)
            next if capture.nil?

            locale_assets_folder = File.join(assets_folder, locale)
            FileUtils.mkdir_p(locale_assets_folder)
            FileUtils.cp(File.join(capture_folder, capture), File.join(locale_assets_folder, screenshot))
            imported_paths << File.join(locale_assets_folder, screenshot)
          end
        end
        imported_paths
      end

      # fastlane snapshot saves "<simulator name>-<name>.png"; simulator names can contain hyphens themselves,
      # so captures are matched by their "-<slot screenshot>" ending rather than split at the first hyphen.
      def self.capture_for(screenshot, capture_files, capture_folder, device)
        if device
          capture = "#{device}-#{screenshot}"
          return capture if capture_files.include?(capture)

          UI.important("No #{capture} in #{capture_folder}")
          return nil
        end

        matching_captures = capture_files.select { |file| file.end_with?("-#{screenshot}") }.sort
        if matching_captures.count > 1
          UI.user_error!("Several captures in #{capture_folder} end in -#{screenshot} " \
                         "(#{matching_captures.join(', ')}) — set device: to the simulator name")
        end
        UI.important("No capture ending in -#{screenshot} in #{capture_folder}") if matching_captures.empty?
        matching_captures.first
      end

      def self.copy_renders(rendered_folder:, output_directory:, locales:, slots:)
        rendered_files = slots.map { |slot| "#{slot.fetch('name')}.png" }
        locales.to_h do |locale|
          destination_folder = File.join(output_directory, locale)
          FileUtils.mkdir_p(destination_folder)
          other_files = Dir.children(destination_folder).select { |file|
            file.downcase.end_with?(".png")
          } - rendered_files
          unless other_files.empty?
            UI.important("deliver uploads every PNG in #{destination_folder}, " \
                         "so these go up too: #{other_files.sort.join(', ')}")
          end
          copied_paths = rendered_files.map do |file|
            destination = File.join(destination_folder, file)
            FileUtils.cp(File.join(rendered_folder, locale, file), destination)
            destination
          end
          [locale, copied_paths]
        end
      end
    end
  end
end
