pipeline {
	parameters {
		string defaultValue: 'https://github.com/Azure/aad-pod-identity.git', description: 'Git repo to build from.', name: 'GIT_REPO', trim: false
		credentials credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl', defaultValue: '', description: 'Git repo credentials.', name: 'GIT_REPO_CREDENTIALS', required: true
		string defaultValue: '', description: 'Git commit to build from.', name: 'GIT_REPO_COMMIT', trim: false

		string defaultValue: 'upstreamk8sci', description: 'Name of the ACR registry to push images to.', name: 'REGISTRY_NAME', trim: false
		string defaultValue: 'public/k8s/aad-pod-identity', description: 'The repository namespace to push the images to.', name: 'REGISTRY_REPO', trim: false
		credentials credentialType: 'com.microsoft.azure.util.AzureCredentials', defaultValue: '', description: 'Which stored credentials to use to push image to.', name: 'REGISTRY_CREDENTIALS', required: true

		choice choices: ['mic', 'nmi', 'demo', 'identity-validator'], description: 'Select the component to build.', name: 'COMPONENT'

		string defaultValue: '', description: '', name: 'MIC_VERSION', trim: false
		string defaultValue: '', description: '', name: 'NMI_VERSION', trim: false
		string defaultValue: '', description: '', name: 'DEMO_VERSION', trim: false
		string defaultValue: '', description: '', name: 'IDENTITY_VALIDATOR_VERSION', trim: false

		booleanParam defaultValue: false, description: 'Set to true just trigger a build to init new parameters, nothing else will run', name: 'INIT_PARAMS'
	}

	agent any

	environment {
		AZURE_CONFIG_DIR = "${WORKSPACE}/.azure"
	}

	stages {
		stage("init params") {
			when { expression { return params.INIT_PARAMS }}
			steps {
				script {
					currentBuild.result = 'ABORTED'
					error('parameters initialized')
					return
				}
			}
		}

		stage("checkout source") {
			steps {
				script {
					cleanWs disableDeferredWipeout: true, deleteDirs: true
					git changelog: false, credentialsId: env.GIT_REPO_CREDENTIALS, poll: false, url: env.GIT_REPO, branch: "master"
					sh "echo 'fetching origin @ ${GIT_REPO_COMMIT}'; git fetch origin"
					sh "git checkout -f '${GIT_REPO_COMMIT}'"
					sh "git log -n 1"
				}
			}
		}

		stage('Build images') {
			steps {
				sh "make REGISTRY_NAME='${REGISTRY_NAME}' REGISTRY='${REGISTRY_NAME}.azurecr.io' REPO_PREFIX='${REGISTRY_REPO}' image-${COMPONENT}"
			}
		}

		stage("Push images") {
			steps {
				withCredentials([azureServicePrincipal("${REGISTRY_CREDENTIALS}")]) {
						sh "az login --service-principal -u '${AZURE_CLIENT_ID}' -p '${AZURE_CLIENT_SECRET}' -t '${AZURE_TENANT_ID}'"
				}
				sh "az acr login -n '${REGISTRY_NAME}'"
				sh '''#!/bin/bash
				make REGISTRY_NAME="${REGISTRY_NAME}" REGISTRY="${REGISTRY_NAME}.azurecr.io" REPO_PREFIX="${REGISTRY_REPO}" push-${COMPONENT}
				'''
			}
		}
	}
}
