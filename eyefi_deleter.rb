#!/usr/bin/env ruby

require 'watir'
require 'watir-webdriver'

$stdout.sync = true

USERNAME = ENV['EYEFI_UNAME']
PWD = ENV['EYEFI_PWD']
LOGIN_URL = 'http://center.eye.fi/login.php'
DOWNLOAD_DIR = "#{ENV['HOME']}/Downloads"
PART_FILE_MATCHER = /.part$/
EXCLUDE_LIST = "exclude.list"

#########################################################

class Deleter
  def browser
    @browser ||= get_firefox
  end

  def get_firefox
    # Firefox = update profile to not ask where to save
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.helperApps.neverAsk.saveToDisk'] = "application/zip,application/x-zip,application/octet-stream,image/JPG,image/png,image/jpeg,image/jpg,video/mp4,video/quicktime,video/x-msvideo,video/3gpp"
    Watir::Browser.new :firefox, :profile => profile
  end

  def load_all_albums
    puts "Loading all albums"
    browser.div(id: 'load_more').wait_until_present
    browser.div(id: 'load_more').click
    browser.div(id: 'load_more').wait_while_present
  end

  def login
    puts "logging in"
    browser.goto(LOGIN_URL)
    browser.text_field(name: 'login').set USERNAME
    browser.text_field(name: 'password').set PWD
    browser.button(class: 'loginbutton').click  
    browser.button(class: 'loginbutton').wait_while_present
  end

  def run
    login
    load_all_albums

    puts "Fetching links to individual days"
    links = browser.elements(css: '.summarythumbcover > a').to_a

    puts "Total links: #{links.length}"
    script = "arguments[0].target = 'foo'; arguments[0].click();return;"
    links.each do |atag|
      puts "*" * 80
      href = atag.to_subtype.href

      # :command opens a new tab, and :shift shifts the focus
      puts "Opening #{href} in a new window"
      # atag.when_present.click(:command, :shift)
      browser.execute_script(script, atag.to_subtype)

      browser.window(index: 1).use
      browser.execute_script("window.confirm = function() {return true}")

      browser.div(id: 'pagetitle').wait_until_present
      puts browser.div(id: 'pagetitle').text

      puts "selecting all assets on this page"
      browser.checkbox(id: 'checkoptsbox').wait_until_present
      browser.checkbox(id: 'checkoptsbox').click
      browser.div(id: 'actionopts').wait_until_present
      browser.div(id: 'actionopts').click
      all_actions = browser.elements(css: '#actionmenu a').to_a
      delete = all_actions[6]
      delete.wait_until_present

      puts "clicking on delete"
      delete.click
      browser.div(id: 'summary_noitems').wait_until_present
      browser.windows[1].close
      browser.window(index: 0).use
    end
  rescue => e
    puts e
    require 'pry'; binding.pry
  end
end

# main program
deleter = Deleter.new
deleter.run

puts "Done."

