require "fastlane/action"
require_relative "../helper/appshot_helper"

module Fastlane
  module Actions
    class AppshotAction < Action
      def self.run(params)
        studio = File.expand_path(params[:studio])
        appshot_path = params[:appshot_path]
        UI.message("appshot #{Helper::AppshotHelper.appshot_version(appshot_path)}")

        app = Helper::AppshotHelper.app_name(studio, params[:app])
        config = Helper::AppshotHelper.load_config(studio, app)
        locales = Helper::AppshotHelper.selected_locales(config, params[:locales])
        slots = config.fetch("slots")
        output_directory = File.expand_path(params[:output_directory])

        if params[:raw_screenshots]
          raw_screenshots = File.expand_path(params[:raw_screenshots])
          if raw_screenshots == output_directory
            UI.user_error!("raw_screenshots and output_directory are both #{output_directory}: deliver would upload " \
                           "the raw captures next to the framed ones. Have snapshot write somewhere else, e.g. " \
                           "capture_screenshots(output_directory: \"fastlane/raw_screenshots\").")
          end
          imported_paths = Helper::AppshotHelper.import_captures(
            raw_screenshots: raw_screenshots,
            assets_folder: File.join(studio, "apps", app, "assets"),
            locales: locales,
            slots: slots,
            device: params[:device]
          )
          UI.success("Imported #{imported_paths.count} captures into apps/#{app}/assets")
        end

        render_command = [appshot_path, "render", "--root", studio, "--app", app]
        render_command += locales.flat_map { |locale| ["--locale", locale] }
        render_command += ["--chrome", params[:chrome]] if params[:chrome]
        Actions.sh(*render_command)

        copied_paths_by_locale = Helper::AppshotHelper.copy_renders(
          rendered_folder: File.join(studio, "output", app),
          output_directory: output_directory,
          locales: locales,
          slots: slots
        )
        UI.success("Copied #{copied_paths_by_locale.values.sum(&:count)} screenshots into #{output_directory}")
        copied_paths_by_locale
      end

      def self.description
        "Frame fastlane snapshot captures with appshot and hand them to deliver"
      end

      def self.authors
        ["Maksim Zhelezniakov"]
      end

      def self.return_value
        "A hash of locale => paths of the framed screenshots copied into output_directory"
      end

      def self.details
        [
          "Takes fastlane snapshot's raw captures into an appshot studio, renders the framed, captioned App Store",
          "screenshots for every locale with appshot (https://github.com/jems19s/appshot-studio), and copies them",
          "into the folder fastlane deliver uploads from. Each capture named \"<simulator>-<name>.png\" goes to the",
          "slot whose screenshot is \"<name>.png\"."
        ].join(" ")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :studio,
                                       env_name: "APPSHOT_STUDIO",
                                       description: "appshot studio: the folder holding apps/, templates/ and devices/",
                                       default_value: "appshot",
                                       type: String,
                                       verify_block: proc do |value|
                                         UI.user_error!("No appshot studio at #{value}") unless File.directory?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :app,
                                       env_name: "APPSHOT_APP",
                                       description: "App under apps/ (default: the only one there)",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :raw_screenshots,
                                       env_name: "APPSHOT_RAW_SCREENSHOTS",
                                       description: "fastlane snapshot's output_directory, one folder per locale. " \
                                                    "Leave it out to render the screenshots already in the studio",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :device,
                                       env_name: "APPSHOT_DEVICE",
                                       description: "Simulator whose captures to use, e.g. \"iPhone 17 Pro Max\". " \
                                                    "Needed only when raw_screenshots holds several devices",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :locales,
                                       env_name: "APPSHOT_LOCALES",
                                       description: "Locales to import and render (default: all the app's locales)",
                                       optional: true,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :output_directory,
                                       env_name: "APPSHOT_OUTPUT_DIRECTORY",
                                       description: "Where deliver picks up screenshots; framed PNGs go to " \
                                                    "<output_directory>/<locale>/",
                                       default_value: "fastlane/screenshots",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :appshot_path,
                                       env_name: "APPSHOT_PATH",
                                       description: "The appshot command",
                                       default_value: "appshot",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :chrome,
                                       env_name: "APPSHOT_CHROME",
                                       description: "Chrome or Chromium to render with (default: found automatically)",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.example_code
        [
          <<~LANE
            lane :screenshots do
              capture_screenshots(output_directory: "fastlane/raw_screenshots")
              appshot(raw_screenshots: "fastlane/raw_screenshots")
              upload_to_app_store(skip_binary_upload: true, skip_metadata: true)
            end
          LANE
        ]
      end

      def self.category
        :screenshots
      end

      def self.is_supported?(platform)
        %i[ios mac].include?(platform)
      end
    end
  end
end
