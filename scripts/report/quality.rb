#!/usr/bin/env ruby

require 'json'

def fauxPasParse (filename)
  concerns = 0
  warnings = 0
  errors = 0
  total = 0
  
  if (File.exist?(filename))
    #file = File.load(filename, "r:UTF-8")
    report = JSON.parse(IO.read(filename))

    total = report['diagnostics'].count

    for diagnostic in report['diagnostics']
      if diagnostic['severity'] <= 3
        concerns += 1
      elsif diagnostic['severity'] <= 5
        warnings += 1
      elsif diagnostic['severity'] <= 9
        errors += 1
      end
    end

    puts "#{total} issues, #{errors} errors, #{warnings} warnings, #{concerns} concerns" 
  else
    puts "File does not exist: #{file}"
  end
end

Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8

ARGV.each do |arg|
  fauxPasParse (arg)
end
