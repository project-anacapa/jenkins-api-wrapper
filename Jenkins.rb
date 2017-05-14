require 'jenkins_api_client'
require 'yaml'
require 'rest-client'

credentials =


module Jenkins
  Client = JenkinsApi::Client.new(YAML.load_file(File.expand_path('./jenkins.yml')).merge({:log_level => 4}))

  JOB_SETUP_ASSIGNMENT = 'AnacapaGrader-setupAssignment'

  class Lab
    attr_reader :git_provider_domain
    attr_reader :course_org
    attr_reader :credentials_id
    attr_reader :assignment_job_name
    attr_reader :grader_job_name

    def initialize(git_provider_domain:, course_org:, credentials_id:, lab_name:)
      @git_provider_domain = git_provider_domain
      @course_org = course_org
      @credentials_id = credentials_id
      @lab_name = lab_name

      @assignment_job_name = "AnacapaGrader #{@git_provider_domain} #{@course_org} assignment-#{@lab_name}"
      @grader_job_name = "AnacapaGrader #{@git_provider_domain} #{@course_org} grader-#{@lab_name}"
    end

    def jobsExist?
      return Client.job.exists?(@assignment_job_name) && Client.job.exists?(@grader_job_name)
    end

    def makeGraderAndAssignentIfNotExist()
      if !jobsExist?
        puts "jobsExist? failed to locate the grader and assignment jobs. Creating them now..."
        begin
          Client.job.delete(@assignment_job_name)
        rescue
        end
        begin
          Client.job.delete(@grader_job_name)
        rescue
        end

        build_number = Client.job.build(JOB_SETUP_ASSIGNMENT, {
          "git_provider_domain" => @git_provider_domain,
          "course_org" => @course_org,
          "credentials_id" => @credentials_id,
          "lab_name" => @lab_name
        }, {
          "build_start_timeout" => 60,
          "poll_interval" => 2
        })

        buildDetails = Client.job.get_build_details(JOB_SETUP_ASSIGNMENT, build_number)

        if buildDetails["result"] != "SUCCESS"
          raise "failed to create grader and or assignment jobs. Status: #{buildDetails['result']}"
        end
        puts "Done."
      end
    end
  end
end
