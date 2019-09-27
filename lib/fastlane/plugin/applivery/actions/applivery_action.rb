require 'faraday'

module Fastlane
  module Actions

    module SharedValues
      APPLIVERY_BUILD_ID = :APPLIVERY_BUILD_ID
    end

    class AppliveryAction < Action

      def self.run(params)
        build_path = params[:build_path]
        build = Faraday::UploadIO.new(build_path, 'application/octet-stream') if build_path && File.exist?(build_path)

        conn = Faraday.new(url: 'https://api.applivery.io') do |faraday|
          faraday.request :multipart
          faraday.request :url_encoded
          # faraday.response :logger
          faraday.use FaradayMiddleware::ParseJson
          faraday.adapter :net_http
        end

        response = conn.post do |req|
          req.url '/v1/integrations/builds'
          req.headers['Content-Type'] = 'multipart/form-data'
          req.headers['Accept'] = 'application/json'
          req.headers['Authorization'] = "bearer #{params[:app_token]}"
          request_body = {
            changelog: params[:changelog],
            notifyCollaborators: params[:notify_collaborators],
            notifyEmployees: params[:notify_employees],
            notifyMessage: params[:notify_message],
            build: build,
            deployer: {
              name: "fastlane",
              info: {
                buildNumber: Helper::AppliveryHelper.get_integration_number,
                branch: Helper::AppliveryHelper.git_branch,
                commit: Helper::AppliveryHelper.git_commit,
                commitMessage: Helper::AppliveryHelper.git_message,
                repositoryUrl: Helper::AppliveryHelper.add_git_remote,
                tag: Helper::AppliveryHelper.git_tag,
                triggerTimestamp: Time.now.getutc.to_i
              } 
            }
          }
          request_body[:versionName] = params[:name] if !params[:name].nil?
          request_body[:tags] = params[:tags] if !params[:tags].nil?

          req.body = request_body
          UI.message "Uploading to Applivery... 🛫"
          UI.verbose("Request Body: #{req.body}")
        end
        UI.verbose "Response Body: #{response.body}"
        status = response.body["status"]
        Actions.lane_context[SharedValues::APPLIVERY_BUILD_ID] = response.body["data"]["id"]
        if status
          UI.success "Build uploaded succesfully! 💪"
        else
          UI.error "Oops! Something went wrong.... 🔥"
          Helper::AppliveryHelper.parse_error(response.error)
        end

      end

      def self.build_path
        platform = Actions.lane_context[Actions::SharedValues::PLATFORM_NAME]

        if platform == :ios
          return Actions.lane_context[SharedValues::IPA_OUTPUT_PATH]
        else
          return Actions.lane_context[Actions::SharedValues::GRADLE_APK_OUTPUT_PATH]
        end
      end

      def self.description
        "Upload new iOS or Android build to Applivery"
      end

      def self.authors
        ["Alejandro Jimenez", "Cesar Trigo"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :app_token,
            env_name: "APPLIVERY_APP_TOKEN",
            description: "Your application identifier",
            optional: false,
            type: String),

          FastlaneCore::ConfigItem.new(key: :name,
            env_name: "APPLIVERY_BUILD_NAME",
            description: "Your build name",
            optional: true,
            type: String),

          FastlaneCore::ConfigItem.new(key: :changelog,
            env_name: "APPLIVERY_BUILD_CHANGELOG",
            description: "Your build notes",
            default_value: "Uploaded automatically with fastlane plugin",
            optional: true,
            type: String),

          FastlaneCore::ConfigItem.new(key: :tags,
            env_name: "APPLIVERY_BUILD_TAGS",
            description: "Your build tags",
            optional: true,
            type: String),

          FastlaneCore::ConfigItem.new(key: :build_path,
            env_name: "APPLIVERY_BUILD_PATH",
            description: "Your build path",
            default_value: self.build_path,
            optional: true,
            type: String),

          FastlaneCore::ConfigItem.new(key: :notify_collaborators,
            env_name: "APPLIVERY_NOTIFY_COLLABORATORS",
            description: "Send an email to your App Collaborators",
            default_value: true,
            optional: true,
            is_string: false),

          FastlaneCore::ConfigItem.new(key: :notify_employees,
            env_name: "APPLIVERY_NOTIFY_EMPLOYEES",
            description: "Send an email to your App Employees",
            default_value: true,
            optional: true,
            is_string: false),

          FastlaneCore::ConfigItem.new(key: :notify_message,
            env_name: "APPLIVERY_NOTIFY_MESSAGE",
            description: "Notification message to be sent along with email notifications",
            default_value: "New version uploaded!",
            optional: true,
            type: String),

        ]
      end

      def self.output
        [
          ['APPLIVERY_BUILD_ID', 'The id for the new build generated. You can open your build in https://dashboard.applivery.io/apps/apps/<YOUR_APP_SLUG>/builds?id=${APPLIVERY_BUILD_ID}']
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Platforms.md
        
        [:ios, :android].include?(platform)
        true
      end

      def self.category
        :beta
      end

      def self.example_code
        [
          'applivery(app_token: "YOUR_APP_TOKEN")'
        ]
      end

    end
  end
end
