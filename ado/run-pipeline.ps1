    - task: AzureCLI@2
      displayName: 'run pipeline for ${{ parameters.appName }}'
      enabled: true 
      inputs:
        azureSubscription: ext-dev-cabrego-service-connection # ${{ parameters.serviceConnection }}
        scriptType: 'pscore'
        scriptLocation: 'inlineScript'
        inlineScript: |
          az config set extension.use_dynamic_install=yes_without_prompt | out-null
          echo $(System.AccessToken) | az devops login | out-null

          # write-Output 'CD into ${{ parameters.component }} repo to create PR'
          # Set-Location "$(Agent.BuildDirectory)/repo_folder"
          get-location

          git remote -v

          # write-Output '########################################################################################'

          $devopsProjectUrl = "https://dev.azure.com/${{ variables.AzureDevOpsOrganization }}/${{ variables.AzureDevOpsProject }}"

             $body = @{
              templateParameters = @{
                "appName" = "${{ parameters.appName }}",
                "otherParam" = "value for other param"
                
                }
              }
          $json = $body | ConvertTo-Json
          $pipelineId = "$($objPipeline.id)"
          $pipelineRunUrl = "$devopsProjectUrl/_apis/pipelines/$pipelineId/runs?api-version=7.2-preview.1"

          $pipelineRunResponse = Invoke-RestMethod -Uri $pipelineRunUrl `
              -Method POST -Headers (@{ Authorization = "Bearer $(System.AccessToken)" }) -ContentType 'application/json' `
              -Body $json -Verbose
          $pipelineRunResponse
          # write-Output '########################################################################################'

          git branch -v

        addSpnToEnvironment: true
        useGlobalConfig: true
      env:
        SYSTEM_ACCESSTOKEN: $(System.AccessToken)
