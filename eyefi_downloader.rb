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

class Downloader
  def initialize
    @urls = File.readlines(EXCLUDE_LIST).map(&:strip)
  end

  def wait_for_part
    puts "waiting for part file to be created"
    dir = Dir.new(DOWNLOAD_DIR)
    sleep 5 while ((dir.grep PART_FILE_MATCHER).length == 0)
  end

  def wait_till_no_more_parts
    puts "waiting until the part file download is complete"
    dir = Dir.new(DOWNLOAD_DIR)
    sleep 5 while ((dir.grep PART_FILE_MATCHER).length > 0)
  end

  def is_done(url)
    @urls.include?(url)
  end

  def browser
    @browser ||= get_firefox
  end

  def get_firefox
    # Firefox = update profile to not ask where to save
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.helperApps.neverAsk.saveToDisk'] = "application/zip,application/x-zip,application/octet-stream,image/JPG,image/png,image/jpeg,image/jpg,video/mp4,video/quicktime,video/x-msvideo,video/3gpp"
    Watir::Browser.new :firefox, :profile => profile
  end

  def check_if_parts_exist
    if (Dir.new(DOWNLOAD_DIR).grep(PART_FILE_MATCHER)).length > 0
      puts "found part files in #{DOWNLOAD_DIR}"
      puts "please delete these first"
      exit 1
    end
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
    check_if_parts_exist
    login
    load_all_albums

    puts "Fetching links to individual days"
    links = browser.elements(css: '.summarythumbcover > a').to_a

    puts "Total links: #{links.length}"
    script = "arguments[0].target = 'foo'; arguments[0].click();return;"
    links.each do |atag|
      puts "*" * 80
      href = atag.to_subtype.href

      if is_done(href)
        puts "Skipping #{href} as already done"
        next
      end

      # :command opens a new tab, and :shift shifts the focus
      puts "Opening #{href} in a new window"
      # atag.when_present.click(:command, :shift)
      browser.execute_script(script, atag.to_subtype)

      browser.window(index: 1).use

      browser.div(id: 'pagetitle').wait_until_present
      puts browser.div(id: 'pagetitle').text

      puts "selecting all assets on this page"
      browser.checkbox(id: 'checkoptsbox').wait_until_present
      browser.checkbox(id: 'checkoptsbox').click
      browser.div(id: 'actionopts').wait_until_present
      browser.div(id: 'actionopts').click
      all_actions = browser.elements(css: '#actionmenu a').to_a
      download = all_actions[5]
      download.wait_until_present

      puts "clicking on download"
      download.click
      wait_for_part
      puts "sleeping while the download finishes"
      wait_till_no_more_parts
      puts "download complete. closing this window"
      #browser.element(css: 'body').send_keys(:command, 'w')
      #browser.element(css: 'body').send_keys(:control, :tab)
      browser.windows[1].close
      File.open(EXCLUDE_LIST, 'a') {|f| f.puts href}
      browser.window(index: 0).use
    end
  rescue => e
    puts e
    require 'pry'; binding.pry
  end
end

# main program
downloader = Downloader.new
downloader.run

puts "Done. Make sure you look for *.zip and *.mp4 files in the #{DOWNLOAD_DIR} directory"

