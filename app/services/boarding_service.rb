require "spaceship"

class AddTesterResponse
  attr_accessor :message
  attr_accessor :type
end  

class BoardingService
  include AbstractController::Translation

  attr_accessor :app
  attr_accessor :app_icon
  attr_accessor :app_id
  attr_accessor :user
  attr_accessor :password
  attr_accessor :tester_group_names
  attr_accessor :test_flight_groups
  attr_accessor :is_demo
  attr_accessor :itc_token
  attr_accessor :itc_closed_text
  attr_accessor :imprint_url

  def initialize(app_id: ENV["ITC_APP_ID"],
     tester_group_names: ENV["ITC_APP_TESTER_GROUPS"])
    @app_id = app_id 

    groups = tester_group_names.to_s.split(/\s*,\s*/)
    @tester_group_names = groups unless groups.empty?

    @test_flight_groups = []

    @is_demo = ENV["ITC_IS_DEMO"]
    @itc_token = ENV["ITC_TOKEN"]
    @itc_closed_text = ENV["ITC_CLOSED_TEXT"]
    @imprint_url = ENV["IMPRINT_URL"]

    ensure_values
  end

  def add_tester(email, first_name, last_name)
    add_tester_response = AddTesterResponse.new
    add_tester_response.type = "danger"

    begin
      @test_flight_groups.each do |group|
        beta_group_id = group.id

        attributes = {
          email: email,
          firstName: first_name,
          lastName: last_name
        }
        Spaceship::ConnectAPI.post_beta_tester_assignment(beta_group_ids: [beta_group_id], attributes: attributes)
      end
      add_tester_response.message = t(:message_success_live)
      add_tester_response.type = "success"
    rescue => ex
      Rails.logger.error "Could not add #{email} to app: #{app.name}"
      raise ex
    end

    return add_tester_response
  end

  private

    def ensure_values
      error_message = []

      error_message << "Environment variable `ITC_APP_ID` required" if @app_id.to_s.length == 0
      raise error_message.join("\n") if error_message.length > 0

      
      token = Spaceship::ConnectAPI::Token.create()
      
      Spaceship::ConnectAPI.token = token

      @app ||= Spaceship::ConnectAPI::App.get(app_id: app_id)

      build = Spaceship::ConnectAPI.get_builds(sort: "-uploadedDate", includes: "preReleaseVersion", filter: { app: app.id }, limit: 1).first

      @app_icon ||= build.icon_asset_token["templateUrl"].gsub("{w}", "120").gsub("{h}", "120").gsub("{f}", "png")

      if tester_group_names
        @test_flight_groups = Spaceship::ConnectAPI.get_beta_groups(filter: { app: @app_id }).select do |group|
          tester_group_names.include?(group.name)
        end

        test_flight_group_names = @test_flight_groups.map { |group| group.name }.to_set
        tester_group_names.select do |group_name|
          next if test_flight_group_names.include?(group_name)
          error_message << "TestFlight missing group `#{group_name}`, You need to first create this group in App Store Connect."
        end
      end

      raise error_message.join("\n") if error_message.length > 0
    end

    def testing_is_live? # TODO: clean this when Spaceship::TestFlight::BuildTrains has more attributes
      app.build_trains(platform: 'ios').values.each do |trains|
        # if train.external_testing_enabled
        #   train.builds.each do |build|
        trains.each do |build|
          return true if build.active?
        end
        #   end
        # end
      end
      return false
    end
end
