#!/usr/bin/env ruby -wKU
# -*- coding: utf-8 -*-

# Adapted from Martin Kopischke’s original “Markdown to Evernote” workflow (http://blog.timlockridge.com/blog/2013/02/03/using-textmate-and-markdown-with-evernote-configuring-a-workflow/)
# Aaron Bach 2014 – License: Creative Commons Attribution Share-Alike (CC BY-SA) 3.0 Unported (http://creativecommons.org/licenses/by-sa/3.0/)

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