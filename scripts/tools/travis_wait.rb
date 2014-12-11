#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'net/http'
require 'net/https'

TRAVIS_SUCCESS = 1
TRAVIS_FAILED = 2
TRAVIS_RUNNING = 3

#
# Returns repository information about slug
#
def repo (slug, githubToken)

  puts "Retrieving #{slug} from GitHub..."

  urlString = 'https://api.github.com/repos/' + slug + '?access_token=' + githubToken

  uri = URI(urlString)

  client = Net::HTTP.new(uri.host, uri.port)
  client.use_ssl = (uri.scheme == 'https')

  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/vnd.github.v3+json'

  result = client.request (request)

  case result
  when Net::HTTPSuccess, Net::HTTPRedirection
    repoData = JSON.parse(result.body)
    return repoData
  else
	return nil
  end
end

def checkPrivateRepo (repo)
  if repo.nil?
  	return false
  end

  return repo['private']
end


def login (githubToken, privateRepo)
  #
  # Attempt to login to Travis
  #

  puts "Using GitHub token to login to Travis..."

  if (privateRepo)
  	uri = URI('https://api.travis-ci.com/auth/github')
  else
  	uri = URI('https://api.travis-ci.org/auth/github')
  end

  client = Net::HTTP.new(uri.host, uri.port)
  client.use_ssl = (uri.scheme == 'https')

  request = Net::HTTP::Post.new(uri.path)

  #
  # Add headers
  #
  
  appendTravisHeaders (request)

  #
  # Add token
  #

  body = '{"github_token":"' + githubToken + '"}'

  #request.use_ssl = true

  request.body = body

  result = client.request (request)

  case result
  when Net::HTTPSuccess, Net::HTTPRedirection
    loginData = JSON.parse(result.body)

    return loginData['access_token']
  else
	#result.value

	return nil
  end
end

def appendTravisHeaders (request)
  #
  # Return Travis headers
  #

  request['User-Agent'] = 'TravisWorkerClient/1.0.0'
  request['Accept'] = 'application/vnd.travis-ci.2+json'
  request['Content-Type'] = 'application/json'
end

def help ()
  puts "Dominus Travis Worker Client connects to Travis API and checks jobs for current build."
  puts "Based on Dominus actions, only jobs that have ACTION=deploy in environment variables are ignored."
  puts "Script will continue checking jobs every 10 seconds and it will quit once all other jobs have finished."
  puts "It all jobs had finished successfully, it will output \"Integration: Success\"."
  puts "If one job had failed script will output \"Integration: Failed\"."
  puts ""
  puts "GitHub token is optional, if provided script will use the api.travis-ci.com for private repositories."
  puts ""
  puts "Usage: #{$0} <REPOSITORY_SLUG> <TRAVIS_BUILD_ID> <GITHUB_TOKEN>"
  puts ""
end

def build(buildId, accessToken, privateRepo)

  if privateRepo
    urlString = 'https://api.travis-ci.com/builds/' + buildId + '?access_token=' + accessToken
  else
  	urlString = 'https://api.travis-ci.org/builds/' + buildId + '?access_token=' + accessToken
  end

  uri = URI(urlString)

  client = Net::HTTP.new(uri.host, uri.port)
  client.use_ssl = (uri.scheme == 'https')

  request = Net::HTTP::Get.new(uri)

  #
  # Add headers
  #
  
  appendTravisHeaders (request)

  result = client.request (request)

  case result
  when Net::HTTPSuccess, Net::HTTPRedirection
    buildData = JSON.parse(result.body)

    return buildData
  else
	return nil
  end
end

def checkJobs(buildData)

  if buildData.nil?
    return TRAVIS_FAILED
  end

  #
  # Go through all jobs and look for failed one
  #

  buildData['jobs'].each do |job|

  	#
  	# Ignore deploy jobs
  	#

    action = job['config']['env']

    action = action.gsub(' ', '')
    action = action.gsub('\'', '')
    action = action.gsub('"','')

    next if action.include? 'ACTION=deploy'

    #
    # Check if job's state is failed, just return failed
    #

    state = job['state'].downcase()

    if state.include? 'failed'
      return TRAVIS_FAILED
    elsif state.include? 'running'
      return TRAVIS_RUNNING
    end
  end

  return TRAVIS_SUCCESS
end

#
# Main
#

if (ARGV.count >= 3)
  repositorySlug = ARGV[0]
  buildId = ARGV[1]
  githubToken = ARGV[2]
end

if buildId.nil? or repositorySlug.nil? or githubToken.nil?
  puts "Error: Missing parameters. Try again."
  puts ""

  help

  exit
end

#
# Get GitHub Repo
#

repo = repo(repositorySlug, githubToken)

if repo.nil?
  puts "Error: Unable to retrieve #{repositorySlug} repository on GitHub."

  exit
end

#
# Login to Travis
#

privateRepo = checkPrivateRepo(repo)

accessToken = login(githubToken, privateRepo)

if (accessToken.nil?)
  puts "Error: Unable to login to Travis. Check GitHub token."

  exit
end

#
# Start an unlimited loop (we'll put a break inside just in case to make it work)
#

counter = 1

while true do 
  puts "Running check loop: #{counter}, checking jobs..."

  buildData = build(buildId, accessToken, privateRepo)

  result = checkJobs (buildData)

  if (result == TRAVIS_SUCCESS)
  	puts "Integration: Success"

    exit
  elsif (result == TRAVIS_FAILED)
   	puts "Integration: Failed"

    exit
  end

  #
  # Stop script after 10 minutes with failed state
  #
  if (counter > 60)
  	puts "One of the jobs is stuck, aborting..."
  	puts "Integration: Failed"

  	exit
  end

  puts "At least 1 job still running, continuing loop..."

  sleep (2)

  counter = counter + 1
   	
end
