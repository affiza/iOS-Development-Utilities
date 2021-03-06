#!/usr/bin/env ruby

# Copyright (c) 2010, Tapmates s.r.o. (www.tapmates.com). All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use 
# this file except in compliance with the License.
#
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed 
# under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
# CONDITIONS OF ANY KIND, either express or implied. See the License for the specific 
# language governing permissions and limitations under the License.
#
# Author(s): Petr Kaleta
#
# name: ipaque
# version: 1.0.6
# description: script for building *.ipa packages
# usage: ./ipaque -h
#        ./ipaque -n 'project_name' -s 'source_dir' -b 'build_dir' -d 'deploy_dir'

require 'rubygems'
require 'optparse'
require 'zip/zipfilesystem'
require 'plist'

# required gems
gem 'rubyzip'
gem 'plist'

@options = {}

def exit_with_error(message = '')
  STDERR.puts "#{message} Use -v to enter --verbose mode" unless message.empty?
  exit(1) # error
end

def say(message)
  puts "* #{message}" if @options[:verbose]
end

USAGE = "USAGE: #{$0} [@options]" << "\nUse -h for help"

if ARGV.empty?
  puts USAGE
  exit_with_error
end

OptionParser.new do |opts|
  opts.banner = USAGE
  opts.separator ''
  opts.separator '@options:'

  @options[:verbose] = false
  opts.on('-v', '--verbose',
    'Output more information') do
    @options[:verbose] = true
  end

  opts.on('-n', '--name [NAME]',
    'Project name, REQUIRED') do |project_name|
    @options[:project_name] = project_name
  end

  opts.on('-s', '--source-dir [path]',
    'Path to source directory, REQUIRED') do |source_dir|
    @options[:source_dir] = source_dir
  end

  opts.on('-b', '--build-dir [path]',
    'Path to build directory, REQUIRED') do |build_dir|
    @options[:build_dir] = build_dir
  end

  opts.on('-d', '--deploy-dir [path]',
    'Path to deploy directory, REQUIRED') do |deploy_dir|
    @options[:deploy_dir] = deploy_dir
  end
  
  opts.on_tail('-h', '--help',
    'Show this message') do
    puts opts
    exit
  end
end.parse!

# check if all required params are present and valid
say "Project name: #{@options[:project_name]}"
exit_with_error('Project name is required!') if
    @options[:project_name].nil? or @options[:project_name].empty?
    
say "Source directory: #{@options[:source_dir]}"
exit_with_error('Source directory is required!') if
    @options[:source_dir].nil? or !File.directory?(@options[:source_dir])
    
say "Build directory: #{@options[:build_dir]}"
exit_with_error('Build directory is required!') if
    @options[:build_dir].nil? or !File.directory?(@options[:build_dir])
    
say "Deploy directory: #{@options[:deploy_dir]}"
exit_with_error('Deploy directory is required!') if
    @options[:deploy_dir].nil? or !File.directory?(@options[:deploy_dir])

# plist file must be in root of source directory
plist_file = File.join(@options[:source_dir], "#{@options[:project_name]}-Info.plist")
exit_with_error("No plist file inside source directory!") unless
    File.exist?(plist_file)

# hypothetical path to artwork
artwork_file = File.join(@options[:source_dir], 'iTunesArtwork')

begin
  # read version number from plist
  say "Parsing build version from plist file: #{plist_file}"
  build_version = Plist::parse_xml(plist_file)['CFBundleVersion']
  say "Parsed: #{build_version}"
  
  # *.ipa file path
  archive = File.join(@options[:deploy_dir], "#{@options[:project_name]}-#{build_version}.ipa")
  say "Archive path: #{archive}"

  # create zip archive
  say 'Creating archive...'
  Zip::ZipFile.open(archive, Zip::ZipFile::CREATE) do |zipfile|
    # copy artwork file if exists
    if File.exist?(artwork_file)
      say "Copying itunes artwork: #{artwork_file}"
      zipfile.add('iTunesArtwork', artwork_file)
    end
  
    # create payload folder with project folder inside
    say 'Creating directory: Payload'
    zipfile.dir.mkdir('Payload')
    
    # copy compiled files to payload folder
    binary_path = File.join(@options[:build_dir], "#{@options[:project_name]}.app", '**/**')
    say "Copying files from: #{binary_path}"
    Dir[binary_path].each do |file|
      file_path = File.join('Payload', file.sub(@options[:build_dir], ''))
      say "Adding file to archive from: #{file} to #{file_path}"
      zipfile.add(file_path, file)
    end
  end
  say 'Archive successfully created!'
rescue Exception => e
  # delete archive if exist
  if !archive.nil? and File.exist?(archive)
    say "Removing invalid archive: #{archive}"
    File.delete(archive)
    say 'Archive removed...'
  end
  
  say e.inspect
  
  exit_with_error('Error during ipaqueing, please check your parameters!')
end