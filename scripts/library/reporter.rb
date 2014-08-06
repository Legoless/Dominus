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
  
  #if (xcodeEvent['event'].include? "test")
    #puts line
  #end
  
  if (xcodeEvent['event'] == 'end-test-suite')
    testing = true
      
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
  
  #puts line

end

#
# Output data
#

if (testing)
  puts " #{testPassed} passed, #{testFailed} failed, #{testError} errored, #{testCount} total"
else
  puts " #{errors} errors, #{warnings} warnings"
end
