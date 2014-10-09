#!/usr/bin/env ruby

require 'json'

ARGA.each do |arg|
  fauxPasParse (arg)
end

def fauxPasParse (file)
  concerns = 0
  warnings = 0
  errors = 0
  total = 0

  if (File.exist?(file))
    puts "Checking file"

    report = JSON.load(file)
  else
    puts "File does not exist: #{file}"
  end
end