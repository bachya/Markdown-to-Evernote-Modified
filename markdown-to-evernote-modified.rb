#!/usr/bin/env ruby -wKU
# -*- coding: utf-8 -*-

#-------------------------------------------------------------------------------------------------------------
#  Markdown to Evernote (Modified)
#
#  A modification of Tim Lockridge's Markdown to Evernote Textmate bundle that allows for Evernote checkboxes
#  to be interpreted correctly.
#
#  Markdown to Evernote copyright Tim Lockridge 2014 <http://timlockridge.com>
#
#  Copyright (c) 2014
#  Aaron Bach <bachya1208@gmail.com>
#  
#  Permission is hereby granted, free of charge, to any person
#  obtaining a copy of this software and associated documentation
#  files (the "Software"), to deal in the Software without
#  restriction, including without limitation the rights to use,
#  copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the
#  Software is furnished to do so, subject to the following
#  conditions:
#  
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
#  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
#  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
#  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
#  OTHER DEALINGS IN THE SOFTWARE.
#-------------------------------------------------------------------------------------------------------------

# Markdown executable path
# – edit to match your install location if non-default
# – pre-version 3 MMD script usually is '~/Application Support/MultiMarkDown/bin/MultiMarkDown.pl'
MARKDOWN = '/usr/local/bin/multimarkdown'
Process.exit unless File.executable?(MARKDOWN) 

# Smart typography (aka SmartyPants) switch
SMARTY = true
# – Smart typography processing via MARKDOWN extension
#   enable with '--smart' for PEG Markdown, disable using '--nosmart' in upcoming MMD version 3
SMARTY_EXT_ON  = '--smart'
SMARTY_EXT_OFF = '--nosmart'
# – Separate smart typography processor (i.e. SmartyPants.pl)
#   set to path to SmartyPants.pl (for classic Markdown and MMD pre-version 3, usually same dir as (Multi)MarkDown.pl)
#   set to '' to use SMARTY_EXT instead
SMARTY_PATH = ''
if SMARTY && !SMARTY_PATH.empty? then Process.exit unless File.executable?(SMARTY_PATH) end

# utility function: escape double quotes and backslashes (for AppleScript)
def escape(str)
	str.to_s.gsub(/(?=["\\])/, '\\')
end

# utility function: enclose string in double quotes
def quote(str)
	'"' << str.to_s << '"'
end

# buffer
input = ''
# processed data
contents = ''
title = ''
tags = ''
notebook = ''
date = ''
# operation switches
metadata = true

# parse for metadata and pass all non-metadata to input
ARGF.each_line do |line|
	case line
	# note title (either MMD metadata 'Title' – must occur before the first blank line – or atx style 1st level heading)
	when /^Title:\s.*?/
 		if metadata then title = line[7..-1].strip else input << line end
	# strip all 1st level headings as logically, note title is 1st level
	when /^#[^#]+?/
		if title.empty? then title = line[line.index(/[^#]/)..-1].strip end
	# note tags (either MMD metadata 'Keywords' or '@ <tag list>'; must occur before the first blank line)
	when /^(Keywords:|@)\s.*?/
		if metadata then tags = line[line.index(/\s/)+1..-1].split(',').map {|tag| tag = tag.strip} else input << line end
	# notebook (either MMD metadata 'Notebook' or '= <name>'; must occur before the first blank line)
	when /^(Notebook:|=)\s.*?/
		if metadata then notebook = line[line.index(/\s/)+1..-1].strip else input << line end
	# datek (either MMD metadata 'Date'; must occur before the first blank line)
	when /^(Date:)\s.*?/
		if metadata then date = line[line.index(/\s/)+1..-1].strip else input << line end
	# metadata block ends at first blank line
	when /^\s?$/
		if metadata then metadata = false end
		input << line
	# anything else is appended to input
	else
		input << line
	end
end

# Markdown processing
mmd_cmd =  "#{quote MARKDOWN}"
mmd_cmd << if SMARTY_PATH.empty? then SMARTY ? " #{SMARTY_EXT_ON}" : " #{SMARTY_EXT_OFF}" else "|#{quote SMARTY_PATH}" end unless !SMARTY

IO.popen(mmd_cmd, 'r+') do |io|
	input.each_line {|line| io << line}
	io.close_write
	io.each_line {|line| contents << line}
end

# create note, using localized date and time stamp as fallback for title
if title.empty? then title = %x{osascript -e 'get (current date) as text'}.chomp end

osa_cmd =  "tell application #{quote 'Evernote'} to create note with enml #{quote escape contents}"
osa_cmd << "  title #{quote escape title}"
if tags.length  > 1 then osa_cmd << " tags #{'{' << tags.map {|tag| tag = quote escape tag}.join(",") << '}'}" end
if tags.length == 1 then osa_cmd << " tags #{quote escape tags[0]}" end
osa_cmd << " notebook #{quote escape notebook}" unless notebook.empty?
osa_cmd << " created date #{quote escape date}" unless date.empty?

require 'tempfile'
Tempfile.open('md2evernote') do |file|
	file.puts osa_cmd
	file.rewind
	%x{osascript "#{file.path}"}
end