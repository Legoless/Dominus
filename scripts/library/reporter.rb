#!/usr/bin/env ruby

require 'json'

warnings = 0
errors = 0

testing = false

testCount = 0
testPassed = 0
testFailed = 0
testError = 0

ARGF.each do |line|
  xcodeEvent = JSON.parse(line)
  
  #
  # Parse testing events
  #
  
  puts line
  
  if (xcodeEvent['event'].include? "test")
    testing = true
  end
  
  if (xcodeEvent['event'] == 'end-test-suite')
    testCount = xcodeEvent['testCaseCount']
    testFailed = xcodeEvent['totalFailureCount']
    testError = xcodeEvent['unexpectedExceptionCount']
    testPassed = testCount - testFailed - testError
  end
  
  #
  # Skip events that are not end build targets
  #
  
  if (xcodeEvent['event'] != 'end-build-target')
      #next
  end

  unless xcodeEvent['totalNumberOfErrors'].nil?
    errors = xcodeEvent['totalNumberOfErrors']
  end
    
  unless xcodeEvent['totalNumberOfWarnings'].nil?
    warnings = xcodeEvent['totalNumberOfWarnings']
  end
end

#
# Output data
#

if (testing)
  puts " #{testPassed} passed, #{testFailed} failed, #{testError} errored, #{testCount} total"
else
  puts " #{errors} errors, #{warnings} warnings"
end
