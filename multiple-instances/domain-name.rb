#!/usr/bin/ruby

# Parse out the domain name from a full host name
if ARGV.length != 1
  puts "Usage: domain-name.rb <host-name>"
  exit 1
end

parts = ARGV[0].split '.'
if parts.length < 2
  puts "Invalid host name"
  exit 1
end

if parts.length == 2
  puts ARGV[0]
else 
  puts parts[parts.length - 2] + "." + parts[parts.length - 1]
end
