require 'jenkins_api_client'
require 'yaml'
require 'rest-client'
require 'json'
require 'net/http'
require 'uri'

module Jenkins
  Credentials = YAML.load_file(File.expand_path('./jenkins.yml'))
  Client = JenkinsApi::Client.new(Credentials.merge({:log_level => 4}))

  class Build
    attr_reader :job
    attr_reader :buildNo

    def initialize(job, buildNo)
      @job = job
      @buildNo = buildNo
      @details = nil
    end

    def status
      return Client.job.get_current_build_status(@assignment_job_name)
    end

    def details(force: true)
      if @details == nil || force then
        @details = Client.job.get_build_details(@job.jobName, @buildNo)
      end
      return @details
    end

    def artifacts()
      return self.details["artifacts"]
    end

    def downloadArtifact(artifact, baseUrl: nil) # NOTE: this input is the artifact object from artifacts
      if baseUrl.nil? then
        baseUrl = self.details(:force => false)["url"]
      end

      uri = URI.parse("#{baseUrl}/artifact/#{artifact["relativePath"]}")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(Credentials["username"], Credentials["password"])
      response = http.request(request)

      return response.body
    end
  end

  class Job
    attr_reader :jobName
    def initialize(jobName)
      @jobName = jobName
    end

    def rebuild(env=nil) # NOTE: this can throw connection exceptions etc.
      buildNo = Client.job.build(@jobName, env || {}, {
          "build_start_timeout" => 30,
          "poll_interval" => 1
        })
      return getBuild(buildNo)
    end

    def currentBuild
      result = Client.job.get_current_build_number(@jobName)
      if result > 0 then
        return getBuild(result)
      else
        return nil
      end
    end

    def getBuild(buildNo)
      return Build.new(self, buildNo)
    end

    def exists?
      return Client.job.exists?(@jobName)
    end

    def destroy!
      return Client.job.delete(@jobName)
    end
  end

  JobSetupAssignment = Job.new('AnacapaGrader-setupAssignment')

  class Assignment
    attr_reader :gitProviderDomain
    attr_reader :courseOrg
    attr_reader :credentials_id
    attr_reader :credentialsId
    attr_reader :labName

    attr_reader :jobGrader
    attr_reader :jobInstructor

    def initialize(gitProviderDomain:, courseOrg:, credentialsId:, labName:)
      @gitProviderDomain = gitProviderDomain
      @courseOrg = courseOrg
      @credentialsId = credentialsId
      @labName = labName

      @jobInstructor = Job.new("AnacapaGrader #{@gitProviderDomain} #{@courseOrg} assignment-#{@labName}")
      @jobGrader = Job.new("AnacapaGrader #{@gitProviderDomain} #{@courseOrg} grader-#{@labName}")
    end

    def checkJenkinsState
      # checks that the projects exist on jenkins
      if !@jobInstructor.exists? || !@jobGrader.exists? then
        # trigger a rebuild of both the instructor and grader jobs...
        begin
          @jobInstructor.destroy!
        rescue

        end
        begin
          @jobGrader.destroy!
        rescue
        end

        setupBuild = JobSetupAssignment.rebuild({
            "git_provider_domain" => @gitProviderDomain,
            "course_org" => @courseOrg,
            "credentials_id" => @credentialsId,
            "lab_name" => @labName
          })

        details = nil
        loop do
          details = setupBuild.details()
          break if !details.key?("building") || !details["building"]
          sleep(1)
        end

        raise "An error was encountered while running the grader jobs. Status: #{details["result"]}" unless details["result"] == "SUCCESS"
        raise "Failed to create the expected jobs." unless !@jobInstructor.exists? || !@jobGrader.exists?

      end
    end
  end

end

assignment = Jenkins::Assignment.new(
  gitProviderDomain: "github.com",
  courseOrg: "ucsb-cs-test-org-1", # test
  credentialsId: "github.com-gareth-machine-user",
  labName: "lab00"
)

assignment.checkJenkinsState

currentBuild = assignment.jobInstructor.currentBuild
if currentBuild.nil? then
  assignment.jobInstructor.rebuild
  currentBuild = assignment.jobInstructor.currentBuild
end

for artifact in currentBuild.artifacts
  puts(currentBuild.downloadArtifact(artifact))
end
