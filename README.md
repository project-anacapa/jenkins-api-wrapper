# jenkins-api-proto

## API
The functionality of this API is encapsulated in the Jenkins module.

The main class exposed right now is the 'lab' class.
```
# to create a new lab instance
lab = Jenkins::Lab.new(
  :git_provider_domain => "github.com",
  :course_org => "ucsb-cs-test-org-1",
  :credentials_id => "github.com-gareth-machine-user",
  :lab_name => "lab00"
  )
```

Lab methods
 - __lab.makeGraderAndAssignentIfNotExist__ will check that jobs for this assignment have been created (creating them if they do not exist). You MUST call this before attempting to grade a student submission or update an assignment from the professors definition repository.
 - __assignment_job_name__ is an attribute accessor returning the name of the job for updating the assignment (
 _NOTE: this job does not necessarily exist, you must first trigger makeGraderAndAssignentIfNotExist to trigger its creation_)
 - __grader_job_name__ is an attribute accessor returning the name of the job for grading student submissions. To build this you must pass in an enviornment variable containnig the student's github profile as per https://github.com/project-anacapa/anacapa-jenkins-lib/blob/master/jobs/grader.groovy. The name of the enviornment variable of interest is 'github_user'

## Jenkins Configuration
 - _TODO: move this to a more appropriate location_
 - Plugins
    - install Job DSL
    - install Rebuilder
    - install Copy Artifact
    - install Environment Injector Plugin
 - Manage Jenkins -> Configure System -> Click add Global Pipeline Library
    - Add https://github.com/garethgeorge/anacapa-jenkins-lib to your jenkins libraries
    - default version: master
    - retrieval method: github
    - load implicitly: true
 - Additional Steps for Development
    - Go to Security -> Enable Script Security for Job DSL
       - Uncheck the setting to avoid annoying confirmation dialogs
    - Go to Manage Nodes and edit the settings for 'master' and add the 'submit' label
        - this is because in production you would add worker slaves with ssh credentials and the 'submit' label but this is entirely unnecessary for development.
 - Restart Jenkins and you should be good to go!

## Jenkins Jobs Setup
 - Create Job -> Free Style Project
    - name: anacapa-jenkins-lib (note this job will bootstrap the construction of other jobs)
    - turn on Build Enviornment -> 'delete workspace before build' setting in the job setup
    - build -> add build step -> Process Job DSLs
        - look on file system
        - DLS Scripts: jobs/standaloneSetupAssignment.groovy
    - save changes!
    - run the job
        - you should see a new job 'AnacapaGrader-setupAssignment'
