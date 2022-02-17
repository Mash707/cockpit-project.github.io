#!/usr/bin/ruby
# frozen_string_literal: true

# To use with a toolbox, make sure your toolbox exists and run:
# _scripts/toolbox-ruby _scripts/update-browser-data.rb

require 'bundler'
require 'net/http'
require 'json'
require 'yaml'
require 'fileutils'

# Browser support feature rules
# Uses caniuse.com's short name for the key
# Values are 1:1 what Cockpit checks for req() in src/ws/login.js
# css() is prefixed with css, then includes the rules
supports = YAML.safe_load("
    websockets:
        req: [WebSocket, window]

    xhr2:
        req: [XMLHttpRequest, window]

    namevalue-storage:
        req: [sessionStorage, window]

    json:
        req: [JSON, window]

    es5:
        req: [defineProperty, Object]

    console-basic:
        req: [console, window]

    history:
        req: [pushState, window.history]

    textcontent:
        req: [textContent, document]

    css-variables:
        req: [CSS, window]

    css-supports-api:
        req: [supports, window.CSS]

    promise-finally:
        req: [finally, Promise.prototype]

    mdn-javascript_builtins_string_replaceall:
        req: [replaceAll, String.prototype]

    flexbox:
        css: [display, flex]

    css-grid:
        css: [display, grid]

    css-supports-api:
        css: 'selector(test)'

    mdn-css_selectors_where:
        css: 'selector(:is():where())'
")

caniuse_db = 'https://raw.githubusercontent.com/Fyrd/caniuse/main/data.json'
support_file = File.expand_path "#{__dir__}/../_data/browser_support.yml"

puts 'Downloading caniuse database...'
doc = Net::HTTP.get(URI(caniuse_db))

puts 'Processing DB...'

obj = JSON.parse(doc)
data = obj['data']

browsers = {}
terminator = 999_999

supports.each do |support, _vals|
  # First check to see if the support data is in the caniuse DB.
  # It really should be, but sometimes it's missing something.
  # Regardless, it needs to be passed through still, for the live JS browser check.
  data[support] && data[support]['stats'].each do |browser, version|
    # Edge _almost_ supports @supports API; close enough for us
    low_version = if support == 'css-supports-api'
                    version.reject { |_k, v| v == 'n' }.keys.first
                  else
                    version.select { |_k, v| v == 'y' }.keys.first
                  end

    if low_version.nil?
      browsers[browser] = terminator
    elsif !browsers[browser] || browsers[browser].to_f < low_version.to_f
      browsers[browser] = low_version.split('-').first
    end

    ## Include versions in each rule
    # if (low_version)
    #   supports[support]["browsers"] ||= {}
    #   supports[support]["browsers"][browser] = low_version.split('-').first
    # end
  end
end

# Smoosh browser support down
browsers = browsers.reject { |_k, v| v == terminator }.compact

comment = 'Generated by _scripts/update-browser-data.rb'

puts "Writing #{support_file}..."
File.write(support_file, ['comment' => comment, 'browsers' => browsers, 'rules' => supports].first.to_yaml)
puts 'Done!'
